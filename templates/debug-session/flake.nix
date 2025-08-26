{
  description = "Deebo debugging session environment with comprehensive shell dependency mapping";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # All debugging dependencies mapped via nix-shell as requested
        debugDependencies = with pkgs; [
          # Core development tools
          git
          bash
          coreutils
          findutils
          gnugrep
          gnused
          
          # Language runtimes
          nodejs
          npm
          python3
          python3Packages.pip
          python3Packages.debugpy
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
          
          # Process and system utilities
          procps
          util-linux
          shadow
        ];
        
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = debugDependencies;

          shellHook = ''
            echo "Deebo Debugging Session Environment"
            echo "Session ID: $(date +%s)"
            echo "All debugging tools mapped via nix-shell:"
            echo "  Languages: git, node, python3, rust, go"
            echo "  Debug tools: gdb, strace, ltrace, valgrind"
            echo "  Utils: rg, fd, jq, curl, wget"
            echo "  Build: make, cmake, pkg-config"
            
            # Set up isolation environment with all dependencies available
            export DEEBO_SESSION_ID="session-$(date +%s)"
            export DEEBO_SANDBOX_MODE="nix"
            export PATH="${pkgs.lib.makeBinPath debugDependencies}:$PATH"
            
            # Create isolated workspace
            mkdir -p .deebo-workspace/{logs,results,scratch}
            cd .deebo-workspace
            
            echo "Workspace ready at: $(pwd)"
            echo "All shell dependencies available via: $PATH"
          '';
        };

        # Sandbox execution environments with all dependencies mapped
        packages = {
          # Python debugging environment with full dependency mapping
          python-debug = pkgs.runCommand "python-debug-env" {
            buildInputs = debugDependencies ++ (with pkgs; [ python3Packages.virtualenv ]);
            PATH = "${pkgs.lib.makeBinPath debugDependencies}";
          } ''
            mkdir -p $out/bin
            cat > $out/bin/python-debug << EOF
            #!/bin/bash
            export PATH="${pkgs.lib.makeBinPath debugDependencies}:\$PATH"
            python3 -m debugpy --listen 5678 --wait-for-client "\$@"
            EOF
            chmod +x $out/bin/python-debug
          '';

          # Node.js debugging environment with all tools available
          node-debug = pkgs.runCommand "node-debug-env" {
            buildInputs = debugDependencies;
            PATH = "${pkgs.lib.makeBinPath debugDependencies}";
          } ''
            mkdir -p $out/bin
            cat > $out/bin/node-debug << EOF
            #!/bin/bash
            export PATH="${pkgs.lib.makeBinPath debugDependencies}:\$PATH"
            node --inspect-brk=0.0.0.0:9229 "\$@"
            EOF
            chmod +x $out/bin/node-debug
          '';

          # Rust debugging environment with complete toolchain
          rust-debug = pkgs.runCommand "rust-debug-env" {
            buildInputs = debugDependencies ++ (with pkgs; [ lldb ]);
            PATH = "${pkgs.lib.makeBinPath debugDependencies}";
          } ''
            mkdir -p $out/bin
            cat > $out/bin/rust-debug << EOF
            #!/bin/bash
            export PATH="${pkgs.lib.makeBinPath debugDependencies}:\$PATH"
            RUSTFLAGS="-g" cargo build
            gdb ./target/debug/\$(basename \$(pwd))
            EOF
            chmod +x $out/bin/rust-debug
          '';
          
          # Complete shell environment package
          shell-env = pkgs.runCommand "deebo-debug-shell" {
            buildInputs = debugDependencies;
          } ''
            mkdir -p $out/bin
            cat > $out/bin/deebo-debug-shell << EOF
            #!/bin/bash
            export PATH="${pkgs.lib.makeBinPath debugDependencies}:\$PATH"
            echo "Deebo Debug Shell - All dependencies available"
            echo "PATH: \$PATH"
            \$SHELL
            EOF
            chmod +x $out/bin/deebo-debug-shell
          '';
        };
      });
}