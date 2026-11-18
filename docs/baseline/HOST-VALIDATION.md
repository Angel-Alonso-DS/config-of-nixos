# Recolección de baseline físico — Laptop y desktop

**Estado:** identidad del sistema, generaciones actuales, revisión, commit, cargador, servicios seleccionados y sesión Hyprland confirmados físicamente para ambos equipos. Plasma, bloqueo efectivo, conectividad completa y recuperación con reinicio siguen pendientes. Este documento no contiene resultados inventados.

## Ejecución de solo lectura

Desde la raíz de una copia local del repositorio, ejecutar:

```bash
bash -n scripts/collect-host-baseline.sh
bash scripts/collect-host-baseline.sh .
```

El script no usa `sudo`, no modifica archivos ni servicios, no ejecuta `nixos-rebuild switch`, no descarga paquetes y escribe únicamente a stdout. Consulta `bootctl` y `efibootmgr` cuando están disponibles; esa evidencia no sustituye la confirmación manual del cargador seleccionado durante el arranque. Si hay un comando ausente, lo señala y continúa. La recolección se puede repetir con la otra máquina.

**Privacidad:** antes de compartir la salida, revisar y ocultar nombres de proyectos privados o rutas personales que aparezcan en `git status`. No adjuntar claves, contraseñas, tokens ni contenidos de archivos de secretos. Las salidas no se suben automáticamente al repositorio.

Para que los estados de `systemctl`, la sesión gráfica y EFI sean representativos, ejecutar la recolección desde la sesión local normal de **cada equipo físico**, no desde un contenedor ni mediante acceso remoto. Sustituir la ruta y repetir exactamente:

```bash
cd <ruta-al-repositorio>
bash -n scripts/collect-host-baseline.sh
bash scripts/collect-host-baseline.sh .
```

No usar `sudo` para compensar secciones de `bootctl` que pidan privilegios: anotar esa limitación junto con la salida. Compartir únicamente la salida saneada para completar esta tabla.

## Plantilla por equipo

| Dato | `nixos-alons` | `nixos-desktop` |
| --- | --- | --- |
| Hostname real | `nixos-alons` (informado) | `nixos-desktop` (informado) |
| NixOS y kernel activos | NixOS 26.05; kernel `6.18.57`; revisión `f3a73bc` | NixOS 26.05; kernel `6.18.43`; revisión `ee48b14` |
| Generación actual y generaciones anteriores | Generación actual 163; historial no reproducido aquí | Generación actual 117; historial no reproducido aquí |
| SHA local / estado Git | `HEAD` `899b9fa`; el detalle de rama/estado no se reproduce aquí | `HEAD` `899b9fa`; el detalle de rama/estado no se reproduce aquí |
| Modo UEFI | Entrada UEFI de NixOS observada | `systemd-boot` activo en ESP; no se reproduce aquí el detalle de modo |
| Tipo filesystem de `/boot` | `vfat`, montado desde `/dev/nvme0n1p5` | `vfat`, montado desde `/dev/nvme0n1p1` |
| Bootloader efectivo | Entrada UEFI de NixOS hacia `EFI/nixos/grubx64.efi`; falta observar un arranque de GRUB | `systemd-boot 260.2` activo confirmado |
| Servicios fallidos | Cero unidades fallidas durante la consulta | Cero unidades fallidas durante la consulta |
| Servicios activos elegidos | NetworkManager, `sshd`, Docker, MySQL, PostgreSQL, Ollama, `libvirtd` y display manager activos | NetworkManager, `sshd`, Docker, MySQL, `libvirtd` y display manager activos; PostgreSQL y Ollama inactivos |
| CLI del stack de desarrollo presentes | `podman` y `nvim` presentes; `nix-direnv` no apareció en `PATH`; `direnv` funciona | `podman` y `nvim` no aparecieron en `PATH`; `nix-direnv` tampoco; `direnv` funciona |
| Hyprland / Waybar funcional | Sesión Hyprland sobre Wayland; Waybar, SwayNC e Hypridle activos; Rofi e Hyprlock presentes | Sesión Hyprland sobre Wayland; Waybar, SwayNC e Hypridle activos; Rofi e Hyprlock presentes |
| Plasma funcional | Pendiente | Pendiente |
| Monitores observados | `eDP-1`, 1920×1080 a 144 Hz | `HDMI-A-1`, 1920×1080 a 120 Hz, posición 900×172; `DP-1`, 1600×900 a 60 Hz, posición 0×0, transform 3 |
| Método de recuperación probado | Estrategia documentada; no probada porque requiere reinicio autorizado | Estrategia documentada; no probada porque requiere reinicio autorizado |

