{
  config,
  pkgs,
  ...
}:
let
  independentHpModule = pkgs.callPackage ./independent-hp-module.nix {
    kernel = config.boot.kernelPackages.kernel;
  };

  independentHpRealtekModule = pkgs.callPackage ./independent-hp-realtek-module.nix {
    kernel = config.boot.kernelPackages.kernel;
  };

  hdaPatch = pkgs.writeText "sof-indep-hp-alc287.fw" ''
    [codec]
    0x10ec0287 0x17aa38f9 0
    [hint]
    indep_hp = yes
  '';

  topologySource = pkgs.fetchFromGitHub {
    owner = "thesofproject";
    repo = "sof";
    rev = "v2.14";
    hash = "sha256-Y3byJmoANVeilJpO82aljBZas/6u6VqfynYl0csW1as=";
  };

  topology =
    pkgs.runCommand "sof-hda-generic-independent-hp.tplg"
      {
        nativeBuildInputs = [
          pkgs.alsa-utils
          pkgs.bash
          pkgs.patch
        ];
      }
      ''
        cp -r ${topologySource} source
        chmod -R u+w source
        patch --directory=source --strip=1 < ${./sof-hda-independent-hp-topology.patch}

        bash source/tools/topology/topology2/get_abi.sh source ipc4 > abi.conf
        cat abi.conf source/tools/topology/topology2/sof-hda-generic.conf > sof-hda-generic.conf

        export ALSA_CONFIG_DIR=$PWD/source/tools/topology/topology2
        alsatplg -I "$ALSA_CONFIG_DIR" \
          -D "HDA_CONFIG=mix,INDEPENDENT_HP=true,NUM_DMICS=2,DMIC0_ID=7,DMIC1_ID=8,DMIC0_ENHANCED_CAPTURE=true,EFX_DMIC0_TDFB_PARAMS=line2_generic_pm10deg,EFX_DMIC0_DRC_PARAMS=dmic_default" \
          -p -c sof-hda-generic.conf -o sof-hda-generic-independent-hp.tplg

        install -Dm444 sof-hda-generic-independent-hp.tplg \
          "$out/lib/firmware/intel/sof-ipc4-tplg/sof-hda-generic-independent-hp.tplg"
      '';

  ucmLongName = "LENOVO-21N5-ThinkBook16pG5IRX-LNVNB161216";

  # ALSA's UCM configuration lives in the immutable store on NixOS.  Keep the
  # upstream database intact and add a board-specific mapping which points at
  # a copied, patched SOF-HDA UCM tree.  In particular, do not shadow
  # Intel/sof-hda-dsp: other SOF-HDA cards must continue to use it unchanged.
  independentHpUcm = pkgs.symlinkJoin {
    name = "alsa-ucm-conf-sof-independent-hp";
    paths = [
      pkgs.alsa-ucm-conf
      (pkgs.runCommand "sof-independent-hp-ucm"
        {
          nativeBuildInputs = [
            pkgs.patch
          ];
        }
        ''
          upstream=${pkgs.alsa-ucm-conf}/share/alsa/ucm2
          work="$PWD/ucm2"
          install -d "$work/Intel" "$work/HDA" \
            "$work/conf.d/sof-hda-dsp"

          # This is a private copy of the official SOF HDA UCM tree.  It is
          # deliberately installed under a new directory, not over the
          # upstream Intel/sof-hda-dsp directory.
          cp -r "$upstream/Intel/sof-hda-dsp" \
            "$work/Intel/sof-hda-dsp-independent-hp"
          cp "$upstream/HDA/HiFi-analog.conf" \
            "$work/HDA/HiFi-independent-hp-analog.conf"
          chmod -R u+w "$work"

          # ALSA discovers a card's UCM through conf.d/<card-id>/<long-name>.
          # Make that mapping a symlink just like upstream does, so relative
          # includes (dsp.conf and HiFi-sof.conf) resolve inside our private
          # copied tree rather than beside the mapping file.
          ln -s ../../Intel/sof-hda-dsp-independent-hp/sof-hda-dsp.conf \
            "$work/conf.d/sof-hda-dsp/${ucmLongName}.conf"

          patch --directory="$work" --strip=1 < ${./ucm/sof-hda-independent-hp-ucm.patch}

          install -d "$out/share/alsa/ucm2"
          cp -r "$work/." "$out/share/alsa/ucm2/"
        ''
      )
    ];
  };
in
{
  boot.extraModulePackages = [
    independentHpModule
    independentHpRealtekModule
  ];
  # Load the patched codec before the tree-out machine driver binds the HDA
  # codec.  It has the upstream module name, so depmod resolves it in extra/.
  boot.kernelModules = [
    "snd-hda-codec-alc269"
    "snd-soc-skl-hda-dsp-independent-hp"
  ];
  boot.blacklistedKernelModules = [ "snd_soc_skl_hda_dsp" ];

  boot.kernelParams = [
    "snd_sof.tplg_filename=sof-hda-generic-independent-hp.tplg"
    "snd_soc_hdac_hda.patch=sof-indep-hp-alc287.fw"
  ];

  hardware.firmware = [
    (pkgs.writeTextFile {
      name = "sof-indep-hp-alc287-firmware";
      destination = "/lib/firmware/sof-indep-hp-alc287.fw";
      text = builtins.readFile hdaPatch;
    })
    topology
  ];

  # Set by PAM early in the login process, so PipeWire and WirePlumber use
  # the same native UCM database without any ACP/profile property override.
  environment.sessionVariables = {
    ALSA_CONFIG_UCM2 = "${independentHpUcm}/share/alsa/ucm2";
  };
}
