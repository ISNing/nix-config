{
  lib,
  pkgs,
  blender-bin,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      # creative
      # gimp      # image editing, I prefer using figma in browser instead of this one
      inkscape # vector graphics
      krita # digital painting
      musescore # music notation
      # reaper # audio production
      # sonic-pi # music programming

      # 2d game design
      # aseprite # Animated sprite editor & pixel art tool

      # this app consumes a lot of storage, so do not install it currently
      # kicad     # 3d printing, electrical engineering

      # office
      libreoffice-qt6-fresh
      hunspell # spell check for libreoffice
      hunspellDicts.en_US # USA English
      hyphenDicts.en_GB # British English

    ]
    ++ (lib.optionals pkgs.stdenv.isx86_64 [
      # https://github.com/edolstra/nix-warez/blob/master/blender/flake.nix
      blender-bin.packages.${pkgs.stdenv.hostPlatform.system}.blender_4_2 # 3d modeling

      ldtk # A modern, versatile 2D level editor

      # fpga
      # python313Packages.apycula # gowin fpga
      # yosys # fpga synthesis
      # nextpnr # fpga place and route
      # openfpgaloader # fpga programming
      # nur-ryan4yin.packages.${pkgs.stdenv.hostPlatform.system}.gowin-eda-edu-ide # app: `gowin-env` => `gw_ide` / `gw_pack` / ...
    ]);

  programs = {
    # live streaming
    obs-studio = {
      enable = pkgs.stdenv.isx86_64;
      plugins = with pkgs.obs-studio-plugins; [
        # screen capture
        wlrobs
        # obs-ndi
        # obs-nvfbc
        obs-teleport
        # obs-hyperion
        # FIXME: Temporaryly disable it since build failure: https://github.com/NixOS/nixpkgs/issues/461403
        # droidcam-obs
        obs-vkcapture
        obs-gstreamer
        input-overlay
        obs-multi-rtmp
        obs-source-clone
        obs-shaderfilter
        obs-source-record
        obs-livesplit-one
        looking-glass-obs
        obs-vintage-filter
        obs-command-source
        obs-move-transition
        obs-backgroundremoval
        # advanced-scene-switcher
        obs-pipewire-audio-capture
        obs-vaapi
        obs-3d-effect
      ];
    };
  };
}