## Evidencia de arranque recibida

### Hechos comprobados

| Equipo | Evidencia |
| --- | --- |
| `nixos-alons` | La entrada UEFI de NixOS apunta a `EFI/nixos/grubx64.efi`. `systemd-boot` no está instalado en la ESP. Existe además una entrada UEFI de Windows Boot Manager. `/boot` está en `/dev/nvme0n1p5` con `vfat`. |
| `nixos-desktop` | El cargador activo confirmado es `systemd-boot 260.2`. La entrada actual observada es `nixos-generation-117.conf`. `/boot` está en `/dev/nvme0n1p1` con `vfat`. Algunas secciones de `bootctl` requieren privilegios de administrador. |
| Ambos | `efibootmgr` no está instalado; su ausencia limita el inventario de entradas EFI desde esa herramienta, pero no invalida las comprobaciones anteriores. |

### Inferencias y límites

- La evidencia de laptop es coherente con la configuración versionada que habilita GRUB, pero una ruta en una entrada UEFI no prueba por sí sola que se haya completado un arranque correcto ni que el menú conserve todas las generaciones.
- El estado físico del desktop confirma la premisa de migración: seguirá con `systemd-boot` durante los PR 00–05. Su migración a GRUB continúa reservada para PR 06, independiente y supervisado.
- Los dispositivos, puntos de montaje y números de generación son datos de observación; no autorizan cambios de EFI, bootloader ni activación de una configuración.

## Matriz física confirmada

Los datos siguientes proceden de los registros completos reunidos en ambos equipos físicos. Las generaciones 163 y 117 son referencias operativas actuales; no demuestran por sí mismas que se haya probado un rollback.

| Área | `nixos-alons` | `nixos-desktop` |
| --- | --- | --- |
| NixOS / kernel / revisión | 26.05 / `6.18.57` / `f3a73bc` | 26.05 / `6.18.43` / `ee48b14` |
| Generación operativa actual | 163 | 117 |
| Checkout | `899b9fa` | `899b9fa` |
| Unidades fallidas | 0 | 0 |
| Servicios activos | NetworkManager, `sshd`, Docker, MySQL, PostgreSQL, Ollama, `libvirtd` y display manager | NetworkManager, `sshd`, Docker, MySQL, `libvirtd` y display manager; PostgreSQL y Ollama inactivos |
| Herramientas diferenciadas | `podman` y `nvim` disponibles en `PATH` | `podman` y `nvim` no aparecen en `PATH` |
| `direnv` / `nix-direnv` | `direnv` funciona; `nix-direnv` no aparece en `PATH`; no había `.envrc` cargado en el directorio consultado | `direnv` funciona; `nix-direnv` no aparece en `PATH`; no había `.envrc` cargado en el directorio consultado |
| Sesión gráfica | Hyprland sobre Wayland; Waybar, SwayNC e Hypridle activos; Rofi e Hyprlock presentes | Hyprland sobre Wayland; Waybar, SwayNC e Hypridle activos; Rofi e Hyprlock presentes |
| Monitores | `eDP-1`, 1920×1080 a 144 Hz | `HDMI-A-1`, 1920×1080 a 120 Hz en 900×172; `DP-1`, 1600×900 a 60 Hz en 0×0, transform 3 |

Que `nix-direnv`, `podman` o `nvim` no aparezcan en un `PATH` concreto no prueba una instalación defectuosa ni justifica un cambio de paquetes. Que `direnv` funcione sin un `.envrc` cargado tampoco valida aún ningún entorno de proyecto. Las diferencias de desarrollo quedan como insumo para PR 03, sin cambios funcionales en este PR.

