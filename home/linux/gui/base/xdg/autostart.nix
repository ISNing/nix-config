{ pkgs, lib, ... }:
{
  # XDG autostart entries - ensures apps start after portal services are ready
  xdg.autostart.enable = true;
  # This fixes nixpak sandboxed apps (like firefox) accessing mapped folders correctly
  xdg.autostart.entries = [
    "${pkgs.foot}/share/applications/foot.desktop"

    "${pkgs.clash-verge-rev}/share/applications/clash-verge.desktop"

    "${pkgs.bitwarden-desktop}/share/applications/bitwarden.desktop"

    # nixpaks
    "${pkgs.nixpaks.telegram-desktop}/share/applications/org.telegram.desktop.desktop"
  ]
  ++ (
    if pkgs.stdenv.isx86_64 then
      [ "${pkgs.google-chrome}/share/applications/google-chrome.desktop" ]
    else
      [ "${pkgs.chromium}/share/applications/chromium-browser.desktop" ]
  );
}
