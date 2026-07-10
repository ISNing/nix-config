{
  config,
  mysecrets,
  ...
}:
{
  home.file.".ssh/romantic.pub".source = "${mysecrets}/public/romantic.pub";

  programs.ssh = {
    enable = true;

    # default config
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ForwardAgent = false;
        # "a private key that is used during authentication will be added to ssh-agent if it is running"
        AddKeysToAgent = "yes";
        Compression = true;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      "github.com" = {
        # "Using SSH over the HTTPS port for GitHub"
        # "(port 22 is banned by some proxies / firewalls)"
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";

        # Specifies that ssh should only use the identity file explicitly configured above
        # required to prevent sending default identity files first.
        IdentitiesOnly = true;
      };

      "router.319.ccsn.dev" = {
        HostName = "router.319.ccsn.dev";
        Port = 22;
        User = "tunnel";
      };

      "isning-nosql.319.local" = {
        HostName = "192.168.1.98";
        Port = 22;
        User = "root";
        ProxyJump = "router.319.ccsn.dev";
      };

      "kubevirt-dl160" = {
        HostName = "192.168.1.161";
        Port = 22;
        User = "snc";
        ProxyJump = "router.319.ccsn.dev";
      };

      "kubevirt-t410" = {
        HostName = "192.168.1.162";
        Port = 22;
        User = "snc";
        ProxyJump = "router.319.ccsn.dev";
      };

      "kubevirt-dl380" = {
        HostName = "192.168.1.163";
        Port = 22;
        User = "root";
        ProxyJump = "router.319.ccsn.dev";
      };

      # "192.168.*" = {
      #   # "allow to securely use local SSH agent to authenticate on the remote machine."
      #   # "It has the same effect as adding cli option `ssh -A user@host`"
      #   ForwardAgent = true;
      #   # "romantic holds my homelab~"
      #   IdentityFile = "/etc/agenix/ssh-key-romantic";
      #   IdentitiesOnly = true;
      # };
    };
  };
}
