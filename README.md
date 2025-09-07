# Deebo: Your AI Agent's Debugging Copilot
[![CI Status](https://github.com/snagasuri/deebo-prototype/actions/workflows/basic-ci.yml/badge.svg)](https://github.com/snagasuri/deebo-prototype/actions/workflows/basic-ci.yml)
[![npm version](https://img.shields.io/npm/v/deebo-setup.svg)](https://www.npmjs.com/package/deebo-setup)
[![GitHub stars](https://img.shields.io/github/stars/snagasuri/deebo-prototype?style=social)](https://github.com/snagasuri/deebo-prototype)

**[www.bojack.ai](https://www.bojack.ai) From the creators of Deebo.**

**Bojack is a unified, AI-native DevOps platform based in the browser and terminal. No more dashboards, just answers.**


**Deebo is not maintained actively. Install at your own risk.**
Deebo is an agentic debugging copilot for your AI coding agent that speeds up time-to-resolution by 10x. If your main coding agent is like a single-threaded process, Deebo introduces multi-threadedness to your development workflow.

As seen on [PulseMCP](https://www.pulsemcp.com/servers/snagasuri-deebo), [@cline on X](https://x.com/cline/status/1915088556852453831), and the [official MCP directory](https://github.com/modelcontextprotocol/servers).

## 🔐 Nix-Native Security & Isolation

Deebo now supports **Nix-native sandbox execution** with comprehensive shell dependency mapping for enhanced security and reproducible debugging environments:

- **Complete shell dependency mapping** - All 31+ tools mapped via nix-shell (bash, nodejs, python3, gdb, ripgrep, etc.)
- **mcp-servers-nix framework integration** - Uses natsukium/mcp-servers-nix for NixOS/home-manager compatibility
- **Stronger isolation** than Docker using Nix's built-in sandboxing with hardened shell quoting  
- **Reproducible environments** with deterministic tool versions and locked dependencies
- **Zero-overhead sandboxing** without container runtime dependencies
- **Declarative configuration** using Nix expressions and flakes

### Quick Start with Nix

```bash
# Install Nix (if not already installed)
curl -L https://nixos.org/nix/install | sh

# Clone and run with comprehensive Nix-native features
git clone https://github.com/RyzeNGrind/deebo-prototype.git
cd deebo-prototype
nix develop  # Enters shell with all 31+ dependencies mapped
npm run build
npm start -- --nix-native
```

### Nix Features

- ✅ **Shell Dependencies**: All tools mapped via `nix-shell` (31+ dependencies)
- ✅ **Framework Integration**: Uses `mcp-servers-nix.lib.mkConfig` for standards-compliant MCP server configuration 
- ✅ **Security Hardening**: Improved shell quoting, argument escaping, command timeouts
- ✅ **Development Shell**: `nix develop` provides complete toolchain
- ✅ **Template System**: Nix flake templates for debugging workflows
- ✅ **Environment Variables**: `DEEBO_SHELL_DEPS_PATH` exposes mapped dependencies

Run `./validate-flake-syntax.sh` and `./validate-shell-deps-mapping.sh` to verify the implementation.

## 🛡️ Regression Testing & Change Safety

Deebo includes a comprehensive self-referential regression testing suite to prevent undetected breakage and ensure change safety through automated validation:

### Regression Prevention Architecture

- **🔄 Self-referential testing** - Compares current flake against `HEAD~1` to detect breaking changes
- **🚁 Pre-commit flight checks** - Validates all critical systems before allowing commits  
- **📊 Comprehensive change detection** - Monitors flake outputs, package builds, devShell integrity
- **⚡ Performance regression detection** - Prevents optimization degradation over time
- **📋 Artifact generation** - Creates detailed logs and diffs for reviewer transparency
- **🛡️ Multi-layer validation** - Combines syntax, build, functional, and performance checks

### Usage

```bash
# Run comprehensive regression tests
nix build .#checks.x86_64-linux.regression-tests

# Run pre-commit flight check (recommended before commits)
nix build .#checks.x86_64-linux.pre-commit-flight-check

# Run pre-commit hook script
./pre-commit-hook.sh

# Validate regression test infrastructure
./validate-regression-tests.sh
```

### Performance Optimization with nix-fast-build & hyperfine

This flake integrates **nix-fast-build** and **hyperfine** for maximum throughput and performance tracking:

```bash
# Use nix-fast-build for faster parallel builds (recommended for CI/development)
nix-fast-build .#default
nix-fast-build .#checks.x86_64-linux.nixos-mcp-e2e

# Benchmark build performance with hyperfine
hyperfine 'nix build .#default'
hyperfine 'nix flake check --no-build'

# Compare performance between different build approaches  
hyperfine 'nix build .#default' 'nix-fast-build .#default'

# Run comprehensive build performance benchmarking
nix build .#checks.x86_64-linux.build-performance-suite

# Access performance metrics and CI artifacts
ls result/results/  # JSON benchmark data, performance reports
ls result/artifacts/  # CI-ready performance artifacts
```

**Performance Regression Detection:**
- ⚡ **5-second threshold alerts** for build performance degradation
- 📊 **Hyperfine JSON artifacts** for trend analysis and CI integration  
- 🏃 **Automated benchmarking** in regression tests and pre-commit hooks
- 📈 **Performance comparison** against previous Git revisions
- 🚀 **Optimization recommendations** (nix-fast-build, lean builds, etc.)

**CI Performance Artifacts:**
All performance data is captured as CI artifacts with 14-day retention for investigation, trend analysis, and performance optimization tracking.

### What Gets Tested

**Output Structure Comparison**
- Compares flake output structure between revisions
- Detects removed/added packages, apps, devShells, checks
- Generates diff artifacts for review

**Critical Package Build Validation**  
- Tests package builds against current and previous revisions
- Detects build regressions and dependency changes
- Compares package outputs for consistency

**DevShell Environment Validation**
- Validates development shell environments work correctly
- Tests essential tools availability and versions
- Ensures environment variables are properly set

**Template Structure Validation**
- Verifies flake template integrity and paths
- Ensures template descriptions and structures are valid
- Prevents template corruption or missing files

**Performance Regression Detection**
- Monitors build times and resource usage
- Alerts on performance degradation (>5s threshold)
- Tracks optimization effectiveness over time

### Regression Report Generation

Each test run generates comprehensive reports:

```
regression-artifacts/
├── regression-report.md          # Comprehensive test summary
├── logs/                         # Detailed execution logs
│   ├── current-build.log
│   ├── previous-build.log  
│   ├── current-devshell.log
│   └── current-flake-check.log
└── artifacts/                    # Comparison artifacts
    ├── current-outputs.json
    ├── previous-outputs.json
    ├── outputs-diff.txt
    └── package-diff.txt
```

### CI Integration

The regression testing suite is fully integrated with GitHub Actions:

- **Automatic execution** on all pull requests and commits
- **Artifact preservation** - 14 days retention for investigation
- **Early failure detection** - Prevents broken changes from merging
- **Performance monitoring** - Tracks optimization regressions over time

### Pre-commit Hook Integration

Install the pre-commit hook for local validation:

```bash
# Install hook (run once)
ln -sf ../../pre-commit-hook.sh .git/hooks/pre-commit

# Hook will automatically run on every commit and validate:
# ✅ Basic flake syntax and structure
# ✅ Regression test infrastructure integrity
# ✅ Shell dependencies mapping
# ✅ Performance optimizations
# ✅ Nix flake comprehensive checks
# ✅ Build and functional validation
```

This comprehensive approach prevents hallucination-induced changes and ensures every commit maintains system integrity while providing full transparency through detailed artifacts and logging.

See [NIX_NATIVE.md](./NIX_NATIVE.md) for detailed documentation and [EXAMPLES.md](./EXAMPLES.md) for usage examples.

## Quick Install (legacy)

```bash
npx deebo-setup@latest
```

<details>
<summary> Manual Configuration </summary>

After installing with deebo-setup, create a configuration file at your coding agent's specified location with the following content. First, add the guide server (which provides help documentation even if the main installation fails):

```json
{
  "servers": {
    "deebo-guide": {
      "command": "node",
      "args": [
        "--experimental-specifier-resolution=node",
        "--experimental-modules",
        "/Users/[your-name]/.deebo/guide-server.js"
      ],
      "env": {},
      "transportType": "stdio"
    },
    "deebo": {
      "command": "node",
      "args": [
        "--experimental-specifier-resolution=node",
        "--experimental-modules",
        "--max-old-space-size=4096",
        "/Users/[your-name]/.deebo/build/index.js"
      ],
      "env": {
        "NODE_ENV": "development",
        "USE_MEMORY_BANK": "true",
        "MOTHER_HOST": "openrouter",
        "MOTHER_MODEL": "anthropic/claude-3.5-sonnet",
        "SCENARIO_HOST": "openrouter",
        "SCENARIO_MODEL": "deepseek/deepseek-chat",
        "OPENROUTER_API_KEY": "your-openrouter-api-key"
      }
    }
  }
}
```
Deebo works with any OpenAI-compatible SDK, Anthropic, Gemini, and OpenRouter.
</details>

<details>

<summary> Deebo Guide </summary>

Deebo helps your AI agent debug real software errors by launching automated investigations. Here's how to use it effectively.

---

### 1. Start a Debugging Session

When you hit a tough bug, ask your agent to delegate the task to Deebo.

**What to include in your request:**
- 🔧 The **error** (message, stack trace, or behavior)
- 📁 The **absolute path** to your Git repository
- 💡 Any helpful **context**, such as:
  - What you’ve already tried
  - Relevant files or code snippets
  - How to reproduce the issue
  - The language or environment

**Example instruction to your agent:**

> “This error is happening in `/path/to/repo`, possibly related to auth logic. I already checked the session token parser. Can you delegate this to Deebo?”

Your agent will start a Deebo session and give you a **session ID** (e.g. `session-1745...`). Save it.

---

### 2. Check Investigation Progress

After ~30 seconds, ask your agent to check the status of the Deebo session using that session ID.

You’ll get a **session pulse**, which shows:
- Whether the investigation is in progress or completed
- What the system is currently exploring
- Summaries of findings, if any

---

### 3. Add Observations (Optional)

If you notice something important — or think Deebo is heading the wrong way — you can guide the investigation.

Ask your agent to pass a short observation to Deebo.

**Example:**

> “Let Deebo know that the file size warnings might be a red herring — the issue is probably with the CI env vars.”

This may shift the direction of the investigation.

### 4. Cancel a Session (Optional)

If you fixed the issue or no longer need the investigation, tell your agent to cancel the Deebo session.

### For AI Agents: Memory Bank Access

When asked to check debug session progress, look in:
`~/.deebo/memory-bank/[project-hash]/sessions/[session-id]/logs/`

The project hash is a unique identifier for each repository, and session IDs are provided when starting a debug session.

### Want More?

We're piloting enterprise features that unlock unprecedented productivity gains for your team. Reach out if interested!
</details>
 
---
[Watch the full work session with Cline + Deebo here (3 mins, sped up)](https://drive.google.com/file/d/141VdQ9DNOfnOpP_mmB0UPMr8cwAGrxKC/view)

<video src="https://github.com/user-attachments/assets/a580ed7e-7f21-45db-91c6-2db1d3a1a174" controls width="100%"></video>

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
