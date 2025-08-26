// src/util/extended-mcp.ts
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";
import { readFile } from 'fs/promises';
import { join } from 'path';
import { DEEBO_ROOT } from '../index.js';

// Types for extended MCP configuration
export interface ExtendedMcpServerConfig {
  type: 'local' | 'sse';
  command?: string;
  args?: string[];
  url?: string;
  tools: string[];
  disabled?: boolean;
  timeout?: number;
  env?: Record<string, string>;
}

export interface ExtendedMcpConfig {
  mcpServers: Record<string, ExtendedMcpServerConfig>;
  serverCapabilities: Record<string, any>;
  validationSettings: {
    enableHealthChecks: boolean;
    maxRetries: number;
    healthCheckInterval: number;
    connectionTimeout: number;
  };
}

// Map to track active connections
const activeExtendedConnections: Map<string, Promise<Client>> = new Map();

/**
 * Connect to an MCP server using either stdio or SSE transport
 */
export async function connectExtendedMcpServer(
  name: string, 
  serverName: string, 
  sessionId: string, 
  repoPath: string
): Promise<Client> {
  const connectionKey = `${name}-${sessionId}`;
  
  // Return existing connection if available
  if (activeExtendedConnections.has(connectionKey)) {
    return activeExtendedConnections.get(connectionKey)!;
  }

  const connectionPromise = createExtendedMcpConnection(name, serverName, sessionId, repoPath);
  activeExtendedConnections.set(connectionKey, connectionPromise);
  
  try {
    const client = await connectionPromise;
    return client;
  } catch (error) {
    // Remove failed connection from cache
    activeExtendedConnections.delete(connectionKey);
    throw error;
  }
}

/**
 * Create a new MCP connection based on server type
 */
async function createExtendedMcpConnection(
  name: string,
  serverName: string,
  sessionId: string,
  repoPath: string
): Promise<Client> {
  const rawConfig = JSON.parse(
    await readFile(join(DEEBO_ROOT, 'config', 'extended-mcp-servers.json'), 'utf-8')
  ) as ExtendedMcpConfig;
  
  const serverConfig = rawConfig.mcpServers[serverName];
  if (!serverConfig) {
    throw new Error(`Server configuration not found: ${serverName}`);
  }

  if (serverConfig.disabled) {
    throw new Error(`Server is disabled: ${serverName}`);
  }

  const client = new Client({ name, version: '1.0.0' }, { capabilities: { tools: true } });
  
  if (serverConfig.type === 'local') {
    return createStdioConnection(client, serverConfig, repoPath);
  } else if (serverConfig.type === 'sse') {
    return createSSEConnection(client, serverConfig);
  } else {
    throw new Error(`Unsupported server type: ${serverConfig.type}`);
  }
}

/**
 * Create a stdio-based connection for local MCP servers
 */
async function createStdioConnection(
  client: Client, 
  config: ExtendedMcpServerConfig, 
  repoPath: string
): Promise<Client> {
  if (!config.command || !config.args) {
    throw new Error('Local server requires command and args');
  }

  // Handle environment variable substitutions
  let command = config.command;
  let args = config.args.map(arg => 
    arg.replace(/{repoPath}/g, repoPath)
  );

  // Substitute command paths if needed
  if (command === 'npx') {
    command = process.env.DEEBO_NPX_PATH || 'npx';
  }

  const transport = new StdioClientTransport({
    command,
    args,
    env: {
      ...process.env,
      // Include any custom environment variables
      ...(config.env || {}),
      // Explicitly set critical variables
      NODE_ENV: process.env.NODE_ENV || 'development',
      USE_MEMORY_BANK: process.env.USE_MEMORY_BANK || 'false',
      MOTHER_HOST: process.env.MOTHER_HOST || '',
      MOTHER_MODEL: process.env.MOTHER_MODEL || '',
      SCENARIO_HOST: process.env.SCENARIO_HOST || '',
      SCENARIO_MODEL: process.env.SCENARIO_MODEL || '',
      OPENROUTER_API_KEY: process.env.OPENROUTER_API_KEY || ''
    }
  });

  await client.connect(transport);
  return client;
}

/**
 * Create an SSE-based connection for remote MCP servers
 */
async function createSSEConnection(
  client: Client, 
  config: ExtendedMcpServerConfig
): Promise<Client> {
  if (!config.url) {
    throw new Error('SSE server requires URL');
  }

  const url = new URL(config.url);
  const transport = new SSEClientTransport(url, {
    // Add any SSE-specific configuration here
    fetch: globalThis.fetch
  });

  await client.connect(transport);
  return client;
}

/**
 * Validate MCP server connection and capabilities
 */
export async function validateMcpServer(
  serverName: string, 
  repoPath: string = '/tmp'
): Promise<{
  connected: boolean;
  capabilities?: any;
  tools?: string[];
  error?: string;
}> {
  try {
    const client = await connectExtendedMcpServer(
      `validator-${serverName}`, 
      serverName, 
      'validation', 
      repoPath
    );
    
    // Get server capabilities
    const capabilities = client.getServerCapabilities();
    
    // List available tools
    let tools: string[] = [];
    try {
      const toolsResponse = await client.listTools();
      tools = toolsResponse.tools.map(tool => tool.name);
    } catch (toolError) {
      // Some servers might not support tools
      console.warn(`Could not list tools for ${serverName}:`, toolError);
    }

    return {
      connected: true,
      capabilities,
      tools
    };
  } catch (error) {
    return {
      connected: false,
      error: error instanceof Error ? error.message : String(error)
    };
  }
}

/**
 * Get all configured MCP servers
 */
export async function getExtendedMcpServers(): Promise<ExtendedMcpConfig> {
  const rawConfig = JSON.parse(
    await readFile(join(DEEBO_ROOT, 'config', 'extended-mcp-servers.json'), 'utf-8')
  ) as ExtendedMcpConfig;
  
  return rawConfig;
}

/**
 * Cleanup all active connections
 */
export async function cleanupExtendedConnections(): Promise<void> {
  for (const [key, clientPromise] of activeExtendedConnections.entries()) {
    try {
      const client = await clientPromise;
      // Note: MCP Client doesn't have a standard disconnect method
      // The transport will be closed when the process ends
    } catch (error) {
      console.warn(`Error cleaning up connection ${key}:`, error);
    }
  }
  activeExtendedConnections.clear();
}