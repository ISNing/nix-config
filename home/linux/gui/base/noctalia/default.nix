{
  lib,
  config,
  pkgs,
  wallpapers,
  noctalia,
  nur-isning,
  ...
}:

{
  imports = [ noctalia.homeModules.default ];

  home.sessionVariables = {
    "QT_QPA_PLATFORM" = "wayland;xcb";
    "QT_AUTO_SCREEN_SCALE_FACTOR" = "1";
  };

  home.packages = [
    nur-isning.packages.${pkgs.stdenv.hostPlatform.system}.qt6ct
    pkgs.app2unit
  ]
  ++ (lib.optionals pkgs.stdenv.isx86_64 [
    pkgs.gpu-screen-recorder
  ]);

  # Wrap noctalia so ddcutil is in PATH only for noctalia, not globally
  programs.noctalia.package =
    let
      orig = noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    pkgs.symlinkJoin {
      name = "${orig.name}-wrapped";
      paths = [ orig ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/noctalia \
          --prefix PATH : ${pkgs.ddcutil}/bin
      '';
      meta.mainProgram = "noctalia";
    };

  home.file."Pictures/Wallpapers".source = wallpapers;

  xdg.configFile."qt6ct/qt6ct.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/linux/gui/base/noctalia/qt6ct.conf";

  programs.noctalia = {
    enable = true;

    settings = {
      # ── Theme ──────────────────────────────────────────────
      # Match v4 behavior: wallpaper-derived M3 tonal-spot palette,
      # auto-scheduled dark/light mode by location.
      theme = {
        mode = "auto";
        source = "wallpaper";
        wallpaper_scheme = "m3-tonal-spot";
      };

      # ── Shell ──────────────────────────────────────────────
      shell = {
        avatar_path = "~/nix-config/_img/myself.jpg";
        font_family = "LXGW WenKai Screen";
        lang = "";
        time_format = "{:%H:%M}";
        date_format = "%A, %x";
        corner_radius_scale = 1.5;
        screen_time_enabled = true;
        telemetry_enabled = false;
        setup_wizard_enabled = false;
        launch_apps_as_systemd_services = true;

        shadow = {
          direction = "down_right";
          alpha = 0.55;
        };

        panel = {
          transparency_mode = "glass";
          launcher_placement = "centered";
          clipboard_placement = "centered";
          control_center_placement = "attached";
          open_near_click_control_center = true;
          session_placement = "attached";
        };

        launcher = {
          categories = true;
          show_icons = true;
          sort_by_usage = true;
          session_search = true;
          compact = false;
          app_grid = false;
        };

        animation = {
          enabled = true;
          speed = 1.0;
        };
      };

      # ── Bar ────────────────────────────────────────────────
      # v4 → v5:
      #   left:   Launcher, Clock, [GPU], capsule-group(cpu+ram+net_tx+net_rx), ActiveWindow, MediaMini
      #   center: Workspace
      #   right:  Notifications, Battery, Volume, Brightness, Network, Tray, ControlCenter
      bar = {
        order = [ "main" ];
        main = {
          position = "top";
          auto_hide = false;
          reserve_space = true;
          thickness = 34;
          background_opacity = 0.5;
          radius = 80;
          margin_ends = 5;
          margin_edge = 5;
          widget_spacing = 6;
          padding = 5;
          scale = 1.0;
          capsule = true;
          capsule_opacity = 1.0;
          capsule_thickness = 0.8;

          capsule_group = [
            {
              id = "g1";
              enabled = true;
              fill = "surface_variant";
              opacity = 1.0;
              padding = 6.0;
              members = [
                "cpu"
                "ram"
                "network_tx"
                "network_rx"
              ];
            }
          ];

          start = [
            "launcher"
            "clock"
            "group:g1"
            "active_window"
            "media"
          ];
          center = [ "workspaces" ];
          end = [
            "volume"
            "brightness"
            "network"
            "battery"
            "notifications"
            "tray"
            "control-center"
          ];
        };
      };

      # ── Widgets ────────────────────────────────────────────
      widget = {
        launcher = {
          glyph = "rocket";
        };
        clock = {
          format = "{:%H:%M} {:%a}, {:%b} {:%d}";
          tooltip_format = "{:%A}, {:%B} {:%d} {:%Y}";
        };
        workspaces = {
          display = "id";
          minimal = false;
          labels_only_when_occupied = true;
          focused_color = "primary";
          occupied_color = "secondary";
          empty_color = "secondary";
        };
        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
          display = "text";
          show_label = true;
          label_min_width = 0;
        };
        ram = {
          type = "sysmon";
          stat = "ram_pct";
          display = "text";
          show_label = true;
          label_min_width = 0;
        };
        network_tx = {
          display = "text";
        };
        network_rx = {
          display = "text";
        };
        active_window = {
          title_scroll = "on_hover";
          display = "icon_and_text";
          max_length = 265;
        };
        media = {
          album_art_only = false;
          hide_when_no_media = true;
          title_scroll = "on_hover";
          max_length = 145;
        };
        notifications = {
          hide_when_no_unread = false;
        };
        battery = {
          display_mode = "glyph";
          show_label = true;
        };
        volume = {
          scroll_step = 1;
          show_label = false;
        };
        brightness = {
          scroll_step = 3;
          show_label = false;
        };
        tray = {
          drawer = true;
          drawer_columns = 5;
          drawer_item_size = 22.0;
          match_adjacent_spacing = true;
        };
        "control-center" = {
          glyph = "noctalia";
        };
      };

      # ── Dock ───────────────────────────────────────────────
      # Port of v4 dock: floating, bottom, auto-hide, no grouping
      dock = {
        enabled = true;
        position = "bottom";
        auto_hide = true;
        reserve_space = false;
        dock_type = "floating";
        background_opacity = 0.5;
        radius = 16;
        margin_ends = 0;
        margin_edge = 0;
        icon_size = 48;
        pinned = [ ];
        show_running = true;
        show_instance_count = true;
        show_dots = false;
        active_scale = 1.0;
        inactive_scale = 0.85;
        magnification = true;
        magnification_scale = 1.35;
      };

      # ── Launcher ───────────────────────────────────────────
      launcher = {
        show_categories = true;
        show_icons = true;
        pinned_apps = [ ];
        position = "center";
        sort_by_usage = true;
      };

      # ── Control Center ─────────────────────────────────────
      control_center = {
        width = 820;
        disk_path = "/persistent";
        shortcuts = {
          left = [
            "wifi"
            "bluetooth"
            "wallpaper"
          ];
          right = [
            "notifications"
            "power_profile"
            "caffeine"
            "night_light"
          ];
        };
      };

      # ── Session Menu ───────────────────────────────────────
      # Port of v4 sessionMenu: grid layout with power options
      shell.session = {
        actions = [
          {
            action = "lock";
            shortcut = "1";
          }
          {
            action = "suspend";
            shortcut = "2";
          }
          {
            action = "hibernate";
            shortcut = "3";
          }
          {
            action = "reboot";
            shortcut = "4";
          }
          {
            action = "logout";
            shortcut = "5";
          }
          {
            action = "shutdown";
            shortcut = "6";
          }
          {
            action = "reboot_to_uefi";
            shortcut = "7";
          }
        ];
      };

      # ── Lock Screen ────────────────────────────────────────
      # Match v4: no blur, no tint
      lockscreen = {
        enabled = true;
        blurred_desktop = false;
        blur_intensity = 0.0;
        tint_intensity = 0.0;
      };

      lockscreen_widgets = {
        enabled = true;
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
      };

      # ── Desktop Widgets ────────────────────────────────────
      desktop_widgets = {
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
      };

      # ── Wallpaper ──────────────────────────────────────────
      # Port of v4 wallpaper settings
      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        fill_color = "#000000";
        directory = "/home/isning/Pictures/Wallpapers";
        transition = [
          "fade"
          "disc"
          "stripes"
          "wipe"
          "pixelate"
          "honeycomb"
        ];
        transition_duration = 1500;
        edge_smoothness = 0.3;
        transition_on_startup = true;

        automation = {
          enabled = true;
          interval_seconds = 600;
          order = "random";
          recursive = true;
        };

        default = {
          path = "";
        };
      };

      # ── Backdrop ───────────────────────────────────────────
      # v4 overviewBlur: 0.4 → blur_intensity: 0.4
      # v4 overviewTint: 0.6 → tint_intensity: 0.6
      backdrop = {
        enabled = true;
        blur_intensity = 0.4;
        tint_intensity = 0.6;
      };

      # ── Desktop Widgets ────────────────────────────────────
      # v4 had widgets enabled but disabled via noctaliaPerformance.disableDesktopWidgets
      desktop = {
        widgets = {
          enabled = false;
        };
      };

      # ── Notifications ──────────────────────────────────────
      # Port of v4 notification settings
      notification = {
        enable_daemon = true;
        position = "top_right";
        layer = "overlay";
        background_opacity = 1.0;
        offset_x = 20;
        offset_y = 8;

        # v4 excluded apps: discord,firefox,chrome,chromium,edge
        filter = {
          discord = {
            match = "discord";
            show_toast = false;
            save_history = true;
            play_sound = false;
          };
          firefox = {
            match = "firefox";
            show_toast = false;
            save_history = true;
            play_sound = false;
          };
          chrome = {
            match = "chrome";
            show_toast = false;
            save_history = true;
            play_sound = false;
          };
          chromium = {
            match = "chromium";
            show_toast = false;
            save_history = true;
            play_sound = false;
          };
          edge = {
            match = "edge";
            show_toast = false;
            save_history = true;
            play_sound = false;
          };
        };
      };

      # ── OSD ────────────────────────────────────────────────
      # Port of v4 OSD
      osd = {
        position = "top_right";
        auto_hide_ms = 2000;
        background_opacity = 1.0;
        offset_x = 20;
        offset_y = 8;
        kinds = {
          volume = true;
          brightness = true;
          wifi = true;
          bluetooth = true;
          power_profile = true;
          night_light = true;
          dnd = true;
          lock_keys = true;
          keyboard_layout = true;
          caffeine = true;
        };
      };

      # ── Location ───────────────────────────────────────────
      location = {
        name = "Beijing";
        first_day_of_week = 1;
        use_12hour_format = false;
        weather_enabled = true;
        auto_locate = false;
      };

      # ── Night Light ────────────────────────────────────────
      nightlight = {
        enabled = true;
        temperature_day = 6500;
        temperature_night = 4000;
      };

      # ── Services: Audio ────────────────────────────────────
      audio = {
        enable_overdrive = false;
        enable_sounds = false;
        sound_volume = 0.5;
      };

      # ── Services: Brightness ───────────────────────────────
      brightness = {
        enable_ddcutil = true;
        minimum_brightness = 0.0;
      };

      # ── Services: Battery ──────────────────────────────────
      battery = {
        show_power_profiles = true;
      };

      # ── Services: Idle ─────────────────────────────────────
      # v4 idle was disabled (using external hypridle)
      idle = {
        pre_action_fade_seconds = 2.0;
      };

      # ── Services: System Monitor ───────────────────────────
      # Port of v4 systemMonitor thresholds
      system = {
        monitor = {
          enabled = true;
          cpu_poll_seconds = 2.0;
          gpu_poll_seconds = 5;
          memory_poll_seconds = 2.0;
          network_poll_seconds = 3.0;
          disk_poll_seconds = 10.0;

          cpu_usage_activity_threshold = 50;
          cpu_usage_critical_threshold = 95;
          cpu_temp_activity_threshold = 60;
          cpu_temp_critical_threshold = 90;
          ram_pct_activity_threshold = 60;
          ram_pct_critical_threshold = 90;
          disk_pct_activity_threshold = 80;
          disk_pct_critical_threshold = 90;
        };
      };

      # ── Hooks ──────────────────────────────────────────────
      # Port of v4 dark mode hook for Kvantum theme switching
      hooks = {
        theme_mode_changed = ''sh -c 'if [ "$NOCTALIA_THEME_MODE" = "dark" ]; then s="kvantum-dark"; else s="kvantum"; fi; sed -i "/^\[Appearance\]/,/^\[/ s/^style=.*/style=$s/" /home/isning/.config/qt6ct/qt6ct.conf' '';
      };

      # ── Templates (App Theming) ────────────────────────────
      # Port of v4 templates: qt, niri, gtk, steam
      templates = {
        active = [
          "qt"
          "niri"
          "gtk"
          "steam"
        ];
        user_theming = false;
      };

      # ── Plugins ────────────────────────────────────────────
      plugin = {
        auto_update = false;
        notify_updates = true;
      };

      # ── Calendar ───────────────────────────────────────────
      calendar = {
        show_events = true;
        show_weather = true;
        show_week_numbers = false;
      };

      # ── Network ────────────────────────────────────────────
      network = {
        bluetooth_auto_connect = true;
        wifi_panel_view = "wifi";
      };
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    platformTheme.package = nur-isning.packages.${pkgs.stdenv.hostPlatform.system}.qt6ct;

    style.package = pkgs.kdePackages.qtstyleplugin-kvantum;

    kvantum = {
      enable = true;
      themes = [ nur-isning.packages.${pkgs.stdenv.hostPlatform.system}.kvlibadwaita-kvantum ];
      settings.General.theme = "KvLibadwaita";
    };
  };

  gtk = {
    enable = true;
    font = {
      name = "LXGW WenKai Screen";
      package = pkgs.lxgw-wenkai-screen;
    };

    gtk3.theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };
    gtk4.theme = null;
  };
}
