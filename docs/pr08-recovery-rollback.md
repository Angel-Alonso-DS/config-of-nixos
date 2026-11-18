# PR 08: recuperación y rollback

## 1. Estado y alcance

Esta guía prepara la recuperación de `nixos-alons` (laptop) y `nixos-desktop` (desktop). La configuración multi-host reorganizada aún no se ha activado físicamente. Ningún procedimiento de este documento constituye evidencia de que un menú, generación, copia de seguridad o medio de rescate funcione en los equipos actuales.

La [configuración de laptop](../laptop/common.nix) declara GRUB UEFI; la [de desktop](../desktop/common.nix) declara **systemd-boot UEFI**, que se conserva. Ambos archivos de hardware declaran `/boot`: [laptop](../laptop/hardware-configuration.nix) y [desktop](../desktop/hardware-configuration.nix). El [flake](../flake.nix) fija una revisión de nixpkgs por host. La [validación previa de los hosts](baseline/HOST-VALIDATION.md) recoge observaciones físicas anteriores, no garantiza su estado actual. Los puntos de montaje y dispositivos deben confirmarse en cada equipo.

GRUB limita el menú a cinco configuraciones y systemd-boot a diez. Son límites de entradas en el menú, no una política de conservación de generaciones ni una garantía de que una entrada arranque. No se encontró una política explícita de recolección automática de basura en la configuración auditada; comprobar la configuración efectiva y timers de cada host. No borrar generaciones ni ejecutar GC como parte de esta guía.

## 2. Tres tipos de recuperación

1. **Servicio:** diagnosticar una unidad o sesión aislada. Su recuperación puede requerir reiniciar el servicio y afectar usuarios o datos; primero consultar su estado y registros.
2. **Rollback declarativo:** arrancar o activar una generación anterior. El menú permite probar una entrada anterior en un arranque; eso no garantiza cambiar la predeterminada ni el perfil de sistema.
3. **Bootloader:** si no se puede mostrar el menú o cargar ninguna entrada, investigar firmware, ESP, archivos del cargador y entradas EFI. Repararlo es una operación diferente que puede escribir en la ESP o NVRAM.

