{
  core-inputs,
  user-inputs,
  xinux-lib,
  xinux-config,
}:
let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib)
    assertMsg
    foldl
    mapAttrs
    callPackageWith
    ;

  user-shells-root = xinux-lib.fs.get-xinux-file "shells";
in
{
  shell = {
    ## Create flake output packages.
    ## Example Usage:
    ## ```nix
    ## create-shells { inherit channels; src = ./my-shells; overrides = { inherit another-shell; }; alias = { default = "another-shell"; }; }
    ## ```
    ## Result:
    ## ```nix
    ## { another-shell = ...; my-shell = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-shells =
      {
        channels,
        src ? user-shells-root,
        pkgs ? channels.nixpkgs,
        overrides ? { },
        alias ? { },
      }:
      let
        user-shells = xinux-lib.fs.get-default-nix-files-recursive src;
        create-shell-metadata =
          shell:
          let
            extra-inputs = pkgs // {
              inherit channels;
              lib = xinux-lib.internal.system-lib;
              inputs = xinux-lib.flake.without-src user-inputs;
              namespace = xinux-config.namespace;
            };
          in
          {
            name = builtins.unsafeDiscardStringContext (xinux-lib.path.get-parent-directory shell);
            drv = callPackageWith extra-inputs shell { };
          };
        shells-metadata = builtins.map create-shell-metadata user-shells;
        merge-shells =
          shells: metadata:
          shells
          // {
            ${metadata.name} = metadata.drv;
          };
        shells-without-aliases = foldl merge-shells { } shells-metadata;
        aliased-shells = mapAttrs (name: value: shells-without-aliases.${value}) alias;
        shells = shells-without-aliases // aliased-shells // overrides;
      in
      filterPackages pkgs.stdenv.hostPlatform.system shells;
  };
}
