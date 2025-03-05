{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
lib.mkMerge [
  (let
    safePath = "/persist";
  in {
    boot = {
      kernelPackages = lib.mkForce pkgs.linuxPackages;
      loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 5;
        };
        efi.canTouchEfiVariables = true;
      };

      supportedFilesystems = [
        "btrfs"
        "reiserfs"
        "vfat"
        "f2fs"
        "xfs"
        "ntfs"
        "cifs"
        "zfs"
      ];

      binfmt.emulatedSystems = [
        "x86_64-windows"
        "aarch64-linux"
      ];

      initrd.postDeviceCommands = lib.mkAfter (
        builtins.concatStringsSep "; " (
          lib.map (sn: "zfs rollback -r ${sn}") [
            "rpool/local/root@blank"
          ]
        )
      );
    };

    services.zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
      trim.enable = true;
      trim.interval = "weekly";
    };

    environment.persistence.${safePath} = {
      enable = true;
      hideMounts = true;
      directories = [
        "/var/lib/systemd/coredump"
        "/var/lib/nixos"
        "/etc/NetworkManager/system-connections"
        "/var/lib/bluetooth"
      ];
    };

    # need to set manually here because disko does not have this flag
    fileSystems.${safePath}.neededForBoot = true;
    facter.reportPath = "${inputs.self}/facter.json";
  })
  {
    nix = {
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
      settings = {
        # See https://jackson.dev/post/nix-reasonable-defaults/
        connect-timeout = 5;
        log-lines = 25;
        min-free = 128000000; # 128MB
        max-free = 1000000000; # 1GB

        experimental-features = "nix-command flakes";
        auto-optimise-store = true;
        keep-outputs = true;
        trusted-users = ["@wheel"];
      };
    };

    virtualisation = {
      vmVariantWithBootLoader = {
        virtualisation.forwardPorts = [
          {
            from = "host";
            host.port = 8888;
            guest.port = 80;
          }
        ];
        diskSize = 32768;
        memorySize = 8192;
        cores = 2;
      };

      vmVariant = {
        virtualisation.forwardPorts = [
          {
            from = "host";
            host.port = 8888;
            guest.port = 80;
          }
        ];
        diskSize = 32768;
        memorySize = 8192;
        cores = 2;
      };
    };

    environment.systemPackages = [
      pkgs.curl
      pkgs.git
      pkgs.tree
      pkgs.wget
      pkgs.vim
    ];

    fonts.packages = [
      pkgs.dejavu_fonts
      pkgs.cm_unicode
      pkgs.libertine
      pkgs.roboto
      pkgs.noto-fonts
    ];
  }
  {
    time = {
      timeZone = "Europe/Berlin";
      hardwareClockInLocalTime = true;
    };

    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = let
        extraLocale = "de_DE.UTF-8";
      in {
        LC_ADDRESS = extraLocale;
        LC_IDENTIFICATION = extraLocale;
        LC_MEASUREMENT = extraLocale;
        LC_MONETARY = extraLocale;
        LC_NAME = extraLocale;
        LC_NUMERIC = extraLocale;
        LC_PAPER = extraLocale;
        LC_TELEPHONE = extraLocale;
        LC_TIME = extraLocale;
      };
    };
  }
  {
    networking = {
      hostId = builtins.substring 0 8 (builtins.hashString "md5" config.networking.hostName);
      networkmanager.enable = true;
      firewall.enable = true;
      wireless.enable = false;
      proxy = {
        default = "172.24.2.60:8080";
        noProxy = "127.0.0.0/8, ::1, *.mh-hannover.local, *.mh-hannover.de, 172.17.*, 172.20.*, 172.24.*";
      };
    };
  }
  {
    ## SECURITY
    programs = {
      # Filesystem in Userspace; secure method for non privileged users to
      # create and mount their own filesystem
      fuse.userAllowOther = true;
      gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-curses;
        enableSSHSupport = lib.mkForce true;
        settings = {
          default-cache-ttl = 60;
          max-cache-ttl = 120;
          ttyname = "$GPG_TTY";
        };
      };
      yubikey-touch-detector.enable = true;
      ssh.startAgent = lib.mkForce false;
    };

    environment = let
      init = ''
        export GPG_TTY="$(tty)"
        ${pkgs.gnupg}/bin/gpg-connect-agent /bye
        export SSH_AUTH_SOCK=$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)
        ${pkgs.gnupg}/bin/gpgconf --launch gpg-agent
      '';
    in {
      shellInit = init;
      interactiveShellInit = init;

      systemPackages = [
        pkgs.gnupg
        pkgs.gpgme
        pkgs.libfido2

        pkgs.yubioath-flutter
        pkgs.yubikey-manager
        pkgs.yubikey-personalization
        pkgs.pcsctools
        (pkgs.writeShellScriptBin "reset-gpg-yubikey" ''
          ${pkgs.gnupg}/bin/gpg-connect-agent "scd serialno" "learn --force" /bye
        '')
      ];
    };

    services = {
      pcscd.enable = true;
      udev = {
        enable = true;
        packages = [pkgs.yubikey-personalization];
      };
    };
  }
  {
    ## AUDIO
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
    };
  }
  {
    ## BLUETOOTH
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = lib.mkIf config.services.pipewire.enable {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"];
      };
    };
  }
  {
    ## NVIDIA
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "nvidia-x11"
        "nvidia-settings"
      ];

    hardware.nvidia = {
      open = false;
      modesetting.enable = true;
      nvidiaSettings = true;
    };

    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia-container-toolkit = {
      enable = true;
      mount-nvidia-executables = true;
    };

    hardware.graphics.extraPackages = [
      pkgs.nvidia-vaapi-driver
    ];
  }
  {
    ## PRINTING
    # Required to queue a job
    services.printing = {
      enable = true;
      openFirewall = true;
      drivers = [
        pkgs.gutenprint
      ];
    };
    # Required to send the job over the network
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true; # required for UDP 5353
      publish = {
        enable = true;
        userServices = true;
      };
    };
  }
  {
    ## VIRTUALISATION
    virtualisation = {
      containers.enable = true;
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    environment.systemPackages = [
      pkgs.dive
      pkgs.podman-tui
      pkgs.podman-compose
    ];
  }
  {
    ## DESKTOP
    programs.dconf.enable = true;
    services.xserver = {
      enable = true;
      displayManager.gdm = {
        enable = true;
        wayland = true;
      };
      desktopManager.gnome.enable = true;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    environment.sessionVariables = {
      GIO_EXTRA_MODULES = ["${pkgs.glib-networking}/lib/gio/modules"];
    };

    environment.systemPackages = [
      pkgs.gnomeExtensions.forge
      pkgs.adwaita-icon-theme
      pkgs.gsettings-desktop-schemas
      pkgs.glib-networking
    ];
  }
]
