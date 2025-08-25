# Nix-Native Deebo-Prototype Examples

This file demonstrates how to use the new Nix-native features of deebo-prototype.

## Setup

First, ensure you have the Nix-native version running:

```bash
# Method 1: Direct execution with Nix-native flag
npm start -- --nix-native

# Method 2: Environment variable
export DEEBO_NIX_SANDBOX_ENABLED=1
npm start

# Method 3: Using Nix flake (when available)
nix run github:RyzeNGrind/deebo-prototype#deebo-prototype -- --nix-native
```

## Example 1: Nix Sandbox Code Execution

### Python Script in Sandbox

```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "test-python-analysis",
    "code": "import sys\nprint(f'Python version: {sys.version}')\nprint('Running in Nix sandbox!')\n\n# Test file operations\nwith open('/tmp/test.txt', 'w') as f:\n    f.write('Hello from sandbox!')\n\nwith open('/tmp/test.txt', 'r') as f:\n    print(f'File content: {f.read()}')",
    "language": "python",
    "timeout": 15000
  }
}
```

Expected output:
```
Nix Sandbox Execution: test-python-analysis

Success: true
Exit Code: 0
Language: python

=== STDOUT ===
Python version: 3.x.x
Running in Nix sandbox!
File content: Hello from sandbox!

🔐 Executed in Nix sandbox with strict isolation:
- Filesystem: Limited to /nix/store + allowed paths
- Network: Disabled
- User privileges: Minimal build user
- Environment: Controlled and reproducible
```

### Node.js Script with Environment Variables

```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "node-env-test",
    "code": "console.log('Node.js version:', process.version);\nconsole.log('Custom env var:', process.env.CUSTOM_VAR);\nconsole.log('Working directory:', process.cwd());\nconsole.log('Available commands:');\nconst { execSync } = require('child_process');\ntry {\n  const result = execSync('ls /usr/bin | head -5', { encoding: 'utf8' });\n  console.log(result);\n} catch (e) {\n  console.log('Limited command access (expected in sandbox)');\n}",
    "language": "nodejs",
    "env": {
      "CUSTOM_VAR": "sandbox-test",
      "DEBUG": "1"
    },
    "timeout": 20000
  }
}
```

### Bash Script with File Analysis

```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "bash-file-analysis",
    "code": "#!/bin/bash\necho 'Bash script in Nix sandbox'\necho 'Available tools:'\nwhich git || echo 'git not available'\nwhich node || echo 'node not available'\nwhich python3 || echo 'python3 not available'\n\necho 'Filesystem restrictions:'\nls / 2>/dev/null | head -10 || echo 'Root filesystem access restricted'\n\necho 'Creating test file:'\necho 'test data' > /tmp/sandbox-test.txt\ncat /tmp/sandbox-test.txt\n\necho 'Sandbox environment complete'",
    "language": "bash",
    "allowedPaths": ["/tmp"],
    "timeout": 25000
  }
}
```

## Example 2: Debugging Environment Initialization

### Python Project Environment

```json
{
  "tool": "nix_flake_init",
  "arguments": {
    "sessionId": "session-1234567890",
    "language": "python",
    "projectPath": "/path/to/python/project"
  }
}
```

This creates a `flake.nix` with:
- Python 3 runtime
- pip package manager
- debugpy for debugging
- Common development tools

### Node.js/TypeScript Project Environment

```json
{
  "tool": "nix_flake_init",
  "arguments": {
    "sessionId": "session-1234567890",
    "language": "nodejs",
    "projectPath": "/path/to/nodejs/project"
  }
}
```

This creates a `flake.nix` with:
- Node.js runtime
- npm package manager
- TypeScript compiler
- Development utilities

### Multi-language Project Environment

```json
{
  "tool": "nix_flake_init",
  "arguments": {
    "sessionId": "session-1234567890",
    "language": "mixed",
    "projectPath": "/path/to/mixed/project"
  }
}
```

This creates a comprehensive environment with:
- Python 3, Node.js, Rust, Go runtimes
- All associated package managers
- Cross-language debugging tools
- Text processing utilities

## Example 3: Complete Debugging Workflow

### Step 1: Start Debug Session

```json
{
  "tool": "start",
  "arguments": {
    "error": "TypeError: Cannot read property 'length' of undefined",
    "repoPath": "/path/to/buggy/project",
    "context": "Error occurs in data processing function when handling empty arrays",
    "language": "typescript",
    "filePath": "src/data-processor.ts"
  }
}
```

### Step 2: Initialize Nix Environment

```json
{
  "tool": "nix_flake_init",
  "arguments": {
    "sessionId": "session-1234567890",
    "language": "nodejs",
    "projectPath": "/path/to/buggy/project"
  }
}
```

### Step 3: Test Hypothesis in Sandbox

```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "hypothesis-null-check",
    "code": "// Test null/undefined handling\nconst data = undefined;\nconsole.log('Testing undefined data:');\ntry {\n  console.log('Length:', data.length);\n} catch (e) {\n  console.log('Error caught:', e.message);\n}\n\n// Test fix\nconst safeLength = data?.length ?? 0;\nconsole.log('Safe length:', safeLength);",
    "language": "nodejs",
    "allowedPaths": ["/path/to/buggy/project"],
    "timeout": 15000
  }
}
```

