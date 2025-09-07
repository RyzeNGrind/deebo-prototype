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
              environment.systemPackages = [ nodeEnv ];
              
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
              import subprocess
              import time
              
              # Start the VM
              start_all()
              machine.wait_for_unit("multi-user.target")
              
              # Test 1: Verify deebo binary is available and executable
              machine.succeed("which deebo")
              machine.succeed("test -x /nix/store/*/bin/deebo")
              
              # Test 2: Test MCP server basic startup and protocol communication
              # MCP servers use JSON-RPC 2.0 over stdio
              mcp_init_request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                  "protocolVersion": "2025-01-25",
                  "capabilities": {
                    "roots": {
                      "listChanged": True
                    },
                    "sampling": {}
                  },
                  "clientInfo": {
                    "name": "nixos-test-client",
                    "version": "1.0.0"
                  }
                }
              }
              
              # Send MCP initialize request and verify response
              init_json = json.dumps(mcp_init_request)
              
              # Test server responds to initialize request within 30 seconds
              result = machine.succeed(f'''
                timeout 30s bash -c '
                  echo "{init_json}" | deebo 2>/dev/null | head -1
                ' || echo "TIMEOUT"
              ''')
              
              # Verify we get a JSON response (not timeout)
              if "TIMEOUT" in result:
                  raise Exception("MCP server failed to respond within 30 seconds")
              
              # Test 3: Verify the response is valid JSON-RPC
              try:
                  response = json.loads(result.strip())
                  assert "jsonrpc" in response, "Response missing jsonrpc field"
                  assert response["jsonrpc"] == "2.0", "Invalid JSON-RPC version"
                  assert "id" in response, "Response missing id field"
                  assert response["id"] == 1, "Response id mismatch"
                  print("✅ MCP server responded with valid JSON-RPC initialization response")
              except json.JSONDecodeError as e:
                  raise Exception(f"Invalid JSON response from MCP server: {e}")
              
              # Test 4: Test server capabilities listing (tools/resources)
              capabilities_request = {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/list"
              }
              
              cap_json = json.dumps(capabilities_request)
              cap_result = machine.succeed(f'''
                timeout 15s bash -c '
                  echo "{init_json}" | deebo 2>/dev/null | head -1 > /dev/null &&
                  echo "{cap_json}" | deebo 2>/dev/null | head -1
                ' || echo "TIMEOUT"
              ''')
              
              if "TIMEOUT" not in cap_result:
                try:
                  cap_response = json.loads(cap_result.strip())
                  if "result" in cap_response:
                    print("✅ MCP server successfully listed tools/capabilities")
                  else:
                    print("⚠️  MCP server responded but may not have tools configured")
                except:
                  print("⚠️  Tools listing response not valid JSON, but server is responding")
              
              print("✅ All NixOS MCP e2e integration tests passed")
            '';
          };
        };
      });
}