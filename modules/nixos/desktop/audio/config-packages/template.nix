{
  pkgs,
  packageName,
  registrationFileName,
  luaScriptName,
  registrationText,
  scriptBody,
  passthru ? { },
}:
pkgs.symlinkJoin {
  name = packageName;
  paths = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/${registrationFileName}" registrationText)
    (pkgs.writeTextDir "share/wireplumber/scripts/${luaScriptName}" scriptBody)
  ];
  inherit passthru;
}
