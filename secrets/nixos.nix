{
  lib,
  config,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
with lib;
let
  cfg = config.modules.secrets;

  enabledServerSecrets = cfg.server.kubernetes.enable;

  noaccess = {
    mode = "0000";
    owner = "root";
  };
  high_security = {
    mode = "0500";
    owner = "root";
  };
  user_readable = {
    mode = "0500";
    owner = myvars.username;
  };
in
{
  imports = [
    agenix.nixosModules.default
  ];

  options.modules.secrets = {
    desktop.enable = mkEnableOption "NixOS Secrets for Desktops";
    host.saika.enable = mkEnableOption "NixOS Secrets for Saika";

    server.kubernetes.enable = mkEnableOption "NixOS Secrets for my homelab servers";

    preservation.enable = mkEnableOption "whether use preservation and ephemeral root file system";
  };

  config = mkIf (cfg.desktop.enable || enabledServerSecrets) (mkMerge [
    {
      environment.systemPackages = [
        agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
      ];

      # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
      age.identityPaths =
        if cfg.preservation.enable then
          [
            # To decrypt secrets on boot, this key should exists when the system is booting,
            # so we should use the real key file path(prefixed by `/persistent/`) here, instead of the path mounted by preservation.
            "/persistent/etc/ssh/ssh_host_ed25519_key" # Linux
          ]
        else
          [
            "/etc/ssh/ssh_host_ed25519_key"
          ];

      # secrets that are used by all nixos hosts
      age.secrets = {
        "nix-access-tokens" = {
          file = "${mysecrets}/nix-access-tokens.age";
        }
        # access-token needs to be readable by the user running the `nix` command
        // user_readable;
      };

      assertions = [
        {
          # This expression should be true to pass the assertion
          assertion = !(cfg.desktop.enable && enabledServerSecrets);
          message = "Enable either desktop or server's secrets, not both!";
        }
      ];
    }

    (mkIf cfg.host.saika.enable {
      age.secrets = {
        "saika-bitlk-crypt-keys/YMTC-3-2E9FEE63-8BBA-4CCA-89E4-CB8D0E7EB084.BEK" = {
          file = "${mysecrets}/saika-bitlk-crypt-keys/YMTC-3-2E9FEE63-8BBA-4CCA-89E4-CB8D0E7EB084.BEK.age";
          mode = "0400";
          owner = "root";
        };
        "saika-bitlk-crypt-keys/YMTC-5-F13C1B91-772E-499F-A014-4A7C8D8A1EE1.BEK" = {
          file = "${mysecrets}/saika-bitlk-crypt-keys/YMTC-5-F13C1B91-772E-499F-A014-4A7C8D8A1EE1.BEK.age";
          mode = "0400";
          owner = "root";
        };
        "saika-bitlk-crypt-keys/FANX-2-2945A11B-7C4E-415D-A27C-4416A856DD63.BEK" = {
          file = "${mysecrets}/saika-bitlk-crypt-keys/FANX-2-2945A11B-7C4E-415D-A27C-4416A856DD63.BEK.age";
          mode = "0400";
          owner = "root";
        };
      };
    })

    (mkIf cfg.desktop.enable {
      age.secrets = {
        # ---------------------------------------------
        # no one can read/write this file, even root.
        # ---------------------------------------------

        # .age means the decrypted file is still encrypted by age(via a passphrase)
        #  "ryan4yin-gpg-subkeys.priv.age" = {
        #    file = "${mysecrets}/ryan4yin-gpg-subkeys-2024-01-27.priv.age.age";
        #  }
        #  // noaccess;

        # ---------------------------------------------
        # only root can read this file.
        # ---------------------------------------------

        #  "wg-business.conf" = {
        #    file = "${mysecrets}/wg-business.conf.age";
        #  }
        #  // high_security;

        # ---------------------------------------------
        # user can read this file.
        # ---------------------------------------------

        "ssh-key-romantic" = {
          file = "${mysecrets}/ssh-key-romantic.age";
        }
        // user_readable;
      };

      # place secrets in /etc/
      environment.etc = {
        "agenix/ssh-key-romantic" = {
          source = config.age.secrets."ssh-key-romantic".path;
          mode = "0600";
          user = myvars.username;
        };
      };
    })

    (mkIf cfg.server.kubernetes.enable {
      age.secrets = {
        "k3s-registries.yaml" = {
          file = "${mysecrets}/kubernetes/registries.yaml.age";
        }
        // high_security;
        "kubevirt-k3s-token" = {
          file = "${mysecrets}/kubernetes/kubevirt-k3s-token.age";
        }
        // high_security;
      };

      # place secrets in /etc/
      environment.etc = {
        # use mirrors for container registries, so that we can pull images faster and more reliably
        "rancher/k3s/registries.yaml" = {
          source = config.age.secrets."k3s-registries.yaml".path;
        };
      };
    })
  ]);
}
