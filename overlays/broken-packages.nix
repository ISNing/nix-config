_:
(self: super: {
  openldap = super.openldap.overrideAttrs (oldAttrs: {
    doCheck = false;
  });

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
