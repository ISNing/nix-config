{ lib }:
rec {
  mainGateway = "192.168.1.1"; # main router
  mainGateway6 = "fe80::1"; # main router's link-local address

  # No transparent proxy for now
  proxyGateway = mainGateway;
  proxyGateway6 = mainGateway6;
  nameservers = [
    # IPv4
    "119.29.29.29" # DNSPod
    "223.5.5.5" # AliDNS
    # IPv6
    "2400:3200::1" # Alidns
    "2606:4700:4700::1111" # Cloudflare
  ];
  prefixLength = 24;

  hostsAddr = {
    # ============================================
    # Homelab's Physical Machines (KubeVirt Nodes)
    # ============================================
    whitefox = {
      iface = "enp11s0";
      ipv4 = "192.168.1.101";
    };

    # ============================================
    # Other VMs and Physical Machines
    # ============================================
  };

  hostsInterface = lib.attrsets.mapAttrs (key: val: {
    interfaces."${val.iface}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          inherit prefixLength;
          address = val.ipv4;
        }
      ];
    };
  }) hostsAddr;

  ssh = {
    # define the host alias for remote builders
    # this config will be written to /etc/ssh/ssh_config
    #
    # Config format:
    #   Host —  given the pattern used to match against the host name given on the command line.
    #   HostName — specify nickname or abbreviation for host
    #   IdentityFile — the location of your SSH key authentication file for the account.
    # Format in details:
    #   https://www.ssh.com/academy/ssh/config
    extraConfig = (
      lib.attrsets.foldlAttrs (
        acc: host: val:
        acc
        + ''
          Host ${host}
            HostName ${val.ipv4}
            Port 22
        ''
      ) "" hostsAddr
    );

    # this config will be written to /etc/ssh/ssh_known_hosts
    knownHosts =
      # Update only the values of the given attribute set.
      #
      #   mapAttrs
      #   (name: value: ("bar-" + value))
      #   { x = "a"; y = "b"; }
      #     => { x = "bar-a"; y = "bar-b"; }
      lib.attrsets.mapAttrs
        (host: value: {
          hostNames = [ host ] ++ (lib.optional (hostsAddr ? host) hostsAddr.${host}.ipv4);
          publicKey = value.publicKey;
        })
        {
          # Define the root user's host key for remote builders, so that nix can verify all the remote builders

          saika.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbTH2mluncgUj96jwSD1ADFUY//NvWFGanpACQ8n4Dx root@saika";
          amiya.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGBokNWi0OyCVjpM2hLYYRoefVN8vTSEnwoPe34JiGF/ ";
          whitefox.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAD4XvKvVpK/LBX44Nr9SzKkfbc0GTlYZObQ0uwchIT root@whitefox";
          # ruby.publicKey = "";
          # kana.publicKey = "";

          # ==================================== Other SSH Service's Public Key =======================================

          # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
          "github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
  };
}
