{
  core-inputs,
  user-inputs,
  xinux-lib,
  xinux-config,
}:
let
  inherit (core-inputs.nixpkgs.lib)
    fix
    filterAttrs
    callPackageWith
    isFunction
    ;

  core-inputs-libs = xinux-lib.flake.get-libs (xinux-lib.flake.without-self core-inputs);
  user-inputs-libs = xinux-lib.flake.get-libs (xinux-lib.flake.without-self user-inputs);

  xinux-top-level-lib = filterAttrs (name: value: !builtins.isAttrs value) xinux-lib;

  base-lib = xinux-lib.attrs.merge-shallow [
    core-inputs.nixpkgs.lib
    core-inputs-libs
    user-inputs-libs
    xinux-top-level-lib
    { xinux = xinux-lib; }
  ];

  user-lib-root = xinux-lib.fs.get-xinux-file "lib";
  user-lib-modules = xinux-lib.fs.get-default-nix-files-recursive user-lib-root;

  user-lib = fix (
    user-lib:
    let
      attrs = {
        inputs = xinux-lib.flake.without-xinux-inputs user-inputs;
        xinux-inputs = core-inputs;
        namespace = xinux-config.namespace;
        lib = xinux-lib.attrs.merge-shallow [
          base-lib
          { "${xinux-config.namespace}" = user-lib; }
        ];
      };
      libs = builtins.map (
        path:
        let
          imported-module = import path;
        in
        if isFunction imported-module then
          callPackageWith attrs path { }
        # the only difference is that there is no `override` and `overrideDerivation` on returned value
        else
          imported-module
      ) user-lib-modules;
    in
    xinux-lib.attrs.merge-deep libs
  );

  system-lib = xinux-lib.attrs.merge-shallow [
    base-lib
    { "${xinux-config.namespace}" = user-lib; }
  ];
in
{
  internal = {
    inherit system-lib user-lib;
  };
}
