{
  kernel,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "snd-soc-skl-hda-dsp-independent-hp";
  version = kernel.modDirVersion;
  src = kernel.src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  postUnpack = ''
    moduleRoot="$PWD/module-source"
    mkdir -p "$moduleRoot"
    cp "$sourceRoot/sound/soc/intel/boards/skl_hda_dsp_generic.c" "$moduleRoot/"
    cp ${./independent-hp-module/Makefile} "$moduleRoot/"
    patch --directory="$moduleRoot" --strip=1 \
      < ${./independent-hp-module/skl-hda-dsp-independent-hp.patch}
    sourceRoot="$moduleRoot"
  '';

  buildPhase = ''
    runHook preBuild
    cp ${./independent-hp-module/Makefile} Makefile
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M="$PWD" modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 snd-soc-skl-hda-dsp-independent-hp.ko \
      "$out/lib/modules/${kernel.modDirVersion}/extra/snd-soc-skl-hda-dsp-independent-hp.ko"
    runHook postInstall
  '';
}
