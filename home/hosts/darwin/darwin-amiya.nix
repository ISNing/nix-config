{ config, ... }:
let
  hostName = "amiya";
in
{
  imports = [ ../../darwin ];

  programs.ssh.settings."github.com".IdentityFile = "${config.home.homeDirectory}/.ssh/${hostName}";
}
