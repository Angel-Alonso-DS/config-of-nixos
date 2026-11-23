# Procedimiento supervisado de despliegue desde Git

Este procedimiento administra cada host desde `/home/alonso/nixos`, sin modificar `/etc/nixos` ni automatizar el despliegue. Ejecutar las comprobaciones en el equipo correspondiente: `nixos-alons` es la laptop con GRUB UEFI y `nixos-desktop` es el escritorio con GRUB UEFI. Trabajar en un host a la vez, con acceso físico y tiempo para recuperar.

Para agregar, quitar o modificar aplicaciones, módulos, scripts y configuraciones, consultar primero la [guía de cambios](configuration-change-workflow.md).

## Flujo de cambios y autorización

1. Crear una rama de trabajo desde `dev`, preparar los cambios y abrir un PR hacia `dev`. Revisar los cambios y `flake.lock`; una actualización de dependencias requiere su propia revisión.
2. Esperar la CI de GitHub del commit correspondiente y revisar el PR. Integrarlo en `dev` únicamente con la revisión y autorización aplicables.
3. Revisar lo integrado y promoverlo a `main` solo con autorización humana. Verificar que la CI de GitHub haya terminado satisfactoriamente para el **commit exacto de `main`** que se propone instalar, no solo para el commit del PR o de `dev`. Si el commit cambia, repetir la comprobación.
4. En el host, actualizar el checkout de forma supervisada y comprobar que está limpio, en `main` y exactamente en el commit autorizado. Comparar con la referencia remota previamente actualizada y con el commit cuya CI se revisó; una referencia local `origin/main` puede estar desactualizada. No sobrescribir cambios locales para forzar la coincidencia.
5. Realizar la validación local y construir el candidato sin activarlo. Revisar los resultados y completar el checklist de autorización. La activación y cualquier reinicio requieren autorización humana explícita para ese host y candidato.
6. Después de activar y reiniciar de forma autorizada, verificar físicamente el arranque y el funcionamiento. Registrar resultados antes de considerar el otro host.

La [CI de validación](pr07-validation-ci.md) corre en GitHub; no demuestra que el hardware, el arranque o los servicios físicos funcionen. La [consulta manual de candidatos](pr07b-candidate-detection.md) mediante [`scripts/check_nixos_candidate.py`](../scripts/check_nixos_candidate.py) consulta únicamente `main`; no valida `dev`, no activa sistemas y no sustituye la autorización ni las pruebas físicas.

## Actualización supervisada del checkout

En `/home/alonso/nixos`, comprobar primero que `git status --short --branch` muestra un árbol limpio, incluidos los archivos no rastreados. Si hay trabajo local, detenerse y preservarlo; no sobrescribirlo. Obtener la referencia remota y comparar su SHA completo con el commit de `main` autorizado y cuya CI se verificó:

```bash
cd /home/alonso/nixos
git status --short --branch
git fetch origin
git rev-parse origin/main
```

Solo si coinciden y el árbol sigue limpio, cambiar a `main` y avanzar exclusivamente mediante fast-forward:

```bash
git switch main
git merge --ff-only origin/main
git rev-parse HEAD
git status --short --branch
```

Comparar el SHA completo de `HEAD` con el SHA autorizado y confirmar de nuevo el árbol limpio. Si no coincide, si el fast-forward falla o si la referencia remota cambia, detenerse e investigar; no forzar la actualización ni sobrescribir trabajo local. Estos comandos describen una intervención futura supervisada; no se ejecutan durante la preparación del documento.

## Identidad y comprobaciones locales

Desde `/home/alonso/nixos`, registrar estas consultas de lectura y contrastarlas con el host, el commit autorizado y la CI. `git status` debe estar limpio, incluidos archivos no rastreados; revisar también submódulos si existen. `sha256sum` permite comparar el contenido de `flake.lock` entre equipos o con un registro confiable; por sí solo no demuestra que sea el lock autorizado.

