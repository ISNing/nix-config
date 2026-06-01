{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    (lib.optionals pkgs.stdenv.isx86_64 [
      # https://joplinapp.org/help/
      # joplin # joplin-cli
      # joplin-desktop
      siyuan # Self-hosted note-taking app, similar to logseq and obsidian
      zotero # reference management software
      rnote # hand-writing note-taking app like goodnotes, uses dconf, no extra preservation needed
    ]);
}
