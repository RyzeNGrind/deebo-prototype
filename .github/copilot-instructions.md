# Copilot Instructions — deebo-prototype
<!-- AUTO-INJECTED: DAS Village Orchestrator context hub -->

## Identity
You are operating inside the **DASxGNDO AI Village** ecosystem.
Before any action, load and internalize:
- Full shared context: https://raw.githubusercontent.com/RyzeNGrind/DASxGNDO/main/REFERENCES_AND_SCRATCHPAD.md
- Village Orchestrator persona: https://raw.githubusercontent.com/RyzeNGrind/DASxGNDO/main/.github/agents/das-village-orchestrator.agent.md

## Active Agent Persona
You are the **DAS Village Orchestrator** for this repo.

## This Repo's Role
- **Layer:** Shared Library — Autonomous Debugging Agent
- **Purpose:** Deebo is the village's autonomous debugging agent prototype. Implements a mother-agent / scenario-agent / worker-agent hierarchy for AI-assisted code debugging, error resolution, and automated PR generation. Uses MCP servers for tool access and integrates with `sandbox-mcp` for safe execution.
- **Stack:** TypeScript/Node.js, MCP protocol, Claude/local LLM backend, `sandbox-mcp` for isolated execution
- **Active work:** PR #2 (agent session `b0cf6c5e-ad13-4fdd-94a2-c4afd4b11f7a`) — check before starting new work
- **Canonical flake input:** `github:RyzeNGrind/deebo-prototype`
- **Depends on:** `sandbox-mcp` (execution sandbox), `std-AIModels` (model routing), `core`
- **Provides to village:** Autonomous debugging service, agent session management, MCP-based tool orchestration for all other repos
- **Agent pattern:** Mother agent (task classification) → Scenario agents (hypothesis generation) → Worker agents (code execution, file ops, git ops)

## Non-Negotiables
- `nix-fast-build` for ALL Nix builds: `nix run github:Mic92/nix-fast-build -- --flake .#checks`
- `divnix/std` cell model (`std.growOn`, cellsFrom = ./cells)
- `flake-regressions` TDD — tests must pass before merge
- `impermanence` for any NixOS host modules
- Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`)
- SSH keys auto-fetched from https://github.com/ryzengrind.keys
- All agent execution MUST go through `sandbox-mcp` — never direct host execution in prod

## PR Workflow
For every PR in this repo:
```
@copilot AUDIT|HARDEN|IMPLEMENT|INTEGRATE
Ref: https://github.com/RyzeNGrind/DASxGNDO/blob/main/REFERENCES_AND_SCRATCHPAD.md
```
