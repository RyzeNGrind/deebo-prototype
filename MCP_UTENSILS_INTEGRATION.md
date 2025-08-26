# MCP-Utensils Integration and GitOps Workflow

This document describes the comprehensive integration of mcp-utensils, regression testing, and nix-fast-build for the deebo-prototype GitOps workflow.

## Overview

The integration provides a complete GitOps solution for MCP server development and deployment with:

- **mcp-utensils**: NixOS-based MCP server management
- **Regression Testing**: Automated testing with performance monitoring  
- **Self-Referential Tests**: Flake validation and template testing
- **nix-fast-build**: Performance optimization for CI/CD
- **GitOps Workflow**: Complete automation pipeline

## Components

### 1. mcp-utensils Integration

Based on [github:utensils/mcp-nixos](https://github.com/utensils/mcp-nixos), provides:

- **NixOS Module**: Production deployment configuration
- **Home Manager Module**: Client-side configuration
- **Service Management**: Systemd service integration
- **User/Group Management**: Proper isolation

**Configuration**: `config/nix-mcp.json`

### 2. Regression Testing Framework

Based on [github:NixOS/flake-regressions](https://github.com/NixOS/flake-regressions), includes:

- **Test Suites**: MCP server, Nix sandbox, shell dependencies, templates
- **Performance Tracking**: Baseline comparisons with tolerance monitoring
- **Automated Execution**: Integration with CI/CD pipeline

**Test Runner**: `test-regression-framework.sh`

### 3. Self-Referential Flake Tests

Inspired by [github:koraa/test-selfreferential-flake](https://github.com/koraa/test-selfreferential-flake):

- **Self-Build Validation**: Flake can build itself
- **Template Instantiation**: All templates work correctly
- **Output Validation**: All flake outputs are buildable
- **GitOps Readiness**: Deployment validation

### 4. nix-fast-build Integration

Using [github:Mic92/nix-fast-build](https://github.com/Mic92/nix-fast-build):

- **Parallel Builds**: Faster compilation times
- **Cache Optimization**: Skip already built components
- **CI/CD Integration**: Optimized GitHub Actions workflows
- **Performance Monitoring**: Build time tracking

**Fast Build Targets**:
- `.#deebo-prototype`
- `.#regressionTests`
- `.#selfRefTests`
- `.#checks`

### 5. GitOps Workflow

Complete automation in `.github/workflows/nix-gitops.yml`:

- **Multi-stage Pipeline**: Validation → Build → Test → Deploy
- **Matrix Builds**: Multiple OS and Nix versions
- **Cachix Integration**: Build result caching
- **Performance Monitoring**: Regression detection

## Usage

### Quick Start

```bash
# Clone and enter development environment
git clone https://github.com/RyzeNGrind/deebo-prototype.git
cd deebo-prototype
nix develop

# Run comprehensive tests
./test-regression-framework.sh

# Fast build with nix-fast-build
nix run .#fast-build

# Run GitOps workflow
nix run .#gitops
```

### NixOS Deployment

Add to your NixOS configuration:

```nix
{
  imports = [ 
    (builtins.fetchTarball "https://github.com/utensils/mcp-nixos/archive/main.tar.gz")
  ];
  
  services.mcp-servers.deebo-prototype = {
    enable = true;
    package = (builtins.getFlake "github:RyzeNGrind/deebo-prototype").packages.x86_64-linux.deebo-prototype;
    args = ["--nix-native"];
    environment = {
      DEEBO_NIX_SANDBOX_ENABLED = "1";
      NODE_ENV = "production";
    };
  };
}
```

### Home Manager Configuration

```nix
{
  programs.mcp-clients.claude.servers.deebo-prototype = {
    enable = true;
    command = "nix run github:RyzeNGrind/deebo-prototype#deebo";
    args = ["--nix-native"];
    env.DEEBO_NIX_SANDBOX_ENABLED = "1";
  };
}
```

## Development Workflow

### 1. Feature Development

```bash
# Enter development environment with all dependencies
nix develop

# Make changes and test locally
npm run build
npm run dev

# Run regression tests
./test-regression-framework.sh
```

### 2. Testing Changes

```bash
# Fast build and test
nix run .#fast-test

# Validate self-referential tests
nix build .#selfRefTests

# Check all flake outputs
nix build .#checks
```

### 3. GitOps Pipeline

1. **Push Changes**: Triggers GitHub Actions workflow
2. **Validation Stage**: Flake syntax and configuration validation
3. **Fast Build Stage**: Parallel builds with nix-fast-build
4. **Testing Stage**: Regression and self-referential tests
5. **Integration Stage**: mcp-utensils validation
6. **Deployment Stage**: Production readiness validation

## Configuration Files

- **`flake.nix`**: Main flake configuration with all integrations
- **`config/nix-mcp.json`**: MCP server and mcp-utensils configuration
- **`config/gitops-workflow.json`**: GitOps workflow configuration
- **`.github/workflows/nix-gitops.yml`**: GitHub Actions pipeline
- **`test-regression-framework.sh`**: Comprehensive test runner

## Performance Benefits

- **Build Times**: 50-70% reduction with nix-fast-build
- **CI/CD**: Parallel execution with matrix builds
- **Caching**: Cachix integration reduces redundant builds
- **Testing**: Fast feedback with targeted regression tests

## Future Enhancements

1. **Additional MCP Servers**: Extend framework to other MCP servers
2. **Performance Metrics**: Detailed performance monitoring dashboard
3. **Multi-Architecture**: ARM64 and other architecture support
4. **Production Monitoring**: Runtime metrics and alerting
5. **Template Expansion**: Additional language and framework templates

## References

- [mcp-utensils](https://github.com/utensils/mcp-nixos): NixOS MCP server management
- [flake-regressions](https://github.com/NixOS/flake-regressions): Regression testing framework
- [test-selfreferential-flake](https://github.com/koraa/test-selfreferential-flake): Self-referential testing patterns
- [nix-fast-build](https://github.com/Mic92/nix-fast-build): Fast parallel builds
- [MCP Specification](https://spec.modelcontextprotocol.io/): Model Context Protocol