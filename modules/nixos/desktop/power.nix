{ ... }:
{
  # TuneD - Tuning Profile Delivery Mechanism for Linux
  # A modern replacement for PPD(power-profiles-daemon)
  services.tuned = {
    enable = true;
    settings.dynamic_tuning = true;
    ppdSupport = true; # translation of power-profiles-daemon API calls to TuneD
    ppdSettings.main.default = "balanced"; # balanced / performance / power-saver
  };
  # DBus service that provides power management support to applications
  # Required by `tuned-ppd` for handling power supply changes
  services.upower.enable = true;

  services.power-profiles-daemon.enable = false; # conflicts with tuned
  services.tlp.enable = false; # conflicts with tuned

  # scx_lavd scheduler for better power and performance
  # In theory, it should help with lower latency at gaming and avoid frequent CPU awake from deep C-states
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = [ "--autopower" ];
  };
}