### Step 4: Validate Fix in Sandbox

```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "validate-fix",
    "code": "// Validate the fix with test cases\nfunction processData(data) {\n  if (!data || !Array.isArray(data)) {\n    console.log('Invalid data provided');\n    return [];\n  }\n  return data.filter(item => item.length > 0);\n}\n\n// Test cases\nconsole.log('Test 1 (undefined):', processData(undefined));\nconsole.log('Test 2 (null):', processData(null));\nconsole.log('Test 3 (empty array):', processData([]));\nconsole.log('Test 4 (valid data):', processData(['a', 'b', 'c']));",
    "language": "nodejs",
    "timeout": 15000
  }
}
```

## Example 4: Security and Isolation Testing

### Network Isolation Test

```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "network-isolation-test",
    "code": "const https = require('https');\nconsole.log('Testing network access in sandbox...');\n\nconst req = https.get('https://httpbin.org/ip', (res) => {\n  console.log('Network access successful (unexpected!)');\n}).on('error', (err) => {\n  console.log('Network access blocked (expected):', err.code);\n});\n\nsetTimeout(() => {\n  req.destroy();\n  console.log('Network isolation test complete');\n}, 3000);",
    "language": "nodejs",
    "timeout": 10000
  }
}
```

### Filesystem Isolation Test

```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "filesystem-isolation-test",
    "code": "import os\nimport sys\n\nprint('Testing filesystem access in sandbox...')\n\n# Test read-only access to system directories\ntry:\n    os.listdir('/etc')\n    print('ERROR: /etc should not be accessible')\nexcept PermissionError:\n    print('✓ /etc access properly restricted')\n\n# Test write access to home directory\ntry:\n    with open('/home/test.txt', 'w') as f:\n        f.write('test')\n    print('ERROR: Home directory should not be writable')\nexcept (PermissionError, FileNotFoundError):\n    print('✓ Home directory write access properly restricted')\n\n# Test /tmp access (should work)\ntry:\n    with open('/tmp/sandbox-test.txt', 'w') as f:\n        f.write('sandbox test')\n    print('✓ /tmp access works as expected')\nexcept Exception as e:\n    print(f'Unexpected error with /tmp: {e}')\n\nprint('Filesystem isolation test complete')",
    "language": "python",
    "timeout": 15000
  }
}
```

## Example 5: Template Usage

### Using Debug Session Template

```bash
# Create a new debugging session using the template
nix flake init --template github:RyzeNGrind/deebo-prototype#debug-session

# Enter the debugging environment
nix develop

# Now you have access to:
# - Multi-language runtimes (Python, Node.js, Rust, Go)
# - Debugging tools (gdb, strace, valgrind)
# - Text processing (ripgrep, fd, jq)
# - Isolated workspace structure
```

### Using Scenario Agent Template

```bash
# Create scenario agent environment
nix flake init --template github:RyzeNGrind/deebo-prototype#scenario-agent

# Build the scenario runner
nix build

# Execute a scenario
./result/bin/run-scenario "scenario-1" "Null pointer hypothesis" "/path/to/repo" "session-123"
```

## Integration with MCP Clients

### Claude Desktop Configuration

```json
{
  "mcpServers": {
    "deebo-nix": {
      "command": "nix",
      "args": [
        "run",
        "github:RyzeNGrind/deebo-prototype#deebo-prototype",
        "--",
        "--nix-native"
      ],
      "env": {
        "MOTHER_MODEL": "claude-3-5-sonnet-20241022",
        "SCENARIO_MODEL": "claude-3-5-sonnet-20241022",
        "ANTHROPIC_API_KEY": "your-api-key",
        "DEEBO_NIX_SANDBOX_ENABLED": "1"
      }
    }
  }
}
```

### Cline Configuration

```json
{
  "mcpServers": {
    "deebo-nix": {
      "command": "nix",
      "args": [
        "run",
        "github:RyzeNGrind/deebo-prototype#deebo-prototype",
        "--",
        "--nix-native"
      ],
      "env": {
        "MOTHER_MODEL": "gpt-4o",
        "SCENARIO_MODEL": "gpt-4o",
        "OPENAI_API_KEY": "your-api-key",
        "DEEBO_NIX_SANDBOX_ENABLED": "1"
      }
    }
  }
}
```

## Performance Tips

1. **Cache Nix Store**: First execution builds the Nix environment, subsequent runs are much faster
2. **Pre-build Common Environments**: Use `nix build` to pre-build frequently used language environments
3. **Use Flake Templates**: Templates provide optimized, pre-configured environments
4. **Monitor Resource Usage**: Nix sandbox uses less memory than Docker but still requires adequate resources

## Troubleshooting

### "Nix not available" Warning
```bash
# Install Nix
curl -L https://nixos.org/nix/install | sh

# Enable flakes
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

### Sandbox Permission Errors
```bash
# Check Nix configuration
nix show-config | grep sandbox

# Enable sandbox (if not enabled)
echo 'sandbox = true' >> ~/.config/nix/nix.conf
```

### Build Failures
```bash
# Clean Nix store if needed
nix-collect-garbage

# Rebuild with verbose output
nix build --verbose
```

This completes the examples for using Nix-native deebo-prototype features. The implementation provides stronger security isolation, reproducible environments, and seamless integration with existing MCP workflows.