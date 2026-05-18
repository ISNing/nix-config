{
  lib,
  config,
  pkgs,
  ...
}:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [
    # screen annotation
    wayscriber
  ];

  systemd.user.services.wayscriber = {
    Unit = {
      Description = "Wayscriber Daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      # https://github.com/devmobasa/wayscriber
      # If the tray icon is blank or the menu shows square placeholders (notably Noctalia/Quickshell),
      # start the daemon with WAYSCRIBER_TRAY_FORCE_PIXMAP=1.
      Environment = "WAYSCRIBER_TRAY_FORCE_PIXMAP=1";
      ExecStart = "${lib.getExe pkgs.wayscriber} --daemon";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  xdg.configFile."wayscriber/config.toml".source =
    mkSymlink "${config.home.homeDirectory}/nix-config/home/linux/gui/base/wayscriber/config/config.toml";
}
