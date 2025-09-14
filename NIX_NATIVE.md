# Nix-Native Deebo-Prototype

This document describes the Nix-native features added to deebo-prototype for enhanced sandbox isolation and reproducible debugging environments.

## Overview

The Nix-native deebo-prototype leverages Nix's built-in sandboxing capabilities to provide:

- **Stronger isolation** than Docker containers using Nix's chroot and namespace isolation
- **Reproducible debugging environments** with deterministic tool versions
- **Declarative configuration** using Nix expressions and flakes
- **Zero-overhead sandboxing** without container runtime dependencies

## Prerequisites

### Nix Installation and Configuration

Deebo-prototype requires Nix with experimental features enabled. Ensure you have:

1. **Nix installed** (version 2.4+ recommended)
2. **Experimental features enabled** for `nix-command` and `flakes`

**Enable experimental features (choose one method):**

```bash
# Method 1: Environment variable (recommended for CI)
export NIX_CONFIG="experimental-features = nix-command flakes"

# Method 2: Command line flags
nix --extra-experimental-features nix-command flakes <command>

# Method 3: Nix configuration file (~/.config/nix/nix.conf)
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

**For CI/CD environments:**
```yaml
env:
  NIX_CONFIG: "experimental-features = nix-command flakes"
```

### Verification

Test your Nix setup:
```bash
nix flake check --no-build  # Should work without errors
nix build .#default         # Should build successfully
nix develop                 # Should enter development shell
```

## Features

### 1. Nix Sandbox Execution (`nix_sandbox_exec`)

Execute code in isolated Nix sandbox environments:

```bash
# Enable Nix-native mode
export DEEBO_NIX_SANDBOX_ENABLED=1

