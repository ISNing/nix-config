{ config, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [ ../../linux/gui.nix ];

  programs.ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/saika";

  modules.desktop.gaming.enable = true;
  modules.desktop.niri.enable = true;
  modules.desktop.nvidia.enable = true;

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink "${config.home.homeDirectory}/nix-config/hosts/saika/niri-hardware.kdl";
}
