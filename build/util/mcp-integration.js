// src/util/mcp-integration.ts
/**
 * Integration layer to enable extended MCP servers in the existing deebo architecture
 */
import { connectRequiredTools } from './mcp.js';
import { connectExtendedMcpServer, getExtendedMcpServers } from './extended-mcp.js';
import { log } from './logger.js';
// Map to track all active MCP connections (both original and extended)
const allMcpConnections = new Map();
/**
 * Enhanced function that connects to both original and extended MCP tools
 */
export async function connectAllMcpTools(agentName, sessionId, repoPath) {
    try {
        // Connect to original required tools (git and filesystem)
        const { gitClient, filesystemClient } = await connectRequiredTools(agentName, sessionId, repoPath);
        // Connect to extended MCP servers
        const extendedClients = new Map();
        try {
            const config = await getExtendedMcpServers();
            const serverNames = Object.keys(config.mcpServers);
            for (const serverName of serverNames) {
                const serverConfig = config.mcpServers[serverName];
                // Skip disabled servers
                if (serverConfig.disabled) {
                    await log(sessionId, agentName, 'debug', `Skipping disabled MCP server: ${serverName}`, { repoPath });
                    continue;
                }
                try {
                    const client = await connectExtendedMcpServer(`${agentName}-${serverName}`, serverName, sessionId, repoPath);
                    extendedClients.set(serverName, client);
                    allMcpConnections.set(`${agentName}-${serverName}`, client);
                    await log(sessionId, agentName, 'info', `Connected to extended MCP server: ${serverName}`, {
                        type: serverConfig.type,
                        tools: serverConfig.tools.length,
                        repoPath
                    });
                }
                catch (error) {
                    // Log but don't fail - extended servers are optional
                    await log(sessionId, agentName, 'warn', `Failed to connect to extended MCP server: ${serverName}`, {
                        error: error instanceof Error ? error.message : String(error),
                        repoPath
                    });
                }
            }
        }
        catch (configError) {
            await log(sessionId, agentName, 'warn', 'Failed to load extended MCP configuration', {
                error: configError instanceof Error ? configError.message : String(configError),
                repoPath
            });
        }
        return {
            gitClient,
            filesystemClient,
            extendedClients
        };
    }
    catch (error) {
        await log(sessionId, agentName, 'error', 'Failed to connect to MCP tools', {
            error: error instanceof Error ? error.message : String(error),
            repoPath
        });
        throw error;
    }
}
/**
 * Enhanced tool call parser that supports both original and extended MCP servers
 */
export function parseExtendedToolCalls(responseText, gitClient, filesystemClient, extendedClients) {
    const toolCalls = [...responseText.matchAll(/<use_mcp_tool>([\s\S]*?)<\/use_mcp_tool>/g)].map(match => match[1].trim());
    return toolCalls.map((tc) => {
        try {
            const serverNameMatch = tc.match(/<server_name>(.*?)<\/server_name>/);
            if (!serverNameMatch || !serverNameMatch[1])
                throw new Error('Missing server_name');
            const serverName = serverNameMatch[1];
            // Find the appropriate client
            let server;
            if (serverName === 'git-mcp') {
                server = gitClient;
            }
            else if (serverName === 'desktop-commander') {
                server = filesystemClient;
            }
            else {
                // Check extended clients
                server = extendedClients.get(serverName);
            }
            if (!server)
                throw new Error(`Unknown or unavailable server: ${serverName}`);
            const toolMatch = tc.match(/<tool_name>(.*?)<\/tool_name>/);
            if (!toolMatch || !toolMatch[1])
                throw new Error('Missing tool_name');
            const tool = toolMatch[1];
            const argsMatch = tc.match(/<arguments>(.*?)<\/arguments>/s);
            if (!argsMatch || !argsMatch[1])
                throw new Error('Missing arguments');
            const args = JSON.parse(argsMatch[1]);
            return { server, tool, args };
        }
        catch (err) {
            return { error: err instanceof Error ? err.message : String(err) };
        }
    });
}
/**
 * Get available tools from all connected MCP servers
 */
export async function getAllAvailableTools(gitClient, filesystemClient, extendedClients) {
    const allTools = [];
    // Get tools from git client
    try {
        const gitTools = await gitClient.listTools();
        allTools.push({
            serverName: 'git-mcp',
            tools: gitTools.tools.map(tool => ({ name: tool.name, description: tool.description }))
        });
    }
    catch (error) {
        console.warn('Could not list tools from git-mcp:', error);
    }
    // Get tools from filesystem client
    try {
        const fsTools = await filesystemClient.listTools();
        allTools.push({
            serverName: 'desktop-commander',
            tools: fsTools.tools.map(tool => ({ name: tool.name, description: tool.description }))
        });
    }
    catch (error) {
        console.warn('Could not list tools from desktop-commander:', error);
    }
    // Get tools from extended clients
    for (const [serverName, client] of extendedClients.entries()) {
        try {
            const tools = await client.listTools();
            allTools.push({
                serverName,
                tools: tools.tools.map(tool => ({ name: tool.name, description: tool.description }))
            });
        }
        catch (error) {
            console.warn(`Could not list tools from ${serverName}:`, error);
        }
    }
    return allTools;
}
/**
 * Generate enhanced prompt that includes information about all available MCP tools
 */
export async function generateEnhancedToolPrompt(gitClient, filesystemClient, extendedClients) {
    const allTools = await getAllAvailableTools(gitClient, filesystemClient, extendedClients);
    let prompt = `
## Available MCP Tools

You have access to the following MCP (Model Context Protocol) servers and their tools:

`;
    for (const serverInfo of allTools) {
        prompt += `### ${serverInfo.serverName}\n`;
        if (serverInfo.tools.length > 0) {
            for (const tool of serverInfo.tools) {
                prompt += `- **${tool.name}**${tool.description ? `: ${tool.description}` : ''}\n`;
            }
        }
        else {
            prompt += '- No tools available\n';
        }
        prompt += '\n';
    }
    prompt += `## How to Use MCP Tools

To call an MCP tool, use this format:
\`\`\`xml
<use_mcp_tool>
  <server_name>SERVER_NAME</server_name>
  <tool_name>TOOL_NAME</tool_name>
  <arguments>
    {
      "parameter1": "value1",
      "parameter2": "value2"
    }
  </arguments>
</use_mcp_tool>
\`\`\`

`;
    return prompt;
}
/**
 * Cleanup all MCP connections
 */
export async function cleanupAllMcpConnections() {
    allMcpConnections.clear();
}
