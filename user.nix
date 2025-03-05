{config, ...}: let
  user = {
    name = "tmpl";
    hashedPassword = "$y$j9T$ED2wTBe5BM1TISOGYdgS11$AkWjWs4kiI0n3kYdlUiuPC33m0aWXV/PK63U7n4Z823";
    keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINi9Ncchcw9R08/jKb6VrgBBvSs78vW9sKUi3Pj5cTiSAAAAEnNzaDphdXRoZW50aWNhdGlvbg== ssh:key-auth-a"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAID8GSpW+Zz1X0UjmiwZbp7vpiHegkxqlMbToJMabBU17AAAAEnNzaDphdXRoZW50aWNhdGlvbg== ssh:key-auth-b"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDaKUw7XbzrROfMEWUjohK01FzVNZrMBWtuLvDPCz323H6i9+9Q+KqkcVGyVoaUED8v3X/YGQaPqieugJjAOtech64tbeuYi00iFSaV+sJhJ7/bY+tg1QX46GwieKy4myhvTHFnwDTP6FG73MPomVjErbNOHRb8NueNFYEmGD+XJBrjFFFONTI1/EEdT+TNVG8rg75tYowgCGaKUmUE+rpzi2EcuVbBYCaHFcBvSrwCxf3NwtnxTZJ01z378vzYgKV+atbidsujG/WYSANWiH6h0JPbnbtIRnMVoPibGGVZZMXhasWdC4TuGQMLlPzx9it3n6VthOAIJMMQG3ImBg43lYSQcyv07vWtrfU3DT3QC6DvudLPDDsqRz3R9lVn2nRlc5BRVXgJnolJjensK53a3drtAapCLlCW4njDi/AYcHB2xIFzsgr88gO+fODek0v6v6OG7q9L1EpVY4+UbNbQW8zc/SxQNZ3t2zV1v5aCU+q6G0hj3JPQoCDJCNHsDfrtrP46HO9XUOErK9FYd1Ry4ClMmhK/4fewj8BrGSG8cbL8rfFSVqQQx8s7Bera+z+2yHmLgxvC9a5y3MbeWvRB3PP2gEzc5kku0eDyhBX8DZRm5facML/eHGqZcVwMqeyHph+OxplpbyBpW+Y8ehYpyDPHaMLw85EzvhA/tB80SQ== openpgp:0x4C957822"
    ];
  };
  checkGroups = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  users.users.${user.name} = {
    inherit (user) name hashedPassword;
    isNormalUser = true;
    openssh.authorizedKeys.keys = user.keys;
    extraGroups =
      [
        "wheel"
      ]
      ++ (checkGroups [
        "audio"
        "video"
        "docker"
        "podman"
        "libvirt"
        "git"
        "networkmanager"
        # printing and scanning"
        "scanner"
        "lp"
      ]);
  };

  systemd.tmpfiles.rules = let
    u = config.users.users.${user.name}.name;
    g = config.users.users.${user.name}.group;
  in [
    "d /home/${user.name}/.ssh 0750 ${u} ${g} -"
    "d /home/${user.name}/.ssh/sockets 0750 ${u} ${g} -"
  ];

  users.users.root = {
    hashedPassword = config.users.users.${user.name}.hashedPassword;
    openssh.authorizedKeys.keys = config.users.users.${user.name}.openssh.authorizedKeys.keys;
  };
}
