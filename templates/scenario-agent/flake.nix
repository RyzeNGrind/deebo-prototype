{
  description = "Deebo scenario agent isolation environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        # Isolated execution environment for scenario agents
        packages.scenario-runner = pkgs.runCommand "scenario-runner" {
          buildInputs = with pkgs; [
            bash
            coreutils
            git
            nodejs
            python3
            findutils
            gnugrep
            gnused
          ];
          
          # Strict sandbox settings
          __noChroot = false;
          allowSubstitutes = false;
          requiredSystemFeatures = [ "sandbox" ];
        } ''
          mkdir -p $out/{bin,lib,logs}
          
          # Create scenario runner script
          cat > $out/bin/run-scenario << 'EOF'
          #!/bin/bash
          set -euo pipefail
          
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
          
          # Copy repository to isolated workspace (read-only perspective)
          if [ -d "$REPO_PATH" ]; then
            cp -r "$REPO_PATH" "$SCENARIO_WORKSPACE/code/"
          fi
          
          # Execute scenario logic
          cd "$SCENARIO_WORKSPACE"
          
          # Log scenario start
          echo "$(date): Scenario $SCENARIO_ID started with hypothesis: $HYPOTHESIS" > logs/scenario.log
          
          # Placeholder for scenario execution logic
          # This would be replaced by actual scenario agent code
          echo "Scenario environment ready for investigation" >> logs/scenario.log
          
          # Create results structure
          cat > results/report.json << REPORT
          {
            "scenarioId": "$SCENARIO_ID",
            "hypothesis": "$HYPOTHESIS",
            "sessionId": "$SESSION_ID",
            "status": "initialized",
            "workspace": "$SCENARIO_WORKSPACE",
            "timestamp": "$(date -Iseconds)",
            "environment": "nix-sandbox"
          }
          REPORT
          
          echo "Scenario environment created at: $SCENARIO_WORKSPACE"
          EOF
          
          chmod +x $out/bin/run-scenario
          
          # Create helper utilities
          cat > $out/bin/scenario-test << 'EOF'
          #!/bin/bash
          # Test execution helper for scenarios
          COMMAND="$1"
          LOG_FILE="$2"
          
          echo "$(date): Executing: $COMMAND" >> "$LOG_FILE"
          eval "$COMMAND" 2>&1 | tee -a "$LOG_FILE"
          echo "Exit code: $?" >> "$LOG_FILE"
          EOF
          
          chmod +x $out/bin/scenario-test
          
          # Create Nix utilities for scenario agents
          cat > $out/lib/nix-utils.sh << 'EOF'
          #!/bin/bash
          # Nix-specific utilities for scenario agents
          
          # Execute code in Nix sandbox
          nix_sandbox_exec() {
            local code="$1"
            local language="${2:-bash}"
            local temp_dir=$(mktemp -d)
            
            cat > "$temp_dir/execution.nix" << NIX_EXPR
          { pkgs ? import <nixpkgs> {} }:
          pkgs.runCommand "scenario-exec" {
            buildInputs = with pkgs; [ $language ];
            __noChroot = false;
          } '''
            mkdir -p \$out/logs
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
          Nix Sandbox Environment:
          - Filesystem: Read-only access to /nix/store, isolated /tmp
          - Network: Disabled during build (can be enabled with allowedRequisites)
          - Users: Single build user with minimal privileges
          - Time: Deterministic (SOURCE_DATE_EPOCH set)
          - Environment: Minimal, controlled environment variables
          INFO
          }
          EOF
          
          chmod +x $out/lib/nix-utils.sh
        '';

        # Development environment for testing scenarios
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            git
            nodejs
            python3
            nix
          ];
          
          shellHook = ''
            echo "Scenario Agent Development Environment"
            echo "Test scenario runner: nix run .#scenario-runner"
            
            export SCENARIO_DEV_MODE=1
            export NIX_SANDBOX_ENABLED=1
          '';
        };
      });
}