_:
(self: super: {
  python3Packages = super.python3Packages.overrideScope (
    _final: prev: {
      # Ensure the python package itself doesn't run its test phases.
      pipx = prev.pipx.overrideAttrs (_: {
        doCheck = false;
        doInstallCheck = false;
        checkPhase = ":";
      });
    }
  );

  pipx = super.pipx.overrideAttrs (_: {
    doCheck = false;
    doInstallCheck = false;
    checkPhase = ":";
  });
})