```bash
cd /home/alonso/nixos
hostnamectl --static
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git status --short --branch
git diff -- flake.lock
git diff --cached -- flake.lock
sha256sum flake.lock
readlink -f /run/current-system
readlink -f /run/booted-system
readlink -f /nix/var/nix/profiles/system
nix-env --profile /nix/var/nix/profiles/system --list-generations
```

Comparar los tres enlaces: sistema activo, sistema arrancado y perfil pueden diferir. La sección 5 del [runbook de recuperación](pr08-recovery-rollback.md#5-generaciones-y-opción-predeterminada) explica cómo relacionarlos con las generaciones y por qué no prueban la entrada predeterminada.

Para evaluar el resultado, obtener el hostname y confirmar que sea `nixos-alons` o `nixos-desktop` antes de ejecutar la evaluación:

```bash
host=$(hostnamectl --static)
printf '%s\n' "$host"
nix eval --no-update-lock-file --raw ".#nixosConfigurations.${host}.config.system.build.toplevel.outPath"
```

Comparar la ruta resultante con los enlaces anteriores. La igualdad identifica el mismo resultado de sistema; no demuestra por sí sola que todos los servicios funcionen. La evaluación no activa el sistema ni actualiza `flake.lock`, aunque Nix puede escribir cachés o entradas en el almacén y necesitar acceso a fuentes. Una diferencia exige investigar antes de continuar.

## Espacio y construcción sin activación

Antes de construir, comprobar el espacio y los puntos de montaje efectivos; la ESP puede estar en una ruta distinta de `/boot`. Revisar también inodos y disponibilidad en el almacén y la ESP, y dejar margen para la construcción, entradas de arranque y recuperación. No ejecutar GC ni borrar generaciones para resolver una falta de espacio sin un plan separado y autorizado.

```bash
findmnt --target /
findmnt --target /nix
findmnt --target /boot
df -h / /nix /boot
df -i / /nix /boot
```

Si alguna ruta no es un punto de montaje independiente, identificar el sistema de archivos que la contiene y la ESP real; ajustar las consultas a esos puntos. No existe un umbral universal que garantice espacio suficiente: el tamaño del candidato y los recursos disponibles deben revisarse para cada host.

Con el checkout y lock verificados, este comando construye el candidato sin activarlo y sin crear un enlace `result` en el directorio actual. Sustituir `HOST` por el atributo correcto:

```bash
nix build --no-update-lock-file --no-link --print-out-paths .#nixosConfigurations.HOST.config.system.build.toplevel
```

La construcción puede descargar o producir rutas en `/nix/store` y consumir espacio; no cambia el perfil ni la configuración activa. Registrar la ruta y compararla con la evaluación. Sin una raíz de GC creada para ella, la ruta podría eliminarse en una recolección posterior. No ejecutar este comando como parte de la preparación de esta documentación.

## Efectos de las operaciones de nixos-rebuild

Los siguientes nombres describen operaciones distintas; verificar las opciones y efectos de la versión instalada antes de autorizar cualquiera. Toda operación futura de `nixos-rebuild` debe especificar `--flake /home/alonso/nixos#HOST`, sustituyendo `HOST` por el atributo correcto (`nixos-alons` o `nixos-desktop`). No se ejecutan en esta preparación.

| Operación | Efecto previsto |
| --- | --- |
| `nixos-rebuild build` | Construye el sistema y normalmente crea el enlace `result` en el directorio actual; no lo activa ni cambia el perfil de sistema. |
| `nixos-rebuild dry-activate` | Construye si es necesario y solicita una previsualización de la activación, sin activar el candidato ni cambiar el perfil. La información depende de los scripts de activación y no garantiza que la activación real tenga éxito. |
| `nixos-rebuild test` | Construye y activa temporalmente el sistema en ejecución, incluyendo posibles cambios de servicios y estado mutable; no cambia el perfil de sistema ni instala el candidato como configuración de arranque predeterminada. Un reinicio vuelve a la configuración de arranque seleccionada. |
| `nixos-rebuild boot` | Construye, actualiza el perfil de sistema y la configuración del cargador para un arranque futuro; no activa el sistema nuevo en la sesión actual. |
| `nixos-rebuild switch` | Construye, actualiza el perfil y la configuración del cargador y activa el sistema inmediatamente; puede iniciar, detener o reiniciar servicios y modificar estado mutable. |

`test`, `boot` y `switch` requieren autorización explícita según sus efectos; incluso una activación temporal puede afectar sesiones y datos. El cambio del cargador no demuestra qué entrada seleccionará realmente el firmware o el menú.

## Antes de autorizar una activación

- [ ] Identificar host, operador, ventana, operación y ruta del candidato; confirmar acceso físico y alimentación estable.
- [ ] Confirmar commit exacto de `main`, CI satisfactoria de ese commit, revisión aprobada, árbol limpio, `flake.lock` y atributo del host.
- [ ] Comprobar espacio en los sistemas de archivos pertinentes y construcción local satisfactoria; investigar cualquier diferencia con el resultado instalado.
- [ ] Registrar generaciones activa, arrancada y del perfil, entrada predeterminada y generación conocida; verificar el plan del [runbook PR 08](pr08-recovery-rollback.md).
- [ ] Disponer del USB NixOS Minimal probado en UEFI y de credenciales o claves necesarias; confirmar respaldos restaurables de datos personales y servicios. El USB permite rescate, pero no sustituye esos respaldos.
- [ ] Revisar cambios de servicios, sesiones, Home Manager y posibles migraciones de datos; acordar cómo comprobarlos y recuperar.
- [ ] Obtener autorización humana explícita para la operación, el host y el candidato. Autorizar el reinicio por separado.

## Después del reinicio autorizado

- [ ] Comprobar físicamente hostname, menú y arranque predeterminado sin USB; registrar generación arrancada, activa y perfil, y compararlos con el candidato.
- [ ] Verificar sesiones gráficas, incluyendo KDE Plasma, periféricos, red, GPU y servicios utilizados; revisar unidades fallidas y registros según el [checklist del runbook](pr08-recovery-rollback.md#7-checklist-posterior-a-la-activación).
- [ ] Registrar resultados, incidencias y cualquier prueba pendiente. Ante un fallo, seguir el runbook y conservar la generación anterior y los respaldos; no considerar el siguiente host validado por la prueba de este.

## Estado histórico al 18 de noviembre de 2026

Según las pruebas físicas comunicadas, laptop tiene la generación funcional 163 y se probó la recuperación con 162; desktop tiene la generación funcional 117 y se probó la recuperación con 116. En ambos se probó un USB NixOS Minimal en modo UEFI. Ambos checkouts estaban sincronizados con `dev` en `4cfa9daf` y cada evaluación de `system.build.toplevel` coincidía exactamente con su generación actual. Estos datos son una instantánea, no sustituyen las comprobaciones antes de un despliegue posterior.

Quedan pendientes la prueba de KDE Plasma, las verificaciones completas de servicios y la revisión del espacio de desktop. El [estado del runbook](pr08-recovery-rollback.md#12-verificación-y-criterios-de-autorización) conserva los demás puntos que aún requieren comprobación. En esa fecha, la migración a GRUB todavía estaba pendiente.

## Validación física del 22 de noviembre de 2026

La migración de `nixos-desktop` a GRUB UEFI se completó correctamente:

- Instalación de GRUB UEFI sin errores.
- Arranque físico satisfactorio de la generación 121.
- Recuperación mediante la generación 120 desde GRUB.
- Regreso al arranque predeterminado de la generación 121.
- Arranque alternativo mediante `Linux Boot Manager` (systemd-boot).
- USB de recuperación UEFI probado y respaldo ESP verificado.
- Configuración integrada en `main` mediante los PR #10 y #33.

**Nota:** el runbook `docs/pr08-recovery-rollback.md` conserva
referencias históricas a systemd-boot como cargador principal del
escritorio. Requiere actualización antes de utilizarlo como guía vigente
de recuperación de GRUB.
