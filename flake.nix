{
  description = "OpenBao OCI image built with Nix dockerTools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      bao = pkgs.openbao;
      dumbInit = pkgs.dumb-init;
      version = "2.7.1";
      fakeNss = pkgs.dockerTools.fakeNss.override {
        extraPasswdLines = [ "openbao:x:10001:10001:OpenBao:/openbao:/noshell" ];
        extraGroupLines = [ "openbao:x:10001:" ];
      };
      entrypoint = pkgs.runCommand "openbao-entrypoint" { } ''
        mkdir -p "$out/bin"
        substitute ${./container/entrypoint.sh} "$out/bin/openbao-entrypoint" \
          --replace-fail @dash@ ${pkgs.dash}/bin/dash
        chmod 0555 "$out/bin/openbao-entrypoint"
      '';
      runtimeCheck = pkgs.runCommand "openbao-runtime-contract" {
        nativeBuildInputs = [ pkgs.gnugrep ];
      } ''
        ${bao}/bin/bao version 2>&1 | grep -F "v${version}"
        test -x ${entrypoint}/bin/openbao-entrypoint
        test -x ${dumbInit}/bin/dumb-init
        grep -F "ulimit -c 0" ${entrypoint}/bin/openbao-entrypoint
        grep -F "openbao:x:10001:10001:" ${fakeNss}/etc/passwd
        grep -F "openbao:x:10001:" ${fakeNss}/etc/group
        touch "$out"
      '';
      image = assert bao.version == version;
        pkgs.dockerTools.buildLayeredImage {
          name = "openbao";
          tag = version;
          contents = [
            bao
            entrypoint
            pkgs.dash
            dumbInit
            fakeNss
            pkgs.cacert
            pkgs.tzdata
          ];

          config = {
            User = "10001:10001";
            WorkingDir = "/openbao";
            Entrypoint = [ "${dumbInit}/bin/dumb-init" "--" "/entrypoint.sh" ];
            Cmd = [ "server" "-config=/openbao/config" ];
            Env = [
              "HOME=/tmp"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "BAO_CONFIG_DIR=/openbao/config"
              "PATH=/usr/bin:${bao}/bin"
              "TZDIR=${pkgs.tzdata}/share/zoneinfo"
            ];
            ExposedPorts = { "8200/tcp" = { }; };
            Volumes = {
              "/openbao/config" = { };
              "/openbao/file" = { };
              "/openbao/logs" = { };
            };
            StopSignal = "SIGTERM";
            Labels = {
              "org.opencontainers.image.title" = "OpenBao";
              "org.opencontainers.image.version" = version;
              "org.opencontainers.image.licenses" = "MPL-2.0";
              "org.opencontainers.image.source" = "https://github.com/openbao/openbao";
              "org.opencontainers.image.description" = "Nix-built OpenBao server image";
            };
          };

          fakeRootCommands = ''
            mkdir -p ./usr/bin ./openbao/config ./openbao/file ./openbao/logs ./tmp
            ln -sfn ${bao}/bin/bao ./usr/bin/bao
            ln -sfn ${entrypoint}/bin/openbao-entrypoint ./entrypoint.sh
            chown -R 10001:10001 ./openbao
            chmod 0750 ./openbao ./openbao/config ./openbao/file ./openbao/logs
            chmod 1777 ./tmp
          '';
        };
    in {
      packages.${system} = {
        inherit image;
        default = image;
      };
      checks.${system} = {
        inherit image;
        runtime-contract = runtimeCheck;
      };
    };
}
