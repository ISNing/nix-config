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
      # https://mirror.sjtu.edu.cn/ responds HTTP error 500 timeout for 404 paths
      # https://mirrors.sjtug.sjtu.edu.cn/ can respond 404 immediately, so use it for now
      # status: https://mirrors.sjtug.sjtu.edu.cn/
      "https://mirrors.sjtug.sjtu.edu.cn/nix-channels/store"

      "https://mirror.nju.edu.cn/nix-channels/store"
      # Using WAF before mirror, causing 468, maybe low rps limit?
      # "https://mirrors.cqupt.edu.cn/nix-channels/store"

      "https://nix-community.cachix.org"

      # my own cache server
      "https://isning.cachix.org"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "isning.cachix.org-1:WTBOxWUkAhuZGq7FtTRwK8jrpsLh23nCjeIgBb1aNDE="
    ];
    builders-use-substitutes = true;
  };
}