# Or use the --nix-native flag
node build/index.js --nix-native
```

**Sandbox Features:**
- Filesystem isolation (read-only `/nix/store`, isolated `/tmp`)
- Network access disabled during execution
- Minimal build user privileges
- Controlled environment variables
- Deterministic execution (SOURCE_DATE_EPOCH set)

**Example Usage:**
```json
{
  "tool": "nix_sandbox_exec",
  "arguments": {
    "name": "test-python-script",
    "code": "print('Hello from Nix sandbox!')",
    "language": "python",
    "allowedPaths": ["/path/to/data"],
    "env": {"DEBUG": "1"},
    "timeout": 30000
  }
}
```

### 2. Nix Flake Environments (`nix_flake_init`)

Create reproducible debugging environments using Nix flakes:

**Supported Languages:**
- Python (with debugpy)
- Node.js/TypeScript
- Rust (with rust-analyzer, gdb)
- Go (with gopls, delve)
- Mixed (multi-language environments)

**Example Usage:**
```json
{
  "tool": "nix_flake_init", 
  "arguments": {
    "sessionId": "session-123456",
    "language": "python",
    "projectPath": "/path/to/project"
  }
}
```

This creates a `flake.nix` with:
- Language-specific tools and debuggers
- Consistent tool versions across systems
- Isolated workspace structure
- Development shell with proper environment

### 3. Flake Templates

Pre-configured flake templates for common debugging scenarios:

#### Debug Session Template (`templates/debug-session/`)
- Multi-language debugging environment
- Debugging utilities (gdb, strace, valgrind)
- Text processing tools (ripgrep, fd, jq)
- Isolated workspace setup

#### Scenario Agent Template (`templates/scenario-agent/`)
- Isolated execution environment for scenario agents
- Nix sandbox utilities
- Process isolation and logging
- Scenario runner scripts

## Installation & Setup

### 1. Install Nix

```bash
# Multi-user installation (recommended)
sh <(curl -L https://nixos.org/nix/install) --daemon

# Single-user installation
sh <(curl -L https://nixos.org/nix/install) --no-daemon
```

### 2. Enable Flakes (if not already enabled)

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### 3. Clone and Build

```bash
git clone https://github.com/RyzeNGrind/deebo-prototype.git
cd deebo-prototype

# Enter Nix development environment
nix develop

# Build the project
npm run build

# Run with Nix-native features
npm start -- --nix-native
```

### 4. MCP Configuration

Configure your MCP client to use the Nix-native server:

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
        "DEEBO_NIX_SANDBOX_ENABLED": "1",
        "NIX_CONFIG": "sandbox = true"
      },
      "transportType": "stdio"
    }
  }
}
```

## Nix vs Docker Comparison

| Feature | Docker | Nix Sandbox |
|---------|---------|-------------|
| **Isolation** | Container namespaces | chroot + namespaces |
| **Overhead** | Container runtime | Zero runtime overhead |
| **Reproducibility** | Image-based | Hash-based derivations |
| **Security** | User namespaces | Build user isolation |
| **Networking** | Configurable | Disabled by default |
| **Filesystem** | Layered filesystem | Read-only /nix/store |
| **Determinism** | Image-dependent | Built-in (SOURCE_DATE_EPOCH) |

## Advanced Configuration

### Custom Sandbox Options

```typescript
const config: NixSandboxConfig = {
  name: "advanced-sandbox",
  code: "#!/bin/bash\necho 'Custom sandbox execution'",
  language: "bash",
  allowedPaths: ["/project/data", "/tmp/workspace"],
  env: {
    "CUSTOM_VAR": "value",
    "DEBUG_MODE": "1"
  },
  timeout: 60000
};
```

### Custom Flake Generation

```typescript
// Generate custom debugging flake
const flakeContent = generateDebuggingFlake("rust", "/path/to/rust/project");
```

### Nix Utilities in Scenario Agents

```bash
# Source Nix utilities in scenario agents
source /path/to/deebo/lib/nix-utils.sh

# Execute code in sandbox
nix_sandbox_exec "cargo test" "rust"

# Check if running in Nix sandbox
if is_nix_sandbox; then
  echo "Running in secure Nix environment"
fi

# Get sandbox information
get_sandbox_info
```

## Security Benefits

1. **Filesystem Isolation**: Only `/nix/store` and explicitly allowed paths accessible
2. **Network Isolation**: No network access during sandbox execution
3. **User Isolation**: Dedicated build user with minimal privileges
4. **Deterministic Environment**: Controlled environment variables and timestamps
5. **No Privilege Escalation**: Cannot escape sandbox boundaries
6. **Audit Trail**: All sandbox executions logged and traceable

## Troubleshooting

### Nix Not Available
If Nix is not installed, the system falls back to compatibility mode:
```
⚠️  Running in compatibility mode (Nix sandbox disabled)
```

### Sandbox Failures
Check sandbox configuration:
```bash
nix show-config | grep sandbox
```

Enable sandbox mode:
```bash
echo "sandbox = true" >> ~/.config/nix/nix.conf
```

### Flake Errors
Ensure flakes are enabled:
```bash
nix-env --version  # Check Nix version (2.4+ recommended)
nix flake show     # Test flake functionality
```

## Performance Considerations

- **Cold Start**: First Nix sandbox execution may be slow due to store population
- **Caching**: Subsequent executions benefit from Nix store caching
- **Build Time**: Nix expressions are evaluated and built on first use
- **Memory**: Lower memory overhead compared to Docker containers
- **Storage**: Nix store deduplication reduces disk usage

## Contributing

To contribute Nix-native features:

1. Test changes in development environment: `nix develop`
2. Validate sandbox functionality: Use `nix_sandbox_exec` tool
3. Update flake templates in `templates/` directory
4. Document new Nix features in this README
5. Ensure compatibility with non-Nix systems (fallback mode)

## References

- [Nix Package Manager](https://nixos.org/manual/nix/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Nix Sandbox](https://nixos.org/manual/nix/stable/advanced-topics/diff-hook.html)
- [Model Context Protocol](https://spec.modelcontextprotocol.io/)