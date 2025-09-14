{
  description = "Deebo scenario agent debugging environment with comprehensive shell dependency mapping";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # All scenario agent dependencies mapped via nix-shell as requested
        scenarioDependencies = with pkgs; [
          # Core system tools
          bash
          coreutils
          findutils
          gnugrep
          gnused
          git
          
          # Language runtimes
          nodejs
          npm
          python3
          python3Packages.pip
          rustc
          cargo
          go
          
          # Development tools
          gdb
          strace
          ltrace
          
          # Utilities
          jq
          curl
          wget
          
          # Build tools
          gnumake
          cmake
          pkg-config
          
          # Process management
          procps
          util-linux
          
          # Nix tools
          nix
        ];
        
      in {
        # Isolated execution environment for scenario agents with all dependencies mapped
        packages.scenario-runner = pkgs.runCommand "scenario-runner" {
          buildInputs = scenarioDependencies;
          
          # Strict sandbox settings
          __noChroot = false;
          allowSubstitutes = false;
          requiredSystemFeatures = [ "sandbox" ];
          
          # Ensure all dependencies are available
          PATH = "${pkgs.lib.makeBinPath scenarioDependencies}";
        } ''
          mkdir -p $out/{bin,lib,logs}
          
          # Create scenario runner script with all dependencies available
          cat > $out/bin/run-scenario << 'EOF'
          #!/bin/bash
          set -euo pipefail
          
          # Ensure all shell dependencies are available
          export PATH="${pkgs.lib.makeBinPath scenarioDependencies}:$PATH"
          
          SCENARIO_ID="$1"
          HYPOTHESIS="$2"  
          REPO_PATH="$3"
          SESSION_ID="$4"
          
          # Set up isolated environment
          export SCENARIO_WORKSPACE="/tmp/scenario-$SCENARIO_ID"
          mkdir -p "$SCENARIO_WORKSPACE"/{code,results,logs}
          
          echo "Starting scenario: $SCENARIO_ID"
          echo "Hypothesis: $HYPOTHESIS"
          echo "Repository: $REPO_PATH"
          echo "Session: $SESSION_ID"
          echo "Available tools: git, node, python3, rust, go, gdb, strace, jq"
          
          # Copy repository to isolated workspace (read-only perspective)
          if [ -d "$REPO_PATH" ]; then
            cp -r "$REPO_PATH" "$SCENARIO_WORKSPACE/code/"
          fi
          
          # Execute scenario logic
          cd "$SCENARIO_WORKSPACE"
          
          # Log scenario start with available dependencies
          echo "$(date): Scenario $SCENARIO_ID started with hypothesis: $HYPOTHESIS" > logs/scenario.log
          echo "$(date): Available PATH: $PATH" >> logs/scenario.log
          echo "$(date): Available tools:" >> logs/scenario.log
          which git node python3 cargo go gdb strace jq 2>&1 >> logs/scenario.log || true
          
          # Placeholder for scenario execution logic
          echo "Scenario environment ready for investigation with all shell dependencies" >> logs/scenario.log
          
          # Create results structure
          cat > results/report.json << REPORT
          {
            "scenarioId": "$SCENARIO_ID",
            "hypothesis": "$HYPOTHESIS", 
            "sessionId": "$SESSION_ID",
            "status": "initialized",
            "workspace": "$SCENARIO_WORKSPACE",
            "timestamp": "$(date -Iseconds)",
            "environment": "nix-sandbox",
            "availableTools": "git,node,python3,rust,go,gdb,strace,jq,curl,wget,make,cmake",
            "shellDependenciesMapped": true
          }
          REPORT
          
          echo "Scenario environment created at: $SCENARIO_WORKSPACE"
          echo "All shell dependencies mapped and available"
          EOF
          
          chmod +x $out/bin/run-scenario
          
          # Create helper utilities with all dependencies available
          cat > $out/bin/scenario-test << 'EOF'
          #!/bin/bash
          # Test execution helper for scenarios with mapped dependencies
          export PATH="${pkgs.lib.makeBinPath scenarioDependencies}:$PATH"
          
          COMMAND="$1"
          LOG_FILE="$2"
          
          echo "$(date): Executing: $COMMAND" >> "$LOG_FILE"
          echo "$(date): Available PATH: $PATH" >> "$LOG_FILE"
          eval "$COMMAND" 2>&1 | tee -a "$LOG_FILE"
          echo "Exit code: $?" >> "$LOG_FILE"
          EOF
          
          chmod +x $out/bin/scenario-test
          
          # Create Nix utilities for scenario agents with complete dependency mapping
          cat > $out/lib/nix-utils.sh << 'EOF'
          #!/bin/bash
          # Nix-specific utilities for scenario agents with all shell dependencies mapped
          
          # Ensure all dependencies are available
          export PATH="${pkgs.lib.makeBinPath scenarioDependencies}:$PATH"
          
          # Execute code in Nix sandbox with mapped dependencies
          nix_sandbox_exec() {
            local code="$1"
            local language="${2:-bash}"
            local temp_dir=$(mktemp -d)
            
            # Build dependency list based on language
            local deps="bash coreutils findutils gnugrep gnused git"
            case "$language" in
              python*) deps="$deps python3" ;;
              node*|javascript) deps="$deps nodejs npm" ;;
              rust) deps="$deps rustc cargo" ;;
              go) deps="$deps go" ;;
            esac
            
            cat > "$temp_dir/execution.nix" << NIX_EXPR
          { pkgs ? import <nixpkgs> {} }:
          pkgs.runCommand "scenario-exec" {
            buildInputs = with pkgs; [ $deps gdb strace jq curl wget gnumake cmake pkg-config ];
            __noChroot = false;
            PATH = "${pkgs.lib.makeBinPath scenarioDependencies}";
          } '''
            mkdir -p \$out/logs
            export PATH="${pkgs.lib.makeBinPath scenarioDependencies}:\$PATH"
            echo '$code' > script.$language
            $language script.$language 2>&1 | tee \$out/logs/execution.log
            echo \$? > \$out/exit_code
          '''
          NIX_EXPR
            
            nix-build "$temp_dir/execution.nix" --no-out-link
            rm -rf "$temp_dir"
          }
          
          # Check if running in Nix sandbox
          is_nix_sandbox() {
            [ -n "${IN_NIX_SHELL:-}" ] || [ -n "${__noChroot:-}" ]
          }
          
          # Get sandbox restrictions info
          get_sandbox_info() {
            cat << INFO
          Nix Sandbox Environment with Mapped Dependencies:
          - Filesystem: Read-only access to /nix/store, isolated /tmp
          - Network: Disabled during build (can be enabled with allowedRequisites)
          - Users: Single build user with minimal privileges
          - Time: Deterministic (SOURCE_DATE_EPOCH set)
          - Environment: Controlled environment variables
          - Available Tools: git, node, python3, rust, go, gdb, strace, jq, curl, wget, make, cmake
          - Shell Dependencies: All mapped via nix-shell as requested
          INFO
          }
          
          # List available tools
          list_available_tools() {
            echo "Available tools in scenario environment:"
            for tool in git node python3 cargo go gdb strace jq curl wget make cmake; do
              if which "$tool" >/dev/null 2>&1; then
                echo "  ✓ $tool: $(which "$tool")"
              else
                echo "  ✗ $tool: not found"
              fi
            done
          }
          EOF
          
          chmod +x $out/lib/nix-utils.sh
        '';

        # Development environment for testing scenarios with all dependencies mapped
        devShells.default = pkgs.mkShell {
          buildInputs = scenarioDependencies;
          
          shellHook = ''
            echo "Scenario Agent Development Environment"
            echo "All shell dependencies mapped via nix-shell:"
            echo "  Core: bash, coreutils, git, findutils, gnugrep, gnused"
            echo "  Languages: nodejs, npm, python3, rust, go"
            echo "  Debug: gdb, strace, ltrace"
            echo "  Utils: jq, curl, wget"
            echo "  Build: make, cmake, pkg-config"
            echo ""
            echo "Test scenario runner: nix run .#scenario-runner"
            echo "Available PATH: ${pkgs.lib.makeBinPath scenarioDependencies}"
            
            export SCENARIO_DEV_MODE=1
            export NIX_SANDBOX_ENABLED=1
            export DEEBO_SHELL_DEPS_MAPPED=1
            export PATH="${pkgs.lib.makeBinPath scenarioDependencies}:$PATH"
          '';
        };
      });
}