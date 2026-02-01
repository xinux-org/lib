{
  core-inputs,
  user-inputs,
  xinux-lib,
  xinux-config,
}:
let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib)
    foldl
    mapAttrs
    callPackageWith
    ;

  user-packages-root = xinux-lib.fs.get-xinux-file "packages";
in
{
  package = rec {
    ## Create flake output packages.
    ## Example Usage:
    ## ```nix
    ## create-packages { inherit channels; src = ./my-packages; overrides = { inherit another-package; }; alias.default = "another-package"; }
    ## ```
    ## Result:
    ## ```nix
    ## { another-package = ...; my-package = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-packages =
      {
        channels,
        src ? user-packages-root,
        pkgs ? channels.nixpkgs,
        overrides ? { },
        alias ? { },
        namespace ? xinux-config.namespace,
      }:
      let
        user-packages = xinux-lib.fs.get-default-nix-files-recursive src;
        create-package-metadata =
          package:
          let
            namespaced-packages = {
              ${namespace} = packages-without-aliases;
            };
            extra-inputs =
              pkgs
              // namespaced-packages
              // {
                inherit channels namespace;
                lib = xinux-lib.internal.system-lib;
                pkgs = pkgs // namespaced-packages;
                inputs = user-inputs;
              };
          in
          {
            name = builtins.unsafeDiscardStringContext (xinux-lib.path.get-parent-directory package);
            drv =
              let
                pkg = callPackageWith extra-inputs package { };
              in
              pkg
              // {
                meta = (pkg.meta or { }) // {
                  xinux = {
                    path = package;
                  };
                };
              };
          };
        packages-metadata = builtins.map create-package-metadata user-packages;
        merge-packages =
          packages: metadata:
          packages
          // {
            ${metadata.name} = metadata.drv;
          };
        packages-without-aliases = foldl merge-packages { } packages-metadata;
        aliased-packages = mapAttrs (_name: value: packages-without-aliases.${value}) alias;
        packages = packages-without-aliases // aliased-packages // overrides;
      in
      filterPackages pkgs.stdenv.hostPlatform.system packages;
  };
}
