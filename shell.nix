{
  inputs,
  ...
}:
{
  imports = [
    inputs.treefmt-nix.flakeModule
    inputs.git-hooks.flakeModule
  ];

  perSystem =
    { config, pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          # Nix
          nixfmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;

          # HTML, CSS, JS, MD, YAML, TOML
          prettier.enable = true;
          yamlfmt.enable = true;
          taplo.enable = true;
        };
      };

      pre-commit = {
        check.enable = true;
        settings.hooks = {
          treefmt.enable = true;

          end-of-file-fixer.enable = true;
          trim-trailing-whitespace.enable = true;
          check-added-large-files.enable = true;
        };
      };

      devShells.default = pkgs.mkShell {
        shellHook = config.pre-commit.installationScript;

        nativeBuildInputs = with pkgs; [
          config.treefmt.build.wrapper
          nixd
        ];

        NIX_CONFIG = "extra-experimental-features = nix-command flakes pipe-operators";
      };
    };
}
