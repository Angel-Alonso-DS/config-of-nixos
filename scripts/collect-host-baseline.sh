#!/usr/bin/env bash
# Solo lectura. No usa sudo ni cambia la configuración del sistema.
set -u
set -o pipefail

repo_root="${1:-$PWD}"

heading() { printf '\n== %s ==\n' "$1"; }
report_cmd() {
  local label="$1"
  shift
  printf '%s: ' "$label"
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '(comando no disponible: %s)\n' "$1"
    return 0
  fi
  "$@" 2>&1 || printf '(no se pudo consultar)\n'
}

heading 'Identificación'
report_cmd hostname hostname
report_cmd nixos-version nixos-version
report_cmd kernel uname -r
report_cmd current-system readlink -f /run/current-system

heading 'Git local (ningún push, pull o modificación)'
if command -v git >/dev/null 2>&1 && git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'checkout: %s\n' "$repo_root"
  git_sha="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null || true)"
  printf 'HEAD: %s\n' "${git_sha:-sin commits}"
  git -C "$repo_root" branch --show-current || true
  git -C "$repo_root" status --short || true
else
  printf 'No se encontró un checkout Git en: %s\n' "$repo_root"
fi

heading 'Arranque (sin cambiar entradas EFI)'
if [[ -d /sys/firmware/efi ]]; then
  printf 'UEFI: sí\n'
else
  printf 'UEFI: no detectado\n'
fi
if command -v findmnt >/dev/null 2>&1; then
  printf 'Filesystem /boot: '
  findmnt --noheadings --output FSTYPE --target /boot || true
fi
report_cmd bootctl-status bootctl status
report_cmd efi-boot-entries efibootmgr -v
printf 'Nota: estas consultas aportan evidencia, pero la selección del cargador debe confirmarse manualmente durante el arranque.\n'

heading 'Generaciones NixOS'
report_cmd generations nixos-rebuild list-generations

heading 'Unidades fallidas (solo consulta)'
report_cmd system-failed systemctl --failed --no-pager --plain
if command -v systemctl >/dev/null 2>&1; then
  printf '\nServicios de usuario fallidos:\n'
  systemctl --user --failed --no-pager --plain 2>&1 || printf '(bus de usuario no disponible)\n'
fi

heading 'Servicios seleccionados (estado de habilitación)'
if command -v systemctl >/dev/null 2>&1; then
  for unit in NetworkManager.service sshd.service display-manager.service docker.service mysql.service postgresql.service ollama.service libvirtd.service; do
    status="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    printf '%-28s %s\n' "$unit" "${status:-desconocido/no instalado}"
  done
fi

heading 'Herramientas development (presencia, no versiones de proyecto)'
for cmd in git git-lfs nix direnv nix-direnv python3 uv node pnpm java javac mvn gradle php composer gcc pkg-config docker podman psql mariadb mongosh adb scrcpy code nvim; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%-14s presente\n' "$cmd"
  else
    printf '%-14s no encontrado en PATH\n' "$cmd"
  fi
done

heading 'Final'
printf 'Este informe contiene solo consultas. Revisar rutas o nombres privados antes de compartirlo.\n'
