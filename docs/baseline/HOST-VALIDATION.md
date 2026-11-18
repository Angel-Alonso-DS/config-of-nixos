# Recolección de baseline físico — Laptop y desktop

**Estado:** pendiente de ejecutar en ambos equipos. Este documento no contiene resultados inventados.

## Ejecución de solo lectura

Desde la raíz de una copia local del repositorio, ejecutar:

```bash
bash -n scripts/collect-host-baseline.sh
bash scripts/collect-host-baseline.sh .
```

El script no usa `sudo`, no modifica archivos ni servicios, no ejecuta `nixos-rebuild switch`, no descarga paquetes y escribe únicamente a stdout. Consulta `bootctl` y `efibootmgr` cuando están disponibles; esa evidencia no sustituye la confirmación manual del cargador seleccionado durante el arranque. Si hay un comando ausente, lo señala y continúa. La recolección se puede repetir con la otra máquina.

**Privacidad:** antes de compartir la salida, revisar y ocultar nombres de proyectos privados o rutas personales que aparezcan en `git status`. No adjuntar claves, contraseñas, tokens ni contenidos de archivos de secretos. Las salidas no se suben automáticamente al repositorio.

## Plantilla por equipo

| Dato | `nixos-alons` | `nixos-desktop` |
| --- | --- | --- |
| Hostname real | Pendiente | Pendiente |
| NixOS y kernel activos | Pendiente | Pendiente |
| Generación actual y generaciones anteriores | Pendiente | Pendiente |
| SHA local / estado Git | Pendiente | Pendiente |
| Modo UEFI | Pendiente | Pendiente |
| Tipo filesystem de `/boot` | Pendiente | Pendiente |
| Bootloader efectivo | Pendiente | Pendiente |
| Servicios fallidos | Pendiente | Pendiente |
| Servicios activos elegidos | Pendiente | Pendiente |
| CLI del stack de desarrollo presentes | Pendiente | Pendiente |
| Hyprland / Waybar funcional | Pendiente | Pendiente |
| Plasma funcional | Pendiente | Pendiente |
| Método de recuperación probado | Pendiente | Pendiente |

## Comprobaciones manuales adicionales

1. Confirmar en la **laptop** si el menú GRUB arranca la generación actual y permite seleccionar generaciones anteriores; no cambiar opciones ni entradas.
2. Confirmar en el **desktop** qué cargador inicia realmente la sesión y si existe una forma de recuperación independiente antes de preparar la futura migración a GRUB.
3. Confirmar que los monitores y su geometría corresponden a la configuración activa en el escritorio.
4. Comprobar que las unidades de bases de datos y Docker que aparecen activas en Git corresponden a las del sistema real. No abrir puertos ni modificar permisos.
5. Comprobar sesiones Hyprland y KDE Plasma en ambos hosts, incluyendo Waybar, Rofi, notificaciones y bloqueo de pantalla, sin alterar configuración.
6. Revisar cambios locales no versionados: proteger datos importantes; no copiar archivos de secretos a Git.

## Interpretación del resultado

El baseline físico se puede aprobar solo si se conoce cómo volver a una generación estable en cada host y si se han documentado las discrepancias entre configuración versionada y activa. **No sustituye las builds del PR 01 ni las pruebas posteriores de GRUB.**
