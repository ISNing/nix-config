{
  catppuccin,
  pkgs,
  ...
}:
{
  # https://github.com/catppuccin/nix
  imports = [
    catppuccin.homeModules.catppuccin
  ];

  catppuccin = {
    # The default `enable` value for all available programs.
    enable = true;
    sources = catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.overrideScope (
      _final: _prev: {
        whiskers = pkgs.catppuccin-whiskers;
      }
    );
    # one of "latte", "frappe", "macchiato", "mocha"
    flavor = "mocha";
    # one of "blue", "flamingo", "green", "lavender", "maroon", "mauve", "peach", "pink", "red", "rosewater", "sapphire", "sky", "teal", "yellow"
    accent = "pink";

    kvantum.assertStyle = false;
    # FIXME: broken package
    # error: hash mismatch in fixed-output derivation '/nix/store/56wsr4lf1hyg7p068fp5dg4m7zb4yws3-vscode-extension-catppuccin-vscode-pnpm-deps.drv':
    #      specified: sha256-sPJhXj13O16kcaJ8LtJaGOtFxdXBl23wmCV4hcEhz4I=
    #         got:    sha256-Rjd4bOnkMcj6rPAvhTqbppseW/5poSQjhRtti/zzCeI=
    vscode.enable = false;
  };
}
