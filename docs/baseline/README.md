# PR 00 — Baseline del repositorio NixOS multi-host

**Estado:** inventario de Git verificado; identidad, generación actual, revisión, commit, bootloader, servicios seleccionados y sesión Hyprland registrados físicamente para ambos equipos. Plasma, bloqueo de pantalla, conectividad completa, rollback y la futura arquitectura multi-host siguen pendientes.
**Fuente:** `Angel-Alonso-DS/config-of-nixos`, referencia `origin/main`, commit `64d6727ddf5ac85b27d68c87139470dcb2d69bb6`.
**Alcance:** documentación y recolección de evidencia de solo lectura. Ningún cambio funcional en NixOS, Home Manager, bootloader, servicios o firewall.

> IMPORTANTE: Las afirmaciones de este documento describen el código versionado en Git en el commit indicado; **no** prueban qué generación está activa en cada equipo.

## 1. Inventario del árbol

El árbol recursivo del commit de fuente contiene **100 archivos rastreados**:

| Grupo | Archivos |
| --- | ---: |
| `laptop/` | 41 |
| `desktop/` | 42 |
| Otros (wallpapers y `.gitignore`) | 17 |

Al comparar rutas relativas `laptop/` ↔ `desktop/` utilizando SHA de los blobs Git:

| Clasificación | Pares o archivos |
| --- | ---: |
| Pares idénticos | 25 pares |
| Pares con contenido diferente | 14 pares |
| Exclusivos de laptop | 2 archivos |
| Exclusivos de desktop | 3 archivos |

**Los 25 pares idénticos** son:

- `jetbrains.nix`
- `plasma.nix`
- `virtual-machine.nix`
- `modules/home/hyprland/hyprlock.conf`
- `modules/home/kitty.nix`
- `modules/home/kitty/current-theme.conf`
- `modules/home/kitty/kitty.conf`
- `modules/home/notifications.nix`
- `modules/home/notifications/style.css`
- `modules/home/rofi.nix`
- `modules/home/rofi/shared/colors.rasi`
- `modules/home/rofi/shared/fonts.rasi`
- `modules/home/rofi/theme-mod.rasi`
- `modules/home/rofi/theme.rasi`
- `modules/home/wallpaper.nix`
- `modules/home/wallpaper/wallpaper.lua`
- `modules/home/waybar/scripts/audio-output-menu.lua`
- `modules/home/waybar/scripts/bluetooth-menu.lua`
- `modules/home/waybar/scripts/hotspot-menu.lua`
- `modules/home/waybar/scripts/monitor-menu.lua`
- `modules/home/waybar/scripts/network-menu.lua`
- `modules/home/waybar/scripts/power-menu.lua`
- `modules/home/waybar/scripts/screenshot-menu.lua`
- `modules/home/waybar/scripts/system-info-menu.lua`
- `modules/home/waybar/scripts/usb-menu.lua`

**Los 14 pares diferentes** son:

- `common.nix`
- `configuration.nix`
- `flake.nix`
- `gaming.nix`
- `hardware-configuration.nix`
- `home.nix`
- `hyprland.nix`
- `modules/home/hyprland-loader.nix`
- `modules/home/hyprland/hypridle.conf`
- `modules/home/hyprland/hyprland.lua`
- `modules/home/waybar.nix`
- `modules/home/waybar/scripts/menu-common.lua`
- `modules/home/waybar/scripts/power-profile-menu.lua`
- `modules/home/waybar/style.css`

**Solo laptop:** `flake.lock`, `hotspost.nix`.
**Solo desktop:** `modules/home/waybar/scripts/bluetooth-status.lua`, `niri.nix`, `roblox-dev.nix`.

Una coincidencia de SHA significa igualdad exacta del contenido versionado, **no** garantía de comportamiento igual entre hosts.

## 2. Estructura actual y diferencias funcionales

| Área | `nixos-alons` (laptop) | `nixos-desktop` |
| --- | --- | --- |
| Flake | `laptop/flake.nix` | `desktop/flake.nix` |
| Flake lock rastreado | `laptop/flake.lock` | No existe `desktop/flake.lock` en este commit |
| Home Manager | Integrado en Flake | Integrado en Flake |
| Bootloader según código | GRUB con UEFI | systemd-boot con EFI |
| Hardware específico | AMD + NVIDIA, pantalla interna | Intel UHD, dos monitores |
| Estado de escritorios | Hyprland y KDE Plasma importados | Hyprland y KDE Plasma importados |
| Dependencias Flake exclusivas | — | `nix-snapd`, `bedrock-on-linux`, `split-monitor-workspaces` |
| Desarrollo adicional | `gh-s`, GitHub CLI, Ollama, servicios de BD | Antigravity, Vinegar, Roblox Studio, snapd |
| Almacenamiento adicional | — | Dos montajes adicionales en `configuration.nix` |

En `laptop/common.nix` hay herramientas de desarrollo, utilidades generales, servicios y opciones NVIDIA mezcladas. `desktop/common.nix` también mezcla estas responsabilidades y posee diferencias de paquetes, servicios y opciones de escritorio. Estas diferencias deberán conservarse al crear módulos comunes.

El diseño visual de Rofi/Kitty y numerosos scripts son compartibles, pero Waybar y Hyprland **no** pueden reemplazarse literalmente entre equipos: cambian la configuración de monitores, sensores de temperatura, workspaces y plugins. `menu-common.lua` difiere y la versión de laptop incluye soporte para `opts.theme_str`; debe reconciliarse con pruebas de los menús.

