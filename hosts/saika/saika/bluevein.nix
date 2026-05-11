{
  pkgs,
  lib,
  bluevein,
  ...
}:
{
  imports = [
    bluevein.nixosModules.default
  ];

  services.bluevein = {
    enable = true;
    efiDevice = "/dev/disk/by-partlabel/disk-s790-4t-ESP";
  };
}
