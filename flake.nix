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
    # mcp-utensils for NixOS-based MCP server management
    mcp-utensils = {
      url = "github:utensils/mcp-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Regression testing framework
    flake-regressions = {
      url = "github:NixOS/flake-regressions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-fast-build for performance optimization
    nix-fast-build = {
      url = "github:Mic92/nix-fast-build";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, mcp-servers-nix, mcp-utensils, flake-regressions, nix-fast-build }:
    flake-utils.lib.eachDefaultSystem (system:
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
          nodejs
          npm
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
          nix-fast-build.packages.${system}.default  # nix-fast-build for performance
          
          # Additional utilities used by sandbox
          procps  # for process management
          util-linux  # for namespace utilities
          shadow  # for user management in sandbox
        ];
        
        # Node.js environment with all dependencies properly mapped
        nodeEnv = pkgs.buildNpmPackage rec {
          pname = "deebo-prototype";
          version = "1.0.0";
          
          src = ./.;
          
          # Provide all shell dependencies to build process
          nativeBuildInputs = shellDependencies;
          
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will need to update this
          
          buildPhase = ''
            # Ensure all shell dependencies are available during build
            export PATH="${pkgs.lib.makeBinPath shellDependencies}:$PATH"
            npm run build
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib/deebo-prototype
            cp -r build/* $out/lib/deebo-prototype/
            cp -r node_modules $out/lib/deebo-prototype/
            cp package.json $out/lib/deebo-prototype/
            
            # Create wrapper script with all shell dependencies available
            cat > $out/bin/deebo << EOF
            #!${pkgs.bash}/bin/bash
            export PATH="${pkgs.lib.makeBinPath shellDependencies}:\$PATH"
            export DEEBO_NIX_SHELL_DEPS="${pkgs.lib.makeBinPath shellDependencies}"
            exec ${pkgs.nodejs}/bin/node $out/lib/deebo-prototype/index.js "\$@"
            EOF
            chmod +x $out/bin/deebo
          '';
        };

        # Nix-native sandbox execution utilities with all dependencies mapped
        nixSandboxUtils = pkgs.writeText "nix-sandbox-utils.nix" ''
          { pkgs ? import <nixpkgs> {} }:

          let
            # Ensure all shell dependencies are available in sandbox environments
            sandboxDeps = with pkgs; [
              bash coreutils findutils gnugrep gnused git
              nodejs npm python3 typescript rustc cargo go
              gdb strace ltrace valgrind ripgrep fd jq curl wget
              gnumake cmake pkg-config procps util-linux shadow
            ];
          in

          rec {
            # Execute code in Nix sandbox with complete dependency mapping
            sandboxExec = { name, code, language ? "bash", allowedPaths ? [] }: pkgs.runCommand name {
              buildInputs = sandboxDeps ++ (
                if language == "python" then [ pkgs.python3Packages.pip pkgs.python3Packages.debugpy ]
                else if language == "nodejs" then [ pkgs.nodePackages.npm ]
                else if language == "typescript" then [ pkgs.nodePackages.typescript ]
                else []
              );
              
              # Restrict network access and filesystem access
              __noChroot = false;
              allowSubstitutes = false;
              
              # Ensure all shell dependencies are in PATH
              PATH = "${pkgs.lib.makeBinPath sandboxDeps}";
            } ''
              # Create isolated environment
              mkdir -p $out/logs $out/results
              
              # Ensure PATH includes all mapped dependencies
              export PATH="${pkgs.lib.makeBinPath sandboxDeps}:$PATH"
              
              # Execute code in restricted environment with all tools available
              ${if language == "bash" then ''
                echo '${code}' > script.sh
                chmod +x script.sh
                ./script.sh 2>&1 | tee $out/logs/execution.log
              '' else if language == "python" then ''
                echo '${code}' > script.py
                python3 script.py 2>&1 | tee $out/logs/execution.log
              '' else if language == "nodejs" then ''
                echo '${code}' > script.js
                node script.js 2>&1 | tee $out/logs/execution.log
              '' else if language == "typescript" then ''
                echo '${code}' > script.ts
                tsc script.ts && node script.js 2>&1 | tee $out/logs/execution.log
              '' else ''
                echo "Unsupported language: ${language}" > $out/logs/error.log
                exit 1
              ''}
              
              # Capture exit code
              echo $? > $out/results/exit_code
            '';

            # Git operations in sandbox with all dependencies mapped
            gitSandboxExec = { repoPath, commands }: pkgs.runCommand "git-sandbox" {
              buildInputs = sandboxDeps;
              __noChroot = false;
              PATH = "${pkgs.lib.makeBinPath sandboxDeps}";
            } ''
              mkdir -p $out/logs
              export PATH="${pkgs.lib.makeBinPath sandboxDeps}:$PATH"
              cd ${repoPath}
              
              ${builtins.concatStringsSep "\n" (map (cmd: ''
                echo "Executing: ${cmd}" | tee -a $out/logs/git.log
                ${cmd} 2>&1 | tee -a $out/logs/git.log
              '') commands)}
            '';

            # Tool execution with complete dependency mapping
            toolExec = { tool, args ? [], env ? {} }: pkgs.runCommand "tool-exec" {
              buildInputs = sandboxDeps;
              __noChroot = false;
              PATH = "${pkgs.lib.makeBinPath sandboxDeps}";
            } (let
              envVars = builtins.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: "export ${k}='${v}'") env);
            in ''
              mkdir -p $out/logs $out/results
              export PATH="${pkgs.lib.makeBinPath sandboxDeps}:$PATH"
              ${envVars}
              
              ${tool} ${builtins.concatStringsSep " " args} 2>&1 | tee $out/logs/execution.log
              echo $? > $out/results/exit_code
            '');
          }
        '';

      in {
        packages = {
          default = nodeEnv;
          deebo-prototype = nodeEnv;
          nix-sandbox-utils = pkgs.writeTextFile {
            name = "nix-sandbox-utils";
            text = builtins.readFile nixSandboxUtils;
          };
          # Regression testing package
          regressionTests = regressionTests;
          # Self-referential tests
          selfRefTests = selfRefTests;
          # Fast build utilities
          fastBuild = fastBuildConfig.builders;
          fastTest = fastBuildConfig.fastTest;
          gitopsWorkflow = fastBuildConfig.gitopsWorkflow;
        };

        # Comprehensive flake checks for GitOps validation
        checks = {
          # Basic package builds
          deebo-build = nodeEnv;
          
          # Regression tests
          regression-tests = regressionTests;
          
          # Self-referential tests
          self-ref-tests = selfRefTests;
          
          # Flake validation
          flake-validation = pkgs.runCommand "flake-validation" { 
            buildInputs = [ pkgs.nix ]; 
          } ''
            cd ${./.}
            nix flake check --no-build
            echo "success" > $out
          '';
          
          # Template validation
          template-validation = pkgs.runCommand "template-validation" {
            buildInputs = [ pkgs.nix ];
          } ''
            mkdir -p $out/results
            cd $(mktemp -d)
            
            # Test each template
            for template in debug-session scenario-agent; do
              echo "Testing template: $template"
              mkdir test-$template
              cd test-$template
              nix flake init -t ${./.}#$template
              nix flake check --no-build
              cd ..
              echo "$template: OK" >> $out/results/templates.log
            done
            
            echo "success" > $out/results/status
          '';
          
          # MCP server configuration validation
          mcp-config-validation = pkgs.runCommand "mcp-config-validation" {
            buildInputs = [ pkgs.jq ];
          } ''
            # Validate MCP server configuration
            echo '${builtins.toJSON mcpServers}' | jq '.' > $out
          '';
          
          # Shell dependencies validation
          shell-deps-validation = pkgs.runCommand "shell-deps-validation" {
            buildInputs = shellDependencies;
          } ''
            mkdir -p $out/results
            
            # Test that all shell dependencies are available
            for tool in git node npm python3 rustc go gdb strace ripgrep jq nix; do
              if command -v $tool >/dev/null 2>&1; then
                echo "$tool: OK" >> $out/results/tools.log
              else
                echo "$tool: MISSING" >> $out/results/tools.log
                exit 1
              fi
            done
            
            echo "All shell dependencies validated" > $out/results/status
          '';
        };

        # Development shell with all shell dependencies properly mapped
        devShells.default = pkgs.mkShell {
          buildInputs = shellDependencies;

          shellHook = ''
            echo "Deebo-Prototype Nix Development Environment"
            echo "All shell dependencies mapped via nix-shell:"
            echo "  Core: bash, coreutils, git, findutils, gnugrep, gnused"
            echo "  Languages: nodejs, npm, python3, typescript, rust, go"  
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
            export DEEBO_NIX_UTILS_PATH=${nixSandboxUtils}
            export DEEBO_SHELL_DEPS_PATH="${pkgs.lib.makeBinPath shellDependencies}"
            
            # Ensure all dependencies are in PATH
            export PATH="${pkgs.lib.makeBinPath shellDependencies}:$PATH"
          '';
        };

        # MCP server configuration using mcp-servers-nix framework
        mcpServers = mcp-servers-nix.lib.mkMcpServers {
          inherit pkgs;
          servers = {
            deebo-nix = {
              package = nodeEnv;
              command = "${nodeEnv}/bin/deebo";
              args = [ "--nix-native" ];
              env = {
                NODE_ENV = "production";
                DEEBO_NIX_SANDBOX_ENABLED = "1";
                DEEBO_SHELL_DEPS_PATH = "${pkgs.lib.makeBinPath shellDependencies}";
                PATH = "${pkgs.lib.makeBinPath shellDependencies}";
              };
              transportType = "stdio";
              description = "Nix-native debugging copilot with mapped shell dependencies";
            };
          };
        };

        # mcp-utensils integration for NixOS-based MCP server management
        mcpUtensils = mcp-utensils.lib.mkMcpConfig {
          inherit pkgs;
          servers = {
            deebo-prototype = {
              package = nodeEnv;
              description = "Deebo prototype MCP server with Nix integration";
              nixosModule = {
                services.mcp-servers.deebo-prototype = {
                  enable = true;
                  package = nodeEnv;
                  args = [ "--nix-native" ];
                  environment = {
                    DEEBO_NIX_SANDBOX_ENABLED = "1";
                    DEEBO_SHELL_DEPS_PATH = "${pkgs.lib.makeBinPath shellDependencies}";
                  };
                };
              };
            };
          };
        };

        # Regression testing framework using flake-regressions
        regressionTests = flake-regressions.lib.mkRegressionTests {
          inherit pkgs;
          name = "deebo-prototype-regressions";
          tests = {
            # Test MCP server functionality
            mcp-server-basic = {
              description = "Basic MCP server functionality";
              command = "${nodeEnv}/bin/deebo --test-mode";
              expectedExitCode = 0;
              timeout = 30;
            };
            
            # Test Nix sandbox execution
            nix-sandbox-basic = {
              description = "Basic Nix sandbox execution";
              command = pkgs.writeShellScript "test-nix-sandbox" ''
                export DEEBO_NIX_SANDBOX_ENABLED=1
                echo "print('Hello from Nix sandbox')" | ${nodeEnv}/bin/deebo --nix-sandbox-exec python
              '';
              expectedExitCode = 0;
              timeout = 60;
            };
            
            # Test shell dependency mapping
            shell-deps-mapping = {
              description = "Shell dependencies are properly mapped";
              command = pkgs.writeShellScript "test-shell-deps" ''
                export PATH="${pkgs.lib.makeBinPath shellDependencies}:$PATH"
                for tool in git node npm python3 rustc go gdb strace ripgrep jq; do
                  if ! command -v $tool >/dev/null 2>&1; then
                    echo "Missing tool: $tool"
                    exit 1
                  fi
                done
                echo "All shell dependencies available"
              '';
              expectedExitCode = 0;
              timeout = 30;
            };

            # Test flake template generation
            flake-template-generation = {
              description = "Flake templates can be generated";
              command = pkgs.writeShellScript "test-flake-templates" ''
                cd $(mktemp -d)
                ${nodeEnv}/bin/deebo --generate-flake python
                if [ -f flake.nix ]; then
                  echo "Flake template generated successfully"
                  nix flake check --no-build
                else
                  echo "Flake template generation failed"
                  exit 1
                fi
              '';
              expectedExitCode = 0;
              timeout = 120;
            };
          };
        };

        # Self-referential flake tests for GitOps validation
        selfRefTests = pkgs.stdenv.mkDerivation {
          name = "deebo-self-ref-tests";
          src = ./.;
          
          buildInputs = shellDependencies ++ [ nix-fast-build.packages.${system}.default ];
          
          buildPhase = ''
            # Test that this flake can build itself
            echo "Testing self-referential flake build..."
            nix build .#deebo-prototype --no-link --print-build-logs
            
            # Test that all outputs are buildable
            echo "Testing all flake outputs..."
            nix flake show --json > outputs.json
            
            # Test template instantiation
            echo "Testing template instantiation..."
            for template in debug-session scenario-agent; do
              mkdir -p test-$template
              cd test-$template
              nix flake init -t ..#$template
              nix flake check --no-build
              cd ..
            done
            
            # Test MCP server configuration
            echo "Testing MCP server configuration..."
            nix eval .#mcpServers --json > mcp-config.json
            
            # Test regression tests
            echo "Running regression tests..."
            nix build .#regressionTests --no-link
            
            echo "All self-referential tests passed"
          '';
          
          installPhase = ''
            mkdir -p $out/results
            cp outputs.json $out/results/
            cp mcp-config.json $out/results/
            echo "success" > $out/results/status
          '';
        };

        # nix-fast-build integration for performance optimization
        fastBuildConfig = {
          # Use nix-fast-build for parallel builds
          builders = pkgs.writeShellScript "fast-build-deebo" ''
            ${nix-fast-build.packages.${system}.default}/bin/nix-fast-build \
              --no-nom \
              --skip-cached \
              --flake .#deebo-prototype
          '';
          
          # Fast testing with nix-fast-build
          fastTest = pkgs.writeShellScript "fast-test-deebo" ''
            ${nix-fast-build.packages.${system}.default}/bin/nix-fast-build \
              --no-nom \
              --skip-cached \
              --flake .#regressionTests \
              --flake .#selfRefTests
          '';
          
          # GitOps workflow integration
          gitopsWorkflow = pkgs.writeShellScript "gitops-workflow" ''
            set -e
            echo "🚀 Running GitOps workflow with nix-fast-build..."
            
            # Fast build all packages
            echo "📦 Building packages..."
            ${nix-fast-build.packages.${system}.default}/bin/nix-fast-build \
              --no-nom \
              --skip-cached \
              --flake .#deebo-prototype
              
            # Run regression tests
            echo "🧪 Running regression tests..."
            ${nix-fast-build.packages.${system}.default}/bin/nix-fast-build \
              --no-nom \
              --skip-cached \
              --flake .#regressionTests
              
            # Run self-referential tests
            echo "🔄 Running self-referential tests..."
            ${nix-fast-build.packages.${system}.default}/bin/nix-fast-build \
              --no-nom \
              --skip-cached \
              --flake .#selfRefTests
              
            # Validate MCP server configuration
            echo "⚙️  Validating MCP server configuration..."
            nix eval .#mcpServers --json | jq '.'
            
            echo "✅ GitOps workflow completed successfully!"
          '';
        };

        # Nix flake templates for debugging workflows
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
          
          # GitOps workflow runner
          gitops = flake-utils.lib.mkApp {
            drv = fastBuildConfig.gitopsWorkflow;
          };
          
          # Fast build runner
          fast-build = flake-utils.lib.mkApp {
            drv = fastBuildConfig.builders;
          };
          
          # Fast test runner
          fast-test = flake-utils.lib.mkApp {
            drv = fastBuildConfig.fastTest;
          };
        };

        # Additional outputs for mcp-utensils integration
        inherit mcpServers mcpUtensils regressionTests;
      });
}