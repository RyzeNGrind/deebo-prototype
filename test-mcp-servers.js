#!/usr/bin/env node

// Test script for validating MCP servers
import { validateMcpServer, getExtendedMcpServers } from './build/util/extended-mcp.js';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Mock the DEEBO_ROOT for testing
process.env.DEEBO_ROOT = __dirname;

async function testMcpServers() {
  console.log('🔍 Testing MCP Server Connections...\n');
  
  try {
    const config = await getExtendedMcpServers();
    const servers = Object.keys(config.mcpServers);
    
    console.log(`Found ${servers.length} MCP servers to test:\n`);
    
    const results = [];
    
    for (const serverName of servers) {
      const serverConfig = config.mcpServers[serverName];
      console.log(`📡 Testing ${serverName} (${serverConfig.type})...`);
      
      const startTime = Date.now();
      const result = await validateMcpServer(serverName);
      const duration = Date.now() - startTime;
      
      results.push({
        name: serverName,
        type: serverConfig.type,
        ...result,
        duration
      });
      
      if (result.connected) {
        console.log(`✅ ${serverName}: Connected (${duration}ms)`);
        if (result.tools && result.tools.length > 0) {
          console.log(`   🛠️  Tools: ${result.tools.slice(0, 3).join(', ')}${result.tools.length > 3 ? ` (+${result.tools.length - 3} more)` : ''}`);
        }
        if (result.capabilities) {
          const caps = result.capabilities;
          const capNames = Object.keys(caps).filter(k => caps[k]);
          if (capNames.length > 0) {
            console.log(`   🔧 Capabilities: ${capNames.join(', ')}`);
          }
        }
      } else {
        console.log(`❌ ${serverName}: Failed - ${result.error}`);
      }
      console.log('');
    }
    
    // Summary
    console.log('📊 Summary:');
    const connected = results.filter(r => r.connected);
    const failed = results.filter(r => !r.connected);
    
    console.log(`✅ Connected: ${connected.length}/${results.length}`);
    console.log(`❌ Failed: ${failed.length}/${results.length}`);
    
    if (connected.length > 0) {
      console.log('\n🎉 Successfully connected servers:');
      connected.forEach(server => {
        console.log(`   • ${server.name} (${server.type}) - ${server.tools?.length || 0} tools`);
      });
    }
    
    if (failed.length > 0) {
      console.log('\n💥 Failed servers:');
      failed.forEach(server => {
        console.log(`   • ${server.name} (${server.type}) - ${server.error}`);
      });
    }
    
    // Exit with error code if any servers failed
    if (failed.length > 0) {
      process.exit(1);
    } else {
      console.log('\n🚀 All MCP servers are working correctly!');
      process.exit(0);
    }
    
  } catch (error) {
    console.error('💥 Error testing MCP servers:', error);
    process.exit(1);
  }
}

// Add error handling for unhandled promises
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Run the tests
testMcpServers().catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});