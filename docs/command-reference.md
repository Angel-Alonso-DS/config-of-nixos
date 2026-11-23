# Referencia de comandos LAN

Estos comandos personalizados están implementados en la configuración de la
laptop `nixos-alons`; requieren aplicar esa configuración para estar disponibles.
Se ejecutan como root con `sudo`. No inician ni detienen servidores.

| Comando | Estado | Efecto |
| --- | --- | --- |
| `sudo minecraft-lan on` | Implementado | Permite temporalmente TCP 25565 desde la subred IPv4 de `wlo1`. |
| `sudo minecraft-lan off` | Implementado | Retira sus reglas reconocidas. |
| `sudo minecraft-lan status` | Implementado | Muestra sus reglas reconocidas. |
| `sudo frontend-lan on` | Implementado en este cambio | Permite temporalmente TCP 5173 desde la subred IPv4 de `wlo1`. |
| `sudo frontend-lan off` | Implementado en este cambio | Retira sus reglas reconocidas. |
| `sudo frontend-lan status` | Implementado en este cambio | Muestra sus reglas reconocidas. |

No hay subcomandos adicionales implementados. Los comandos de este cambio
están pendientes de estar disponibles en la máquina hasta que se aplique la
configuración. `on` requiere `wlo1` activa y exactamente una subred IPv4 válida;
si existen reglas duplicadas o de otra subred, primero debe ejecutarse `off`.
Las reglas no cubren IPv6 y pueden desaparecer al reiniciar o recargar el
firewall. `status` solo muestra las reglas que administra el comando, no prueba
que haya un servidor escuchando ni que otras reglas permitan o impidan acceso.

Véanse [Minecraft LAN](../laptop/MINECRAFT-LAN.md) y la
[guía de presentaciones](../laptop/FRONTEND-LAN.md).

La configuración de la laptop también instala un hook de NetworkManager para
retirar automáticamente las reglas de `frontend-lan` cuando `wlo1` cambia de
conexión, se desconecta o se reconfigura. El hook nunca abre TCP 5173. Tras
una reconexión o renovación DHCPv4 debe invocarse `on` manualmente de nuevo.
