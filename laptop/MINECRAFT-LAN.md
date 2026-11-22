# Minecraft Java en LAN

El puerto TCP 25565 permanece cerrado por defecto. Para permitirlo temporalmente
desde la subred IPv4 conectada a `wlo1`, ejecute `sudo minecraft-lan on`.
Consulte las excepciones con `sudo minecraft-lan status` y retírelas con
`sudo minecraft-lan off` **antes de cambiar de red**. El comando no abre IPv6.
Las excepciones temporales pueden perderse al reiniciar o recargar el firewall;
vuelva a consultar el estado y active la excepción cuando sea necesario.

«Abrir en LAN» de Minecraft Java puede elegir un puerto distinto de 25565: el
puerto mostrado por el juego debe ser 25565 para que esta excepción lo cubra.