## Contraste con la configuración Nix versionada

| Área | Declarado para laptop | Declarado para desktop | Estado físico conocido |
| --- | --- | --- | --- |
| Cargador | GRUB en `laptop/common.nix` | `systemd-boot` en `desktop/common.nix` | Coherente con la evidencia de arranque recibida; desktop usa `systemd-boot 260.2` y laptop tiene una entrada hacia `grubx64.efi` |
| Servicios | OpenSSH, Ollama, PostgreSQL, MySQL/MariaDB, impresión y Docker | OpenSSH, MySQL/MariaDB, Docker, impresión, Avahi y PipeWire | Coherente en lo esencial: PostgreSQL y Ollama activos en laptop e inactivos en desktop; los servicios compartidos indicados están activos en ambos |
| Escritorios | Hyprland y Plasma 6 habilitados | Hyprland y Plasma 6 habilitados | Sesiones Hyprland/Wayland observadas con Waybar, SwayNC e Hypridle activos; Plasma no se probó |

Las columnas «Declarado» describen módulos versionados, no procesos activos. En particular, no concluir que un servicio funciona, que un puerto está abierto o que una sesión gráfica es usable hasta disponer de la comprobación física correspondiente.

## Comprobaciones manuales adicionales

1. Confirmar en la **laptop** si el menú GRUB arranca la generación actual y permite seleccionar generaciones anteriores; no cambiar opciones ni entradas. La entrada UEFI ya identificada hacia `grubx64.efi` no sustituye esta prueba.
2. Registrar en el **desktop** una forma de recuperación independiente y las generaciones disponibles antes de preparar la futura migración a GRUB. El cargador activo ya está confirmado como `systemd-boot 260.2`.
3. Los monitores y su geometría quedaron registrados en la matriz física; confirmar de nuevo solo si cambian los perfiles de monitor.
4. Los estados de bases de datos, Docker y servicios seleccionados quedaron registrados. No abrir puertos ni modificar permisos.
5. Las sesiones Hyprland, Waybar, SwayNC, Hypridle, Rofi e Hyprlock quedaron observadas. Siguen sin prueba una sesión Plasma y el bloqueo efectivo de pantalla.
6. Revisar cambios locales no versionados: proteger datos importantes; no copiar archivos de secretos a Git.

## Pendientes explícitos para evidencia posterior

- Probar una sesión KDE Plasma y el bloqueo efectivo de pantalla; la presencia de `hyprlock` no prueba que el bloqueo funcione.
- Verificar conectividad completa cuando corresponda: NetworkManager activo no prueba acceso a red, DNS ni rutas.
- Probar una recuperación o rollback solo con autorización de reinicio. Hasta entonces, las generaciones 163 y 117 son referencias operativas, no recuperaciones demostradas.
- Validar las configuraciones multi-host propuestas solo a partir de PR 01; este baseline no evalúa ni activa esa arquitectura.

## Estrategia de recuperación — documentada, no ejecutada

1. Antes de cualquier cambio futuro, conservar el SHA del checkout, la generación actualmente funcional y las generaciones anteriores que muestre cada equipo.
2. Si una activación futura impide iniciar sesión, en el siguiente reinicio seleccionar desde el cargador existente una generación NixOS previamente confirmada como funcional: GRUB en laptop tras comprobar su menú, y `systemd-boot` en desktop mientras no llegue PR 06. No modificar entradas EFI desde el menú.
3. Si el cargador no ofrece una generación funcional o la ESP no es accesible, detener la intervención y usar un medio de recuperación NixOS preparado con supervisión humana. No formatear ni reconfigurar la ESP durante la recuperación inicial.
4. La selección de entradas de arranque, el arranque de una generación anterior y cualquier verificación de Windows o recuperación requieren reiniciar. Permanecen pendientes de autorización y no forman parte de esta recolección.

## Interpretación del resultado

El baseline físico se puede aprobar solo si se conoce cómo volver a una generación estable en cada host y si se han documentado las discrepancias entre configuración versionada y activa. **No sustituye las builds del PR 01 ni las pruebas posteriores de GRUB.**