El [manual de NixOS sobre rollback](https://nixos.org/manual/nixos/stable/#sec-rollback) describe las generaciones y el arranque de configuraciones anteriores. Su documentación general debe contrastarse con la versión realmente instalada antes de cualquier operación de escritura.

## 3. Laptop: GRUB UEFI

1. Antes de actualizar, registrar el número de una generación conocida como funcional y comprobar físicamente cómo acceder al menú GRUB y arrancarla.
2. Ante un fallo de la generación nueva, mostrar el menú y seleccionar esa entrada anterior, normalmente dentro del submenú de configuraciones NixOS. Los nombres y la disponibilidad deben comprobarse en pantalla.
3. Si arranca, identificar sistema arrancado, activo y perfil como se indica en la sección 5. Realizar las comprobaciones de salud de la sección 7.
4. Inspeccionar la configuración GRUB efectiva, incluida la selección predeterminada y cualquier selección guardada. No inferirla únicamente del perfil Nix.
5. Si se decide hacer persistente la recuperación, validar previamente en el host la documentación y sintaxis de su versión, sus efectos sobre el perfil y la actualización del menú. Tras la acción autorizada, verificar ambos y probar un arranque sin selección manual.

Si no aparece GRUB o no carga ninguna entrada, seguir el plan de rescate; no reinstalarlo por rutina. La configuración `efiInstallAsRemovable` declarada no demuestra qué ejecutable selecciona actualmente el firmware.

## 4. Desktop: systemd-boot UEFI

1. Antes de actualizar, registrar una generación funcional y probar el acceso físico al menú systemd-boot y a esa entrada.
2. Ante un fallo, seleccionarla en el menú y arrancar. Verificar la salud del sistema y los enlaces descritos en la sección 5.
3. Consultar `bootctl status` y `bootctl list`: distinguir la entrada seleccionada en el arranque, la predeterminada y cualquier selección temporal. La selección manual no demuestra por sí sola el valor persistente.
4. Para conservar una recuperación, validar primero el procedimiento de la versión instalada y cómo interactúan el perfil, las entradas y las variables EFI. Solo después de autorización, aplicar el cambio y probar un arranque sin selección manual.

Desktop continúa usando systemd-boot; esta guía no propone migrarlo a GRUB. La [documentación de bootctl](https://www.freedesktop.org/software/systemd/man/257/bootctl.html) describe las entradas y las selecciones permanentes y temporales; el resultado depende de lo que expongan el cargador y el firmware reales.

## 5. Generaciones y opción predeterminada

En el sistema instalado, los siguientes comandos son de lectura:

```bash
readlink -f /run/current-system
readlink -f /run/booted-system
readlink -f /nix/var/nix/profiles/system
nix-env --profile /nix/var/nix/profiles/system --list-generations
ls -l /nix/var/nix/profiles/system-*-link
```

`current-system` identifica la configuración activa; `booted-system`, la utilizada al arrancar; el perfil `system`, la generación seleccionada en el perfil. Comparar los destinos con los enlaces numerados y registrar los resultados. Un mismo destino puede corresponder a más de una generación; las especializaciones pueden complicar la correspondencia. Ninguno de esos enlaces prueba por sí solo qué opción arrancará por defecto.

En desktop, `bootctl status` y `bootctl list` muestran lo que la interfaz del cargador puede informar; revisar también si hay una selección para el siguiente arranque. En laptop, inspeccionar el `grub.cfg` y, si se utiliza, el entorno guardado de GRUB en sus ubicaciones **realmente montadas**. Si no se puede determinar la selección efectiva, anotarla como desconocida y comprobarla físicamente.

## 6. Checklist antes de la primera activación

- [ ] Elegir un host a la vez, con acceso físico, alimentación estable y tiempo para recuperar.
- [ ] Registrar hostname, versión instalada, commit y revisión del flake, sistema activo, arrancado, perfil y entrada predeterminada.
- [ ] Identificar una generación anterior conocida, mostrar el menú y comprobar que arranca; registrar cómo volver a ella.
- [ ] Verificar raíz, `/nix`, ESP y demás montajes mediante UUID y contenido; confirmar espacio libre sin borrar nada.
- [ ] Preparar y probar un USB de rescate NixOS en modo UEFI. Disponer de credenciales y, si aplica, claves de cifrado.
- [ ] Comprobar copias restaurables de datos personales y respaldos consistentes de bases de datos y volúmenes usados.
- [ ] Registrar estado de red, sesiones, GPU y servicios esenciales; revisar cambios de Home Manager y posibles migraciones de datos.
- [ ] Revisar CI del commit y el atributo correcto del flake: `nixos-alons` o `nixos-desktop`. Un build correcto no prueba el arranque físico.
- [ ] Verificar sintaxis y efectos de la activación propuesta para las versiones implicadas, mantener `flake.lock` y obtener la autorización correspondiente.

La primera activación se hará en una ventana supervisada y no forma parte de este PR. No pasar al segundo host hasta validar arranque y recuperación del primero.

## 7. Checklist posterior a la activación

- [ ] Registrar generación activa, arrancada, perfil y opción predeterminada; revisar unidades fallidas y journal.
- [ ] Iniciar sesión por separado en Hyprland y KDE Plasma; probar teclado, puntero, monitores y aplicaciones habituales.
- [ ] Comprobar conexión de red, ruta, DNS y servicios de red requeridos; verificar SSH si se utiliza.
- [ ] Comprobar GPU y aceleración con las herramientas disponibles. En laptop, verificar NVIDIA y, en una prueba supervisada, suspensión y reanudación.
- [ ] Comprobar gestor de pantalla, NetworkManager, audio y servicios esenciales realmente usados; revisar bases de datos, Docker u otros servicios específicos cuando corresponda.
- [ ] Reiniciar en una prueba autorizada, confirmar el arranque predeterminado y repetir las comprobaciones críticas.
- [ ] Conservar la generación anterior y los respaldos hasta terminar la validación. Registrar resultados y discrepancias.

## 8. Diagnóstico de solo lectura

Ejecutar en el host afectado, sin asumir que todos los comandos o unidades estén disponibles. Los journals pueden contener información sensible.

```bash
hostnamectl
nixos-version
uname -r
findmnt /
findmnt /nix
findmnt /boot
findmnt /boot/efi
lsblk -f
df -h / /nix /boot
systemctl --failed
systemctl list-timers --all
systemctl status NetworkManager display-manager
journalctl -b -p warning
nmcli device status
ip route
lspci -k
```

`findmnt /boot/efi` puede no devolver nada si la ESP usa otra ruta. Los timers listados son evidencia del estado observado, no prueba de toda configuración externa. Completar con los comandos de la sección 5.

**Laptop:** consultar el estado y el controlador NVIDIA con `nvidia-smi`, si está instalado y disponible. Revisar GRUB y su configuración en el punto de montaje confirmado. La ausencia o fallo de `nvidia-smi` requiere diagnóstico y no demuestra por sí sola que no exista GPU.

**Desktop:** consultar `bootctl status` y `bootctl list`; contrastar las entradas con los montajes y el firmware. La salida puede ser incompleta si no se arrancó con una interfaz compatible o faltan permisos.

Para una unidad concreta, sustituir `UNIDAD` por su nombre real y consultar `systemctl status UNIDAD` y `journalctl -b -u UNIDAD`. En una sesión de usuario, `systemctl --user --failed` y `journalctl --user -b` consultan sus unidades y registros. Si se requieren privilegios para leer logs o firmware, usar los permisos habituales del equipo.

## 9. TTY cuando falla la sesión gráfica

1. Cambiar a una consola virtual disponible, habitualmente con Ctrl+Alt+F2 o una tecla de función cercana; iniciar sesión localmente. La asignación exacta depende del equipo.
2. Confirmar hostname y generaciones con las secciones 5 y 8. Consultar unidades fallidas, `display-manager` y el journal del arranque actual; consultar el journal de usuario si está disponible.
3. Determinar si falla una sesión concreta, el gestor de pantalla, el driver o la generación completa. Registrar errores y comparar con el estado anterior.
4. Si el problema no se resuelve de forma aislada, usar el menú para probar la generación conocida conforme a la sección del host. Si tampoco funciona, continuar con rescate USB.

No reiniciar servicios, cambiar drivers ni activar una generación a ciegas. Una TTY funcional no demuestra que el siguiente arranque sea correcto.

## 10. Plan de rescate con USB UEFI

El USB aún debe prepararse y probarse: no se asume que exista ni que arranque en ninguno de los dos hosts.

1. Si el menú del cargador funciona, probar primero una generación conocida. Si no, arrancar un medio NixOS de rescate en modo UEFI y comprobar que se está en el host y entorno esperados.
2. Identificar discos, particiones, sistemas de archivos y posibles volúmenes cifrados; contrastar UUID, tamaño y contenido con el inventario previo. No confiar únicamente en nombres como `/dev/nvme0n1p1`, que pueden cambiar.
3. Identificar raíz, `/nix`, ESP y otros montajes necesarios. Examinar estado del almacenamiento y evidencia de fallo; si hay corrupción o daño físico, priorizar recuperación de datos y respaldos.
4. Preparar por separado el plan de montaje y acceso al sistema instalado, con los dispositivos y opciones concretos confirmados. Entrar al sistema o reparar un cargador puede requerir cambios; revisar la documentación de la versión pertinente y autorizar cada operación de escritura antes de realizarla.
5. Si se diagnostica un problema de bootloader, preparar una reparación específica para GRUB en laptop o systemd-boot en desktop. Confirmar la ESP correcta, espacio y repercusiones en otras entradas EFI antes de modificarla. No formatear particiones ni reinstalar el cargador por rutina.
6. Después de una reparación autorizada, comprobar menú, arranque sin USB y salud del sistema; documentar qué se cambió.

El [manual de instalación y recuperación de NixOS](https://nixos.org/manual/nixos/stable/) y la [guía oficial de bootloader](https://wiki.nixos.org/wiki/Bootloader) ofrecen contexto. Sus ejemplos de montaje e instalación son operaciones de escritura o dependen de la disposición del sistema: no copiarlos sin adaptación y verificación.

## 11. Datos mutables y límites

Una generación anterior no restaura automáticamente `/home`, archivos personales, secretos, bases de datos, volúmenes de contenedores ni estado de servicios en `/var`. Tampoco revierte migraciones de formato, firmware, particiones, ESP o NVRAM. Una versión anterior de un servicio puede no comprender datos migrados por la nueva.

Home Manager puede modificar archivos de usuario durante la activación. La extensión `backup` declarada en el flake no es una copia integral ni garantiza revertir su estado. Mantener respaldos independientes y probar restauraciones; no confundir entradas del menú con copias de seguridad.

## 12. Verificación y criterios de autorización

**Verificado documentalmente:** nombres de atributos, bootloaders declarados y límites de menú en el repositorio; los comandos de diagnóstico de este documento son consultas de lectura según la documentación general de Nix, systemd y herramientas del sistema. La documentación de baseline recoge observaciones previas, no una prueba de la configuración reorganizada.

**Pendiente en cada equipo:** versión y opciones realmente disponibles; menús y generaciones arrancables; selección predeterminada; UUID y montajes; espacio; estado de GC y servicios; sesiones gráficas, GPU y red; respaldos restaurables; USB UEFI y proceso de rescate. Registrar resultados antes de activar.

Las revisiones fijadas de nixpkgs son `f3a73bcf5d1c5b75a66cf35a48957e30d41d647a` (laptop) y `ee48b147c18c7de1e6ec97dc74792be42724bed1` (desktop). La sintaxis de operaciones de escritura debe comprobarse contra esas fuentes cuando estén disponibles y, además, contra las herramientas de la generación instalada que vaya a ejecutarlas. No se incluyen aquí comandos de escritura como procedimiento listo para ejecutar.

Autorizar una activación solo después de completar el checklist previo, confirmar el host y el plan de recuperación, y validar la sintaxis y efectos concretos. Autorizar una reparación del cargador solo tras identificar el fallo y los dispositivos y revisar las escrituras previstas. Las pruebas posteriores y de recuperación deben quedar registradas para cada host.
