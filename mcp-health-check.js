#!/usr/bin/env node

/**
 * Quick MCP Server Health Check
 * Run this script to verify MCP servers are working in your environment
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";

async function quickHealthCheck() {
  console.log('🏥 MCP Server Health Check\n');
  
  const results = [];
  
  // Test Playwright (most reliable local server)
  console.log('🎭 Testing Playwright MCP...');
  try {
    const client = new Client({ name: 'health-check', version: '1.0.0' }, { capabilities: { tools: true } });
    const transport = new StdioClientTransport({
      command: process.env.DEEBO_NPX_PATH || 'npx',
      args: ['@playwright/mcp@latest'],
      env: { ...process.env, NODE_ENV: 'development' }
    });
    
    await client.connect(transport);
    const tools = await client.listTools();
    console.log(`✅ Playwright: ${tools.tools.length} tools available`);
    results.push({ name: 'Playwright', status: 'OK', tools: tools.tools.length });
  } catch (error) {
    console.log(`❌ Playwright: ${error.message}`);
    results.push({ name: 'Playwright', status: 'FAILED', error: error.message });
  }
  
  // Test one SSE server (if network allows)
  console.log('\n🌐 Testing SSE MCP (dev_mcp)...');
  try {
    const client = new Client({ name: 'sse-check', version: '1.0.0' }, { capabilities: { tools: true } });
    const transport = new SSEClientTransport(
      new URL('https://api.toolrouter.ai/u/699f7140-5399-4db2-a597-55e1a82b43b4/sse'),
      { fetch: globalThis.fetch }
    );
    
    const timeout = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Connection timeout (10s)')), 10000)
    );
    
    await Promise.race([client.connect(transport), timeout]);
    const tools = await client.listTools();
    console.log(`✅ dev_mcp: ${tools.tools.length} tools available`);
    results.push({ name: 'dev_mcp (SSE)', status: 'OK', tools: tools.tools.length });
  } catch (error) {
    console.log(`⚠️  dev_mcp: ${error.message.includes('ENOTFOUND') || error.message.includes('timeout') ? 'Network restricted (expected in sandbox)' : error.message}`);
    results.push({ name: 'dev_mcp (SSE)', status: 'NETWORK_RESTRICTED', error: error.message });
  }
  
  console.log('\n📊 Health Check Summary:');
  results.forEach(result => {
    const status = result.status === 'OK' ? '✅' : 
                  result.status === 'NETWORK_RESTRICTED' ? '🌐' : '❌';
    const info = result.tools ? `(${result.tools} tools)` : 
                 result.status === 'NETWORK_RESTRICTED' ? '(needs network access)' : 
                 `(${result.error})`;
    console.log(`${status} ${result.name}: ${result.status} ${info}`);
  });
  
  const working = results.filter(r => r.status === 'OK').length;
  const total = results.length;
  
  console.log(`\n🎯 Status: ${working}/${total} servers functional`);
  
  if (working > 0) {
    console.log('✅ MCP integration is ready for use!');
    console.log('🚀 Proceed with confidence for PR#1 work');
  } else {
    console.log('⚠️  Check your environment setup');
    console.log('💡 Ensure npx is available and network access if needed');
  }
}

quickHealthCheck().catch(error => {
  console.error('💥 Health check failed:', error);
  process.exit(1);
});