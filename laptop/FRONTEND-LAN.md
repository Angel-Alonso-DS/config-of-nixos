# Presentar un frontend desde la laptop

`frontend-lan` está implementado en esta configuración de la laptop, pero solo
estará disponible después de aplicarla. La configuración elimina la apertura
permanente de TCP 5173; hasta aplicarla, el firewall anterior puede seguir
permitiendo ese puerto y `frontend-lan off` no elimina esa apertura anterior.

## Requisitos

- Laptop y dispositivos conectados a la misma red IPv4, por `wlo1` en la laptop;
  la red no debe aislar a los clientes entre sí.
- Una única subred IPv4 válida en `wlo1`, interfaz activa y firewall NixOS con
  cadena `nixos-fw`. El comando requiere root (`sudo`), `ip` e `iptables`,
  incluidos en el paquete de la configuración.
- Un frontend compilado y un servidor HTTP que escuche en TCP 5173 en la
  dirección de la laptop o en `0.0.0.0`. La compilación y el servidor dependen
  del proyecto; el ejemplo siguiente supone npm y una salida `dist/`.

## Preparación y presentación

Desde el directorio del frontend, instale sus dependencias según su proyecto y
compile, por ejemplo:

```sh
npm ci
npm run build
```

Sirva el resultado en una terminal y déjela abierta (requiere Python 3):

```sh
python3 -m http.server 5173 --bind 0.0.0.0 --directory dist
```

En otra terminal compruebe la dirección IPv4 de `wlo1` y abra la excepción:

```sh
ip -4 addr show dev wlo1
sudo frontend-lan on
sudo frontend-lan status
```

Si, por ejemplo, la dirección de la laptop es `192.168.1.20`, abra
`http://192.168.1.20:5173/` en el navegador de otro dispositivo de la misma
subred. Use la dirección real mostrada por `ip`, no la dirección del ejemplo.
La excepción solo acepta IPv4 de esa subred por `wlo1`; no habilita IPv6 ni
otros puertos. El servidor de Python sirve archivos estáticos y no implementa
por sí mismo un backend ni el fallback de rutas de una SPA.

## Finalización y cambios de red

Antes de abandonar o cambiar de red, retire la excepción y verifique su estado:

```sh
sudo frontend-lan off
sudo frontend-lan status
```

Detenga el servidor con Ctrl+C en su terminal. `off` no detiene el servidor ni
modifica otras reglas. `on` es repetible para la misma subred; si hay reglas
antiguas o duplicadas, ejecute `off` antes de volver a activarlo. Las reglas son
temporales y pueden desaparecer al reiniciar o recargar el firewall: compruebe
`status` y vuelva a ejecutar `on` si necesita presentar. `status` informa solo
las reglas administradas por este comando, no confirma conectividad ni descarta
otras aperturas del firewall.

## Limpieza automática con NetworkManager

Una vez aplicada la configuración, los hooks de NetworkManager ejecutan
`frontend-lan off` solo para `wlo1` ante `pre-up`, `up`, `pre-down`, `down`,
`dhcp4-change` y `reapply`. Esto elimina las reglas propias al desconectar,
reconectar, cambiar de perfil o reaplicar la configuración IPv4. Los eventos
`pre-down` no están garantizados en pérdidas inesperadas de señal, por lo que
se cubren también `down` y la siguiente activación con `pre-up`/`up`.

**No se vuelve a abrir el puerto automáticamente.** Después de reconectar,
reaplicar la red o renovar DHCPv4, ejecute `sudo frontend-lan on` solo cuando
vuelva a necesitar compartir la presentación. Una renovación DHCPv4 puede
interrumpir el acceso aun cuando la subred no haya cambiado; es deliberado.

La limpieza depende de que NetworkManager emita y ejecute el evento. No es
una garantía frente a fallos del dispatcher, cambios de red externos a
NetworkManager o eventos demorados. Use `sudo frontend-lan off` como cierre
manual al terminar y verifique las reglas si necesita certeza sobre el estado.
El hook no cambia reglas de Minecraft ni detiene el servidor HTTP.
