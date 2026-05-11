{
  pkgs,
  fluxSource,
  fluxPath ? ".",
  namespaces ? [ ],
  imageArch ? null,
  registryMirrors ? { },
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
  lockFile = "${toString fluxSource}/${fluxPath}/images.lock.nix";
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
    imageName != null && (entry ? imageDigest);

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

  imageSource =
    imageName:
    let
      parsed = splitImageName imageName;
      mappedRegistry = registryMirrors.${parsed.registry} or parsed.registry;
    in
    "${mappedRegistry}/${parsed.repo}";

  toMultiArchImageArchive =
    entry:
    let
      imageName = entry.imageName or (entry.finalImageName or null);
      finalImageName = entry.finalImageName or imageName;
      finalImageTag = entry.finalImageTag or "latest";
      imageDigest = entry.imageDigest;
      sourceImage = imageSource imageName;
      safeName = lib.replaceStrings [ "/" ":" "@" ] [ "-" "-" "-" ] finalImageName;
      safeTag = lib.replaceStrings [ "/" ":" ] [ "-" "-" ] finalImageTag;
      safeDigest = lib.replaceStrings [ ":" ] [ "-" ] imageDigest;
    in
    pkgs.runCommand "${safeName}-${safeTag}-${safeDigest}.tar"
      {
        nativeBuildInputs = [
          pkgs.skopeo
        ];
      }
      ''
        skopeo copy --insecure-policy --multi-arch all \
          "docker://${sourceImage}@${imageDigest}" \
          "oci-archive:$out:${finalImageName}:${finalImageTag}"
      '';

  selectedEntries = builtins.filter entryMatch lockEntries;
  validEntries = builtins.filter hasArchiveFields selectedEntries;
  skippedEntries = builtins.length selectedEntries - builtins.length validEntries;
  archivedImages = map toMultiArchImageArchive validEntries;

  toZstdImage =
    image:
    let
      base = builtins.baseNameOf (toString image);
    in
    pkgs.runCommand "${base}.zst" { nativeBuildInputs = [ pkgs.zstd ]; } ''
      zstd -q -T0 -${toString zstdLevel} --stdout ${image} > "$out"
    '';

  _ =
    if skippedEntries > 0 then
      builtins.trace "genFluxImageFiles skipped ${toString skippedEntries} lock entries missing fields required by multi-arch archive export (imageName/finalImageName, imageDigest)." null
    else
      null;
in
if compressAsZstd then map toZstdImage archivedImages else archivedImages
