{ config, lib, pkgs, ... }:

{
    services.hostapd = {
      enable = true;
      radios.wlo1 = {
        band = "2g";              # 2.4GHz: mejor compatibilidad de clientes
        countryCode = "MX";
        networks.wlo1 = {
          ssid = "ElManolo";
          authentication = {
            mode = "wpa2-sha1";   # WPA2-PSK estándar, máxima compatibilidad
            wpaPasswordFile = "/etc/nixos/secrets/hotspot-psk"; # ver nota abajo
          };
        };
      };
    };

    services.dnsmasq = {
      enable = true;
      settings = {
        interface = [ "wlo1" ];
        bind-interfaces = true;
        "dhcp-range" = [ "10.42.0.10,10.42.0.254,24h" ];
      };
    };

    # Ninguno de los dos debe arrancar solo al boot: se activan/desactivan
    # a demanda desde el menú de rofi.
    systemd.services.hostapd.wantedBy = lib.mkForce [ ];
    systemd.services.dnsmasq.wantedBy = lib.mkForce [ ];

    # Interfaz + traspaso NM <-> hostapd, como dependencia de ambos servicios.
    systemd.services.hotspot-iface = {
      description = "IP estática + traspaso de wlo1 de NetworkManager a hostapd";
      before = [ "hostapd.service" "dnsmasq.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.networkmanager}/bin/nmcli device set wlo1 managed no";
        ExecStart = "${pkgs.iproute2}/bin/ip addr replace 10.42.0.1/24 dev wlo1";
        ExecStop = "${pkgs.iproute2}/bin/ip addr del 10.42.0.1/24 dev wlo1";
        ExecStopPost = "${pkgs.networkmanager}/bin/nmcli device set wlo1 managed yes";
      };
    };

    systemd.services.hostapd.after     = [ "hotspot-iface.service" ];
    systemd.services.hostapd.requires  = [ "hotspot-iface.service" ];
    systemd.services.hostapd.partOf    = [ "hotspot.target" ];

    systemd.services.dnsmasq.after     = [ "hotspot-iface.service" ];
    systemd.services.dnsmasq.requires  = [ "hotspot-iface.service" ];
    systemd.services.dnsmasq.partOf    = [ "hotspot.target" ];

    systemd.services.hotspot-iface.partOf = [ "hotspot.target" ];

    systemd.targets.hotspot = {
      description = "Hotspot (hostapd + dnsmasq)";
      wants = [ "hotspot-iface.service" "hostapd.service" "dnsmasq.service" ];
    };

    # Comparte Internet de enp2s0 hacia los clientes de wlo1.
    networking.nat = {
      enable = true;
      internalInterfaces = [ "wlo1" ];
      externalInterface = "enp2s0";
    };

    networking.firewall.interfaces."wlo1" = {
      allowedUDPPorts = [ 53 67 ];
      allowedTCPPorts = [ 53 ];
    };

    # SSID visible para el script de rofi sin duplicar el dato a mano.
    environment.etc."hotspot-ssid".text = "ElManolo";

    # Permite iniciar/detener SOLO estos dos servicios sin sudo.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            (action.lookup("unit") == "hotspot.target" ||
            action.lookup("unit") == "hostapd.service" ||
            action.lookup("unit") == "dnsmasq.service") &&
            subject.isInGroup("networkmanager")) {
          return polkit.Result.YES;
        }
      });
    '';

}