## 3. Riesgos conocidos, diferidos o sujetos a validación

1. **Arranque:** no migrar GRUB ni editar la partición EFI durante este PR. El desktop usa físicamente `systemd-boot 260.2` según la evidencia registrada; la laptop tiene una entrada UEFI de NixOS hacia `EFI/nixos/grubx64.efi`, además de Windows Boot Manager. La evidencia, sus límites y los pasos aún pendientes están en [HOST-VALIDATION.md](./HOST-VALIDATION.md). GRUB se migrará en el desktop únicamente en una fase independiente y supervisada (PR 06).
2. **Servicios de bases de datos:** se observaron reglas específicas para MariaDB y autenticación local PostgreSQL `trust` en laptop. Registrar como deuda de seguridad, sin cambiarlas durante la refactorización arquitectónica.
3. **GPU y multimedia:** OBS del desktop declara `cudaSupport = true` aunque su GPU indicada es Intel; comprobar antes de modularizar.
4. **Duplicaciones:** se observan paquetes/opciones repetidos entre Home Manager y NixOS (por ejemplo, Kitty y partes de la configuración JetBrains/direnv).
5. **Gestor de paquetes:** el desktop define `gradle_9`, la laptop `gradle`; no consolidar versiones sin comparar dependencias de proyectos.
6. **Waybar/MPRIS:** conservar la ruta de diagnóstico del fallo SIGSEGV conocido; no modificar este módulo durante baseline.
7. **Estado Git:** las referencias `origin/laptop`, `origin/desktop` y `origin/tests` son ancestros de `origin/main` en la comparación realizada; no fusionarlas automáticamente.
8. **Reproducibilidad:** no existe Flake raíz; unificar el lock es trabajo de PR 01, no de PR 00. Aunque ambos hosts siguen NixOS 26.05, sus revisiones Nixpkgs observadas difieren (`f3a73bc` en laptop y `ee48b14` en desktop). PR 01 debe evaluar compatibilidad y reconciliar el input/lock común antes de adoptar una sola revisión.
9. **Datos persistentes y secretos:** no incorporarlos a Git ni recopilar contraseñas, claves, tokens o información privada en reportes.

## 4. Política arquitectónica aprobada

Consultar [DECISIONS.md](./DECISIONS.md). Resumen: laptop como referencia de development, base compartida y perfiles por host, `devShell`/`direnv`, servicios independientes, Home Manager compartido con overlays, gaming/office/multimedia opcionales, Hyprland + KDE Plasma en ambos, GRUB objetivo, CI y aprobación manual, despliegue local por `systemd`, `boot` predeterminado para cambios de sistema y reinicio siempre manual.

## 5. Qué falta para completar realmente el baseline

La auditoría Git no puede determinar el estado activo de las dos máquinas. Deben recabarse **en laptop y desktop**, sin modificar nada:

- Hostname, versión NixOS y generación actual. Están registrados para ambos hosts en [HOST-VALIDATION.md](./HOST-VALIDATION.md); falta incorporar el detalle de las generaciones anteriores si fuese necesario para una recuperación posterior.
- SHA/branch/status del checkout local (si existe) y discrepancias con `main`. Ambos checkouts reportaron `899b9fa`; el detalle de rama/estado se conserva en los registros locales, no en esta documentación saneada.
- Modo de arranque EFI, filesystem de `/boot`, bootloader efectivamente usado y posibilidad de recuperación. La evidencia de bootloader y `/boot` ya recibida está registrada; faltan las comprobaciones de arranque y recuperación indicadas allí.
- Estado de servicios fallidos, herramientas de desarrollo presentes y servicios seleccionados habilitados. Están registrados, incluidas las diferencias de PostgreSQL, Ollama, `podman` y `nvim`; `nix-direnv` ausente de `PATH` no implica una instalación defectuosa.
- Evidencia de que Hyprland, Waybar, SwayNC, Hypridle, Rofi e Hyprlock están presentes en sesiones Wayland reales, junto con la geometría de monitores. Plasma y el bloqueo efectivo siguen pendientes; NetworkManager activo no prueba conectividad completa.
- Validación de la arquitectura multi-host propuesta. Está fuera de alcance de PR 00 y no se realizará antes de PR 01.
- Comprobación de contenido no versionado relevante, sin subir secretos.

Usar [HOST-VALIDATION.md](./HOST-VALIDATION.md) y el script `scripts/collect-host-baseline.sh` de solo lectura. Los resultados son evidencia local; no se afirma haberlos recopilado o probado en los equipos.

## 6. Criterios de aceptación de PR 00

- [x] Inventario de archivos Git versionados y clasificación SHA de pares.
- [x] Diferencias estructurales documentadas sin modificar módulos.
- [x] Decisiones de arquitectura y restricciones registradas.
- [x] Guía y script de recolección de datos locales preparados.
- [x] Recolección y revisión de identidad, revisión, generación actual, commit, bootloader y unidades fallidas de ambos hosts.
- [x] Referencias operativas de generación y procedimiento de recuperación documentado por host; prueba de rollback diferida porque requiere reinicio autorizado.
- [x] Estados de servicios seleccionados y sesión Hyprland/Wayland registrados para ambos hosts.
- [ ] Plasma, bloqueo efectivo, conectividad completa y rollback, diferidos por alcance o por requerir reinicio autorizado.
- [ ] Revisión humana del PR de baseline antes de fusionar en `dev`.

No afirmar que PR 00 está finalizado mientras falten las verificaciones físicas.
