{ lib, ... }:
# ===================================================================
# Remove packages that are not well supported for the Darwin platform
# ===================================================================
let
  brokenPackages = [
    "terraform"
    "terraformer"
    "packer"
    "git-trim"
    "conda"
    "mitmproxy"
    "insomnia"
    "wireshark"
    "jsonnet"
    "zls"
    "verible"
    "gdb"
    "ncdu"
    "racket-minimal"
    "ffmpeg-full"
  ];
in
{
  nixpkgs.overlays = [
    (_: super: {
      # nushell test suite can fail in Darwin sandbox due to restricted process/env behavior.
      nushell = super.nushell.overrideAttrs (_: {
        doCheck = false;
        doInstallCheck = false;
      });

      gopls = super.gopls.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          rm -f $out/bin/modernize
        '';
      });

      gotools = super.gotools.overrideAttrs (old: {
        meta = (old.meta or { }) // {
          priority = 10;
        };
        postFixup = (old.postFixup or "") + ''
          rm -f $out/bin/modernize
        '';
      });

      python3Packages = super.python3Packages.overrideScope (
        _final: prev: {
          "pass-import" = prev."pass-import".overridePythonAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
            pythonImportsCheck = [ ];
          });

          jeepney = prev.jeepney.overridePythonAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
            pythonImportsCheck = [ ];
          });

          secretstorage = prev.secretstorage.overridePythonAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
            pythonImportsCheck = [ ];
          });
        }
      );
    })
    (
      _: super:
      let
        removeUnwantedPackages =
          pname: lib.warn "the ${pname} has been removed on the darwin platform" super.emptyDirectory;
      in
      lib.genAttrs brokenPackages removeUnwantedPackages
    )
  ];
}
