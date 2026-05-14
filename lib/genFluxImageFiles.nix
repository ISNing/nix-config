{
  pkgs,
  k8s-gitops,
  fluxSource,
  fluxPath ? ".",
  namespaces ? [ ],
  imageArch ? null,
  registryMirrors ? { },
  mirrorRetries ? 3,
  compressAsZstd ? false,
  zstdLevel ? 10,
  # Filtering options (all optional, defaults allow all):
  # - namespaces: list of namespaces to include (empty = all, from sources/targets)
  # - imageArch: image architecture to match (null = all)
  # - customFilter: optional custom predicate function (entry -> bool)
  #   If provided, it is combined with base namespace/arch matching.
  #   Example: entry: builtins.any (t: t.kind == "Deployment") (entry.targets or [ ])
  customFilter ? null,
  ...
}:
let
  lib = pkgs.lib;
  fluxSourcePath =
    if builtins.isAttrs fluxSource && fluxSource ? outPath then
      fluxSource.outPath
    else
      toString fluxSource;
  mkMultiArchImageArchive = k8s-gitops.lib.mkMultiArchImageArchive;
  lockFile = "${fluxSourcePath}/${fluxPath}/images.lock.nix";
  lockEntries = if builtins.pathExists lockFile then import lockFile else [ ];

  entryNamespaces =
    entry:
    let
      targetNamespaces = map (t: t.namespace or "") (entry.targets or [ ]);
      sourceNamespaces = map (s: s.namespace or "") (entry.sources or [ ]);
      chainNamespaces = builtins.concatLists (
        map (chain: map (s: s.namespace or "") chain) (entry.sourceChains or [ ])
      );
    in
    builtins.filter (x: x != "") (lib.unique (targetNamespaces ++ sourceNamespaces ++ chainNamespaces));

  namespaceMatch =
    entry: namespaces == [ ] || builtins.any (ns: builtins.elem ns (entryNamespaces entry)) namespaces;

  archMatch = entry: imageArch == null || !entry ? arch || entry.arch == imageArch;

  entryMatch =
    entry:
    namespaceMatch entry
    && archMatch entry
    && (if customFilter != null then customFilter entry else true);

  hasArchiveFields =
    entry:
    let
      imageName = entry.imageName or (entry.finalImageName or null);
    in
    imageName != null && (entry ? imageDigest) && (entry ? archiveHash);

  splitImageName =
    imageName:
    let
      parts = lib.splitString "/" imageName;
      first = if parts == [ ] then "" else builtins.head parts;
      hasExplicitRegistry = lib.hasInfix "." first || lib.hasInfix ":" first || first == "localhost";
      registry = if hasExplicitRegistry then first else "docker.io";
      repoParts = if hasExplicitRegistry then builtins.tail parts else parts;
      repo = lib.concatStringsSep "/" repoParts;
    in
    {
      inherit registry repo;
    };

  normalizeMirrorValue =
    mirrorValue:
    if builtins.isList mirrorValue then
      mirrorValue
    else if builtins.isString mirrorValue then
      [ mirrorValue ]
    else
      [ ];

  imageSources =
    imageName:
    let
      parsed = splitImageName imageName;
      mirrorValue = registryMirrors.${parsed.registry} or [ ];
      mirrorRegs = normalizeMirrorValue mirrorValue;
      mirrorSources = map (mirrorReg: "${mirrorReg}/${parsed.repo}") mirrorRegs;
    in
    lib.unique (mirrorSources ++ [ imageName ]);

  toMultiArchImageArchive =
    entry:
    let
      imageName = entry.imageName or (entry.finalImageName or null);
      finalImageName = entry.finalImageName or imageName;
      finalImageTag = entry.finalImageTag or "latest";
      imageDigest = entry.imageDigest;
      sourceImages = imageSources imageName;
    in
    mkMultiArchImageArchive {
      inherit
        pkgs
        sourceImages
        finalImageName
        finalImageTag
        imageDigest
        mirrorRetries
        ;
      archiveHash = entry.archiveHash;
    };

  selectedEntries = builtins.filter entryMatch lockEntries;
  validEntries = builtins.filter hasArchiveFields selectedEntries;
  skippedEntries = builtins.length selectedEntries - builtins.length validEntries;
  archivedImages = map toMultiArchImageArchive validEntries;

  toZstdImage =
    image:
    let
      base = baseNameOf (toString image);
    in
    pkgs.runCommand "${base}.zst" { nativeBuildInputs = [ pkgs.zstd ]; } ''
      zstd -q -T0 -${toString zstdLevel} --stdout ${image} > "$out"
    '';
in
assert
  skippedEntries == 0
  || throw "genFluxImageFiles found ${toString skippedEntries} lock entries missing fields required by multi-arch archive export (imageName/finalImageName, imageDigest, archiveHash).";
if compressAsZstd then map toZstdImage archivedImages else archivedImages
