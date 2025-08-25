{
  description = "Deebo debugging session environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core development tools
            git
            nodejs
            python3
            rustc
            cargo
            go
            
            # Debugging utilities
            gdb
            strace
            ltrace
            valgrind
            
            # Text processing
            ripgrep
            fd
            jq
            
            # Network tools
            curl
            wget
            
            # Build tools
            gnumake
            cmake
            pkg-config
          ];

          shellHook = ''
            echo "Deebo Debugging Session Environment"
            echo "Session ID: $(date +%s)"
            echo "Available tools: git, node, python3, rust, go, gdb, strace, rg, fd"
            
            # Set up isolation environment
            export DEEBO_SESSION_ID="session-$(date +%s)"
            export DEEBO_SANDBOX_MODE="nix"
            
            # Create isolated workspace
            mkdir -p .deebo-workspace/{logs,results,scratch}
            cd .deebo-workspace
            
            echo "Workspace ready at: $(pwd)"
          '';
        };

        # Sandbox execution environments
        packages = {
          # Python debugging environment
          python-debug = pkgs.runCommand "python-debug-env" {
            buildInputs = with pkgs; [ python3 python3Packages.pip python3Packages.debugpy ];
          } ''
            mkdir -p $out/bin
            cat > $out/bin/python-debug << EOF
            #!/bin/bash
            python3 -m debugpy --listen 5678 --wait-for-client "\$@"
            EOF
            chmod +x $out/bin/python-debug
          '';

          # Node.js debugging environment  
          node-debug = pkgs.runCommand "node-debug-env" {
            buildInputs = with pkgs; [ nodejs ];
          } ''
            mkdir -p $out/bin
            cat > $out/bin/node-debug << EOF
            #!/bin/bash
            node --inspect-brk=0.0.0.0:9229 "\$@"
            EOF
            chmod +x $out/bin/node-debug
          '';

          # Rust debugging environment
          rust-debug = pkgs.runCommand "rust-debug-env" {
            buildInputs = with pkgs; [ rustc cargo gdb ];
          } ''
            mkdir -p $out/bin
            cat > $out/bin/rust-debug << EOF
            #!/bin/bash
            RUSTFLAGS="-g" cargo build
            gdb ./target/debug/\$(basename \$(pwd))
            EOF
            chmod +x $out/bin/rust-debug
          '';
        };
      });
}