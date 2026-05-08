{
  pkgs,
  config,
  myvars,
  ...
}:
{
  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # given the users in this list the right to specify additional substituters via:
    #    1. `nixConfig.substituers` in `flake.nix`
    #    2. command line args `--options substituers http://xxx`
    trusted-users = [ myvars.username ];

    # substituers that will be considered before the official ones(https://cache.nixos.org)
    substituters = [
      # cache mirror located in China
      # status: https://mirrors.tuna.tsinghua.edu.cn/status/
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      # status: https://mirrors.ustc.edu.cn/status/
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      # status: https://mirror.sjtu.edu.cn/
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      # others
      # "https://mirrors.sustech.edu.cn/nix-channels/store"
      #"https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"

      "https://nix-community.cachix.org"
      # my own cache server
      "https://isning.cachix.org"
      "https://jetcookies.cachix.org"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "isning.cachix.org-1:WTBOxWUkAhuZGq7FtTRwK8jrpsLh23nCjeIgBb1aNDE="
      "jetcookies.cachix.org-1:YM4ERAadhoioRkDA5ZKgnKN98N5x0ubV8t6HeIekcnc="
    ];
    builders-use-substitutes = true;
  };
}
