{
  description = "Nix-native debugging copilot MCP server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Include mcp-servers-nix framework for MCP integration
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, mcp-servers-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Node.js environment for the current MCP server
        nodeEnv = pkgs.buildNpmPackage rec {
          pname = "deebo-prototype";
          version = "1.0.0";
          
          src = ./.;
          
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will need to update this
          
          buildPhase = ''
            npm run build
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib/deebo-prototype
            cp -r build/* $out/lib/deebo-prototype/
            cp -r node_modules $out/lib/deebo-prototype/
            cp package.json $out/lib/deebo-prototype/
            
            # Create wrapper script
            cat > $out/bin/deebo << EOF
            #!${pkgs.bash}/bin/bash
            exec ${pkgs.nodejs}/bin/node $out/lib/deebo-prototype/index.js "\$@"
            EOF
            chmod +x $out/bin/deebo
          '';
        };

        # Nix-native sandbox execution utilities
        nixSandboxUtils = pkgs.writeText "nix-sandbox-utils.nix" ''
          { pkgs ? import <nixpkgs> {} }:

          rec {
            # Execute code in Nix sandbox with limited filesystem access
            sandboxExec = { name, code, language ? "bash", allowedPaths ? [] }: pkgs.runCommand name {
              buildInputs = with pkgs; [
                bash
                coreutils
                findutils
                gnugrep
                gnused
              ] ++ (if language == "python" then [ python3 ]
                   else if language == "nodejs" then [ nodejs ]
                   else if language == "typescript" then [ nodejs typescript ]
                   else []);
              
              # Restrict network access and filesystem access
              __noChroot = false;
              allowSubstitutes = false;
            } ''
              # Create isolated environment
              mkdir -p $out/logs $out/results
              
              # Execute code in restricted environment
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
              '' else ''
                echo "Unsupported language: ${language}" > $out/logs/error.log
                exit 1
              ''}
              
              # Capture exit code
              echo $? > $out/results/exit_code
            '';

            # Git operations in sandbox
            gitSandboxExec = { repoPath, commands }: pkgs.runCommand "git-sandbox" {
              buildInputs = with pkgs; [ git ];
              __noChroot = false;
            } ''
              mkdir -p $out/logs
              cd ${repoPath}
              
              ${builtins.concatStringsSep "\n" (map (cmd: ''
                echo "Executing: ${cmd}" | tee -a $out/logs/git.log
                ${cmd} 2>&1 | tee -a $out/logs/git.log
              '') commands)}
            '';

            # Tool execution with path isolation
            toolExec = { tool, args ? [], env ? {} }: pkgs.runCommand "tool-exec" {
              buildInputs = with pkgs; [ ${tool} ];
              __noChroot = false;
            } (let
              envVars = builtins.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: "export ${k}='${v}'") env);
            in ''
              mkdir -p $out/logs $out/results
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
        };

        # Development shell with all necessary tools
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            npm
            typescript
            git
            uv  # uvx replacement
            ripgrep
            # Nix-specific tools
            nix-tree
            nix-output-monitor
            nixpkgs-fmt
          ];

          shellHook = ''
            echo "Deebo-Prototype Nix Development Environment"
            echo "Available commands:"
            echo "  npm run build  - Build TypeScript"
            echo "  npm run dev    - Development mode"
            echo "  nix build      - Build Nix package"
            echo "  nix develop    - Enter development shell"
            
            # Set up environment for Nix sandbox features
            export DEEBO_NIX_SANDBOX_ENABLED=1
            export DEEBO_NIX_UTILS_PATH=${nixSandboxUtils}
          '';
        };

        # MCP server configuration for Nix integration
        mcpServers = {
          deebo-nix = {
            command = "${nodeEnv}/bin/deebo";
            args = [ "--nix-native" ];
            env = {
              NODE_ENV = "production";
              DEEBO_NIX_SANDBOX_ENABLED = "1";
            };
            transportType = "stdio";
          };
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
        };
      });
}