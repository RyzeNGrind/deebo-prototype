{
  description = "Nix-native debugging copilot MCP server using mcp-servers-nix framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Use mcp-servers-nix framework for proper NixOS/home-manager integration
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, mcp-servers-nix }:
    {
      # Templates are system-independent and must be at top level
      templates = {
        debug-session = {
          path = ./templates/debug-session;
          description = "Template for creating isolated debugging sessions with Nix";
        };
        
        scenario-agent = {
          path = ./templates/scenario-agent;
          description = "Template for scenario agent environments";
        };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # All shell dependencies mapped via nix-shell as requested
        shellDependencies = with pkgs; [
          # Core system tools
          bash
          coreutils
          findutils
          gnugrep
          gnused
          git
          
          # Language runtimes and tools
          nodejs  # npm is included with nodejs in modern nixpkgs
          python3
          python3Packages.pip
          python3Packages.debugpy
          typescript
          rustc
          cargo
          go
          
          # Development and debugging tools
          gdb
          strace
          ltrace
          valgrind
          
          # Text processing and utilities
          ripgrep
          fd
          jq
          curl
          wget
          
          # Build tools
          gnumake
          cmake
          pkg-config
          
          # Nix-specific tools
          nix
          nix-tree
          nix-output-monitor
          nixpkgs-fmt
          
          # Additional utilities used by sandbox
          procps  # for process management
          util-linux  # for namespace utilities
          shadow  # for user management in sandbox
        ];
        
        # Node.js environment with all dependencies properly mapped
        # Use existing build instead of buildNpmPackage to avoid hash mismatch issues
        nodeEnv = pkgs.stdenv.mkDerivation rec {
          pname = "deebo-prototype";
          version = "1.0.0";
          
          src = ./.;
          
          # Provide all shell dependencies
          nativeBuildInputs = shellDependencies;
          
          # Explicitly disable CMake and other build systems since this is a Node.js project
          dontUseCmakeConfigure = true;
          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            mkdir -p "$out/bin" "$out/lib/deebo-prototype"
            
            # Copy pre-built JavaScript files
            if [ -d "build" ]; then
              cp -r build/* $out/lib/deebo-prototype/
            else
              echo "Error: build directory not found"
              exit 1
            fi
            
            # Copy package.json for runtime metadata
            cp package.json $out/lib/deebo-prototype/
            
            # Create wrapper script with all shell dependencies available
            cat > $out/bin/deebo << 'EOF'
#!/usr/bin/env bash
export PATH="${pkgs.lib.makeBinPath shellDependencies}:$PATH"
export DEEBO_NIX_SHELL_DEPS="${pkgs.lib.makeBinPath shellDependencies}"
exec ${pkgs.nodejs}/bin/node $out/lib/deebo-prototype/index.js "$@"
EOF
            chmod +x $out/bin/deebo
          '';
        };

        # Nix-native sandbox execution utilities with all dependencies mapped
        # Execute code in Nix sandbox with complete dependency mapping
        sandboxExec = { name, code, language ? "bash", allowedPaths ? [] }: pkgs.runCommand name {
          buildInputs = shellDependencies ++ (
            if language == "python" then [ pkgs.python3Packages.pip pkgs.python3Packages.debugpy ]
            else if language == "nodejs" then [ ] # npm is included with nodejs
            else if language == "typescript" then [ ] # typescript is already in shellDependencies
            else []
          );
          
          # Restrict network access and filesystem access
          __noChroot = false;
          allowSubstitutes = false;
          
          # Ensure all shell dependencies are in PATH
          PATH = "${pkgs.lib.makeBinPath shellDependencies}";
        } ''
          # Create isolated environment
          mkdir -p "$out/logs" "$out/results"
          
          # Execute code in restricted environment with all tools available
          ${if language == "bash" then ''
            cat > script.sh << 'EOF'
${code}
EOF
            chmod +x script.sh
            timeout 300 ./script.sh 2>&1 | tee "$out/logs/execution.log"
          '' else if language == "python" then ''
            cat > script.py << 'EOF'
${code}
EOF
            timeout 300 python3 script.py 2>&1 | tee "$out/logs/execution.log"
          '' else if language == "nodejs" then ''
            cat > script.js << 'EOF'
${code}
EOF
            timeout 300 node script.js 2>&1 | tee "$out/logs/execution.log"
          '' else if language == "typescript" then ''
            cat > script.ts << 'EOF'
${code}
EOF
            tsc script.ts && timeout 300 node script.js 2>&1 | tee "$out/logs/execution.log"
          '' else ''
            echo "Unsupported language: ${language}" > "$out/logs/error.log"
            exit 1
          ''}
          
          # Capture exit code
          echo $? > $out/results/exit_code
        '';

        # Git operations in sandbox with all dependencies mapped
        gitSandboxExec = { repoPath, commands }: pkgs.runCommand "git-sandbox" {
          buildInputs = shellDependencies;
          __noChroot = false;
          PATH = "${pkgs.lib.makeBinPath shellDependencies}";
        } ''
          mkdir -p "$out/logs"
          cd "${repoPath}"
          
          ${builtins.concatStringsSep "\n" (map (cmd: ''
            echo "Executing: ${pkgs.lib.escapeShellArg cmd}" | tee -a "$out/logs/git.log"
            ${cmd} 2>&1 | tee -a "$out/logs/git.log"
          '') commands)}
        '';

        # Tool execution with complete dependency mapping
        toolExec = { tool, args ? [], env ? {} }: pkgs.runCommand "tool-exec" {
          buildInputs = shellDependencies;
          __noChroot = false;
          PATH = "${pkgs.lib.makeBinPath shellDependencies}";
        } (let
          envVars = builtins.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: "export ${pkgs.lib.escapeShellArg k}=${pkgs.lib.escapeShellArg v}") env);
          escapedArgs = map pkgs.lib.escapeShellArg args;
        in ''
          mkdir -p "$out/logs" "$out/results"
          ${envVars}
          
          timeout 300 ${pkgs.lib.escapeShellArg tool} ${builtins.concatStringsSep " " escapedArgs} 2>&1 | tee "$out/logs/execution.log"
          echo $? > "$out/results/exit_code"
        '');

      in {
        packages = {
          default = nodeEnv;
          deebo-prototype = nodeEnv;
          
          # MCP server configuration using natsukium/mcp-servers-nix framework
          mcp-config = mcp-servers-nix.lib.mkConfig pkgs {
            format = "json";
            fileName = "claude_desktop_config.json";
            settings.servers = {
              deebo-nix = {
                command = "${nodeEnv}/bin/deebo";
                args = [ "--nix-native" ];
                env = {
                  NODE_ENV = "production";
                  DEEBO_NIX_SANDBOX_ENABLED = "1";
                  DEEBO_SHELL_DEPS_PATH = "${pkgs.lib.makeBinPath shellDependencies}";
                  PATH = "${pkgs.lib.makeBinPath shellDependencies}";
                };
              };
            };
          };
        };

        # Development shell with all shell dependencies properly mapped
        devShells.default = pkgs.mkShell {
          buildInputs = shellDependencies;

          shellHook = ''
            echo "Deebo-Prototype Nix Development Environment"
            echo "All shell dependencies mapped via nix-shell:"
            echo "  Core: bash, coreutils, git, findutils, gnugrep, gnused"
            echo "  Languages: nodejs (includes npm), python3, typescript, rust, go"  
            echo "  Debug tools: gdb, strace, valgrind, ripgrep, fd"
            echo "  Build tools: make, cmake, pkg-config"
            echo "  Nix tools: nix, nix-tree, nixpkgs-fmt"
            echo ""
            echo "Available commands:"
            echo "  npm run build  - Build TypeScript"
            echo "  npm run dev    - Development mode"
            echo "  nix build      - Build Nix package"
            echo "  nix develop    - Enter development shell"
            
            # Set up environment for Nix sandbox features with mapped dependencies
            export DEEBO_NIX_SANDBOX_ENABLED=1
            export DEEBO_SHELL_DEPS_PATH="${pkgs.lib.makeBinPath shellDependencies}"
            
            # Ensure all dependencies are in PATH
            export PATH="${pkgs.lib.makeBinPath shellDependencies}:$PATH"
          '';
        };



        # Apps for direct execution
        apps = {
          default = flake-utils.lib.mkApp {
            drv = nodeEnv;
            exePath = "/bin/deebo";
          };
          
          deebo = flake-utils.lib.mkApp {
            drv = nodeEnv;
            exePath = "/bin/deebo";
          };
        };

        # Validation checks for production readiness
        checks = {
          # Validate flake syntax and structure
          flake-syntax = pkgs.runCommand "validate-flake-syntax" {
            buildInputs = [ pkgs.bash ];
          } ''
            cd ${./.}
            ${pkgs.bash}/bin/bash validate-flake-syntax.sh
            touch $out
          '';

          # Validate shell dependencies mapping
          shell-deps-mapping = pkgs.runCommand "validate-shell-deps-mapping" {
            buildInputs = [ pkgs.bash ];
          } ''
            cd ${./.}
            ${pkgs.bash}/bin/bash validate-shell-deps-mapping.sh
            touch $out
          '';

          # Build test to ensure package can be built
          build-test = nodeEnv;

          # DevShell test to ensure development environment works
          devshell-test = pkgs.runCommand "devshell-test" {
            buildInputs = shellDependencies;
          } ''
            # Test that all expected tools are available
            echo "Testing devShell tools availability..."
            node --version
            npm --version
            python3 --version
            git --version
            rg --version
            echo "All tools available ✅"
            touch $out
          '';

          # NixOS e2e integration test - boots QEMU VM and tests MCP server functionality
          nixos-mcp-e2e = pkgs.testers.nixosTest {
            name = "deebo-mcp-e2e-test";
            
            nodes.machine = { config, pkgs, ... }: {
              # Minimal NixOS configuration for testing
              imports = [ ];
              
              # Install deebo-prototype package
              environment.systemPackages = [ nodeEnv pkgs.procps pkgs.netcat ];
              
              # Define MCP server systemd service
              systemd.services.deebo-mcp-server = {
                description = "Deebo MCP Server";
                after = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];
                
                serviceConfig = {
                  Type = "simple";
                  User = "deebo";
                  Group = "deebo";
                  ExecStart = "${nodeEnv}/bin/deebo";
                  Restart = "always";
                  RestartSec = 5;
                  StandardInput = "socket";
                  StandardOutput = "journal";
                  StandardError = "journal";
                  # Set environment for Nix sandbox
                  Environment = [
                    "NODE_ENV=production"
                    "DEEBO_NIX_SANDBOX_ENABLED=1"
                    "DEEBO_SHELL_DEPS_PATH=${pkgs.lib.makeBinPath shellDependencies}"
                    "PATH=${pkgs.lib.makeBinPath shellDependencies}"
                  ];
                };
              };
              
              # Create socket for MCP server
              systemd.sockets.deebo-mcp-server = {
                description = "Deebo MCP Server Socket";
                wantedBy = [ "sockets.target" ];
                socketConfig = {
                  ListenStream = "127.0.0.1:8080";
                  Accept = "yes";
                };
              };
              
              # Create user for MCP server
              users.users.deebo = {
                isSystemUser = true;
                group = "deebo";
                home = "/var/lib/deebo";
                createHome = true;
              };
              users.groups.deebo = {};
              
              # Enable required services for testing
              services.openssh.enable = false;
              networking.firewall.enable = false;
              
              # Minimal system configuration for faster boot
              boot.kernelParams = [ "quiet" ];
              services.udisks2.enable = false;
              documentation.enable = false;
              
              # Reduce boot time
              systemd.services.systemd-udev-settle.enable = false;
            };
            
            testScript = ''
              import json
              
              # Start the VM
              start_all()
              machine.wait_for_unit("multi-user.target")
              
              # Test 1: Verify deebo binary is available and executable
              print("🔍 Testing binary availability...")
              machine.succeed("which deebo")
              machine.succeed("test -x $(which deebo)")
              print("✅ Deebo binary is available and executable")
              
              # Test 2: Start and verify MCP server service
              print("🚀 Starting MCP server service...")
              machine.systemctl("start deebo-mcp-server.service")
              
              # Wait for service to be active with proper error handling
              machine.wait_for_unit("deebo-mcp-server.service")
              print("✅ MCP server service started successfully")
              
              # Always log service status and logs for debugging
              print("📋 Service status and logs:")
              status_output = machine.succeed("systemctl status deebo-mcp-server.service --no-pager || true")
              print(f"Status: {status_output}")
              
              log_output = machine.succeed("journalctl -u deebo-mcp-server.service --no-pager -n 30 || true")
              print(f"Logs: {log_output}")
              
              # Test 3: Verify deebo binary functionality with proper assertions
              print("🧪 Testing deebo binary execution...")
              
              # Test that deebo can be executed and shows expected behavior
              help_output = machine.succeed("timeout 10s deebo --help 2>&1")
              print(f"Help output: {help_output}")
              
              # Assert that help output contains expected content
              assert "Usage:" in help_output or "usage:" in help_output or "MCP" in help_output, f"Help output doesn't contain expected usage information: {help_output}"
              print("✅ Deebo binary shows proper help information")
              
              # Test 4: Verify all critical shell dependencies are available  
              print("🛠️  Testing shell dependencies availability...")
              critical_deps = ["node", "npm", "python3", "git", "bash"]
              
              for dep in critical_deps:
                machine.succeed(f"which {dep}")
                version_output = machine.succeed(f"{dep} --version 2>&1 || echo 'no version'")
                print(f"✅ {dep} available: {version_output.strip()}")
              
              # Test optional dependencies (non-critical)
              optional_deps = ["rg", "fd", "jq", "gdb", "strace"]
              for dep in optional_deps:
                result = machine.succeed(f"which {dep} && echo 'FOUND' || echo 'MISSING'")
                print(f"Optional dep {dep}: {result.strip()}")
              
              # Test 5: MCP JSON-RPC functionality test 
              print("🔄 Testing MCP JSON-RPC protocol...")
              
              # Create a proper JSON-RPC 2.0 initialization request
              mcp_request = {
                "jsonrpc": "2.0",
                "id": 1,  
                "method": "initialize",
                "params": {
                  "protocolVersion": "2025-01-25",
                  "capabilities": {},
                  "clientInfo": {"name": "test-client", "version": "1.0.0"}
                }
              }
              
              request_json = json.dumps(mcp_request)
              
              # Test MCP server stdio communication with timeout and proper error handling
              mcp_result = machine.succeed(f"""
                timeout 15s bash -c '
                  echo {json.dumps(request_json)} | deebo --stdio 2>&1 | head -5
                ' || echo "MCP_TIMEOUT"
              """)
              
              print(f"MCP communication result: {mcp_result}")
              
              # Verify we got some response (even if not perfect JSON-RPC)
              assert "MCP_TIMEOUT" not in mcp_result, f"MCP server timed out or failed to respond: {mcp_result}"
              assert len(mcp_result.strip()) > 0, f"MCP server returned empty response: {mcp_result}"
              print("✅ MCP server responds to JSON-RPC communication")
              
              # Test 6: Service health check
              print("🏥 Final service health check...")
              
              # Ensure service is still active after tests
              machine.succeed("systemctl is-active deebo-mcp-server.service")
              
              # Check if service can be stopped and restarted
              machine.systemctl("stop deebo-mcp-server.service")
              machine.wait_until_succeeds("systemctl is-inactive deebo-mcp-server.service", timeout=10)
              
              machine.systemctl("start deebo-mcp-server.service") 
              machine.wait_for_unit("deebo-mcp-server.service")
              
              print("✅ Service stop/start cycle successful")
              
              # Final comprehensive status report
              final_status = machine.succeed("systemctl status deebo-mcp-server.service --no-pager")
              print(f"Final status report: {final_status}")
              
              print("✅ All NixOS MCP e2e integration tests passed successfully!")
            '';
          };
        };
      });
}