{
  nur,
  nuenv,
  colmena,
  ...
}@args:
{
  nixpkgs.overlays = [
    nur.overlays.default
    nuenv.overlays.default
    colmena.overlays.default
  ]
  ++ (import ../../overlays args);
}
