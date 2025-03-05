{...}: let
  safePath = "/persist";
  deviceMain = "/dev/nvme0n1";
  deviceData = "/dev/nvme1n1";
in {
  disko.devices = {
    disk = {
      main = {
        device = deviceMain;
        imageName = "nixos-disko-root-zfs";
        imageSize = "32G";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              label = "BOOT";
              size = "1M";
              type = "EF02"; # for GRUB MBR
            };
            esp = {
              label = "EFI";
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            swap = {
              size = "64G";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true;
              };
            };
            root = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
      data = {
        device = deviceData;
        imageName = "nixos-disko-data-zfs";
        imageSize = "32G";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        mode = "mirror";
        mountpoint = "/";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          acltype = "posixacl";
          canmount = "off";
          dnodesize = "auto";
          normalization = "formD";
          relatime = "on";
          xattr = "sa";
          compression = "zstd";
        };
        datasets = {
          local = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "local/root" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/";
            postCreateHook = ''
              zfs list -t snapshot -H -o name | grep -E '^rpool/local/root@blank$' \
              || zfs snapshot rpool/local/root@blank
            '';
          };
          "local/nix" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
          };
          safe = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "safe/home" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/home";
          };
          "safe/persist" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "${safePath}";
          };
        };
      };
    };
  };
}
