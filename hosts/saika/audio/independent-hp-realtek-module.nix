{
  kernel,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "snd-hda-codec-alc269-independent-hp";
  version = kernel.modDirVersion;
  src = kernel.src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  postUnpack = ''
    moduleRoot="$PWD/module-source"
    mkdir -p "$moduleRoot/sound/hda"
    cp -r "$sourceRoot/sound/hda/codecs" "$moduleRoot/sound/hda/codecs"
    cp -r "$sourceRoot/sound/hda/common" "$moduleRoot/sound/hda/common"
    chmod -R u+w "$moduleRoot"

    cp ${./independent-hp-realtek-module/Makefile} \
      "$moduleRoot/sound/hda/codecs/realtek/Makefile"
    patch --directory="$moduleRoot" --strip=1 \
      < ${./independent-hp-realtek-module/alc269-independent-hp.patch}

    sourceRoot="$moduleRoot/sound/hda/codecs/realtek"
  '';

  buildPhase = ''
    runHook preBuild
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M="$PWD" modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 snd-hda-codec-alc269.ko \
      "$out/lib/modules/${kernel.modDirVersion}/extra/snd-hda-codec-alc269.ko"
    runHook postInstall
  '';
}
