# NetworkManager passes the interface and event as positional parameters.
# No event ever opens the port: an explicit frontend-lan on is required.
[ "${1:-}" = "wlo1" ] || exit 0

case "${2:-}" in
  pre-up|up|pre-down|down|dhcp4-change|reapply)
    exec "@frontendLan@" off
    ;;
esac
exit 0
