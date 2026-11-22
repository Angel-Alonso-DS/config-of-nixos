import fcntl
import ipaddress
import json
import os
import shlex
import subprocess
import sys

IP = "@ip@"
IPTABLES = "@iptables@"
TAG = "minecraft-lan-25565"


def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout


def rules():
    result = []
    for line in run(IPTABLES, "-w", "-S", "nixos-fw").splitlines():
        fields = shlex.split(line)
        # Only manage the exact rule shape produced by this command.
        if (len(fields) == 18 and fields[:2] == ["-A", "nixos-fw"]
                and fields[2] == "-s" and fields[4:] == [
                    "-i", "wlo1", "-p", "tcp", "-m", "tcp", "--dport", "25565",
                    "-m", "comment", "--comment", TAG, "-j", "ACCEPT"]):
            result.append(fields)
    return result


def subnet():
    links = json.loads(run(IP, "-j", "link", "show", "dev", "wlo1"))
    if not links or "UP" not in links[0].get("flags", []) or links[0].get("operstate") != "UP":
        raise ValueError("wlo1 no tiene una conexión activa")
    addresses = json.loads(run(IP, "-j", "-4", "address", "show", "dev", "wlo1", "scope", "global"))
    networks = set()
    for interface in addresses:
        for addr in interface.get("addr_info", []):
            if addr.get("family") != "inet" or addr.get("scope") != "global":
                continue
            if set(addr.get("flags", [])) & {"tentative", "dadfailed", "deprecated"}:
                continue
            ip = ipaddress.IPv4Interface(f"{addr['local']}/{addr['prefixlen']}")
            if (ip.ip.is_unspecified or ip.ip.is_loopback or ip.ip.is_link_local
                    or ip.ip.is_multicast or ip.ip.is_reserved or not 1 <= ip.network.prefixlen <= 30):
                continue
            networks.add(str(ip.network))
    if len(networks) != 1:
        raise ValueError("se requiere exactamente una subred IPv4 local válida en wlo1")
    return networks.pop()


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"on", "off", "status"}:
        raise ValueError("uso: minecraft-lan {on|off|status}")
    if os.geteuid() != 0:
        raise ValueError("se requieren privilegios de root; use sudo")
    with open("/run/lock/minecraft-lan.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        action = sys.argv[1]
        current = rules()
        if action == "status":
            if current:
                for rule in current:
                    print(f"Activa: TCP 25565 desde {rule[3]} por wlo1")
            else:
                print("No hay reglas minecraft-lan activas")
            return
        if action == "off":
            for rule in current:
                run(IPTABLES, "-w", "-D", *rule[1:])
            if rules():
                raise RuntimeError("no se pudieron retirar todas las reglas minecraft-lan")
            print("Reglas minecraft-lan retiradas")
            return
        network = subnet()
        if current and (len(current) != 1 or current[0][3] != network):
            raise ValueError("hay reglas de otra red o duplicadas; ejecute minecraft-lan off primero")
        if not current:
            run(IPTABLES, "-w", "-I", "nixos-fw", "1", "-s", network, "-i", "wlo1",
                "-p", "tcp", "--dport", "25565", "-m", "comment", "--comment", TAG,
                "-j", "ACCEPT")
        current = rules()
        if len(current) != 1 or current[0][3] != network:
            raise RuntimeError("no se pudo verificar la regla minecraft-lan")
        print(f"Activa: TCP 25565 desde {network} por wlo1")


try:
    main()
except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
    detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
    print(f"minecraft-lan: {detail}", file=sys.stderr)
    sys.exit(1)
