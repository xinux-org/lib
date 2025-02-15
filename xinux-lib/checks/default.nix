{
  core-inputs,
  user-inputs,
  xinux-lib,
  xinux-config,
}: let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl mapAttrs callPackageWith;

  user-checks-root = xinux-lib.fs.get-xinux-file "checks";
in {
  check = {
    ## Create flake output packages.
    ## Example Usage:
    ## ```nix
    ## create-checks { inherit channels; src = ./my-checks; overrides = { inherit another-check; }; alias = { default = "another-check"; }; }
    ## ```
    ## Result:
    ## ```nix
    ## { another-check = ...; my-check = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-checks = {
      channels,
      src ? user-checks-root,
      pkgs ? channels.nixpkgs,
      overrides ? {},
      alias ? {},
    }: let
      user-checks = xinux-lib.fs.get-default-nix-files-recursive src;
      create-check-metadata = check: let
        extra-inputs =
          pkgs
          // {
            inherit channels;
            lib = xinux-lib.internal.system-lib;
            inputs = xinux-lib.flake.without-src user-inputs;
            namespace = xinux-config.namespace;
          };
      in {
        name = builtins.unsafeDiscardStringContext (xinux-lib.path.get-parent-directory check);
        drv = callPackageWith extra-inputs check {};
      };
      checks-metadata = builtins.map create-check-metadata user-checks;
      merge-checks = checks: metadata:
        checks
        // {
          ${metadata.name} = metadata.drv;
        };
      checks-without-aliases = foldl merge-checks {} checks-metadata;
      aliased-checks = mapAttrs (name: value: checks-without-aliases.${value}) alias;
      checks = checks-without-aliases // aliased-checks // overrides;
    in
      filterPackages pkgs.stdenv.hostPlatform.system checks;
  };
}
