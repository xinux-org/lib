{
  description = "Xinux Library";

  inputs = {
    nixpkgs.url = "github:xinux-org/nixpkgs/nixos-unstable";

    # NOTE: `nix flake lock --update-input flake-utils-plus` is currently NOT
    # giving us the appropriate revision. We need a fix from a recent PR in
    # FUP, so this revision is being hard coded here for now.
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus?rev=3542fe9126dc492e53ddd252bb0260fe035f2c0f";

    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      core-inputs = inputs // {
        src = ./.;
      };

      # Create the library, extending the nixpkgs library and merging
      # libraries from other inputs to make them available like
      # `lib.flake-utils-plus.mkApp`.
      # Usage: mkLib { inherit inputs; src = ./.; }
      #   result: lib
      mkLib = import ./xinux-lib core-inputs;

      # A convenience wrapper to create the library and then call `lib.mkFlake`.
      # Usage: mkFlake { inherit inputs; src = ./.; ... }
      #   result: <flake-outputs>
      mkFlake =
        flake-and-lib-options@{
          inputs,
          src,
          xinux ? { },
          ...
        }:
        let
          lib = mkLib {
            inherit inputs src xinux;
          };
          flake-options = removeAttrs flake-and-lib-options [
            "inputs"
            "src"
          ];
        in
        lib.mkFlake flake-options;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [
          ./shell.nix
        ];
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-linux"
          "aarch64-darwin"
        ];
        flake = {
          # Put your original flake attributes here.
          inherit mkLib mkFlake;

          # flakeModules.developmentShell = ./shell.nix;
          flakeModules.developmentShell = import ./shell.nix { inherit inputs; };

          nixosModules = {
            user = ./modules/nixos/user/default.nix;
          };

          darwinModules = {
            user = ./modules/darwin/user/default.nix;
          };

          homeModules = {
            user = ./modules/home/user/default.nix;
          };

          xinux = rec {
            raw-config = config;

            config = {
              root = ./.;
              src = ./.;
              namespace = "xinux";
              lib-dir = "xinux-lib";

              meta = {
                name = "xinux-lib";
                title = "Xinux Library";
              };
            };

            internal-lib =
              let
                lib = mkLib {
                  src = ./.;

                  inputs = inputs // {
                    self = { };
                  };
                };
              in
              removeAttrs lib.xinux [ "internal" ];
          };
        };
      }
    );
}
