# Shared development package groups. Host modules splice these groups into
# their existing systemPackages lists to preserve each host's package order.
{ pkgs }:
with pkgs;
{
  core = [
    uv
    gcc
    pkg-config
    git
    git-lfs
  ];

  node = [
    nodejs_22
    pnpm
  ];

  java = [
    jdk25
    maven
  ];

  android = [
    android-studio
    android-tools
  ];

  php = [
    php82
    php82Packages.composer
  ];

  databaseClients = [
    mariadb
    postgresql
    mongosh
    mongodb-tools
  ];

  containers = [ docker ];
  python = [ python3 ];
  editor = [ vscode ];
  debug = [ gdb ];
  mobile = [ scrcpy ];
}
