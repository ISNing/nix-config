{ lib, pkgs, ... }:
{

  # Only apply the battery-tailored profile when on battery.
  # tuned-ppd handles the AC↔battery transition automatically.
  services.tuned.ppdSettings.battery = {
    power-saver = "powersave-battery";
  };

  services.tuned.profiles."powersave-battery" = {
    main = {
      include = "powersave";
    };
    cpu = {
      energy_perf_bias = "power";
      boost = "1";
      force_latency = "None";
    };
    sysfs = {
      # Enable PCI runtime PM for all devices. This allows
      # unused PCI controllers to enter D3cold, saving power
      # (confirmed 36/36 devices on saika).
      "/sys/bus/pci/devices/*/power/control" = "auto";
      # Wake immediately — no delay before suspending PCI devices.
      "/sys/bus/pci/devices/*/power/autosuspend_delay_ms" = "0";

      "/sys/firmware/acpi/platform_profile" = "low-power";
      "/sys/module/pcie_aspm/parameters/policy" = "powersupersave";

      # Disable SMT on battery. The kernel's sched domain rebuild
      # (triggered by CPU hotplug) re-evaluates EAS conditions.
      # When SMT is off on a hybrid CPU, intel_pstate registers an
      # Energy Model, and EAS activates automatically.
      "/sys/devices/system/cpu/smt/control" = "off";
    };
    sysctl = {
      # nmi_watchdog causes periodic wakeups; disable on battery.
      "kernel.nmi_watchdog" = "0";
      # Aggregate dirty pages more aggressively to reduce disk
      # writeback wakeups. 5% / 2% is safe for SSDs and avoids
      # long stalls under memory pressure.
      "vm.dirty_ratio" = "5";
      "vm.dirty_background_ratio" = "2";
    };
    # HAD codec power-save timeout (seconds).
    audio.timeout = "1";
    # Reduce disk read-ahead (kB). 256 is conservative for SSDs;
    # lowers power from fewer speculative reads.
    disk.readahead = "256";
    # USB autosuspend timeout (seconds). Standard plugin only
    # sets autosuspend, NOT power/control=auto, to avoid latency
    # on HID devices.
    usb.autosuspend = "1";
    script.script = "script.sh";
  };

  # The TuneD [script] plugin rejects paths outside the profile
  # directory, so we place the script via environment.etc.
  # It lowers the built-in display to 60 Hz on battery and
  # restores 165 Hz when switching back to AC.
  environment.etc."tuned/profiles/powersave-battery/script.sh" = {
    source = pkgs.writeShellScript "powersave-battery-script" ''
      action="''${1:-start}"
      log="/tmp/powersave-battery-debug.log"
      echo "$(date): action=$action" >> "$log"

      niri_socket="$(ls /run/user/1000/niri.wayland-*.sock 2>/dev/null | head -1)"
      echo "socket: $niri_socket" >> "$log"
      case "$action" in
        start|apply)
          if [ -n "$niri_socket" ]; then
            NIRI_SOCKET="$niri_socket" /run/current-system/sw/bin/niri msg output "eDP-1" mode "3200x2000@60.000" >> "$log" 2>&1
            echo "niri exit: $?" >> "$log"
          fi
          ;;
        stop|unapply)
          if [ -n "$niri_socket" ]; then
            NIRI_SOCKET="$niri_socket" /run/current-system/sw/bin/niri msg output "eDP-1" mode "3200x2000@165.001" >> "$log" 2>&1
            echo "niri exit: $?" >> "$log"
          fi
          ;;
      esac
    '';
    mode = "0755";
  };
}
