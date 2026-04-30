_:
(self: super: {
  openldap = super.openldap.overrideAttrs (oldAttrs: {
    doCheck = false;
  });
})
