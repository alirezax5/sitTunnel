#!/bin/bash

TUNNEL_DIR="/root/sit-tunnels"
CRON_TMP="/tmp/current_cron"
mkdir -p "$TUNNEL_DIR"

FIXED_IPV6_LIST=(
    "fd1d:fc98:b73e:b481::1/64"
    "fd2a:94b2:ee80:c211::1/64"
    "fd3f:ab01:cd23:aa10::1/64"
    "fd45:cc99:fa12:bb20::1/64"
    "fd57:dc10:badd:cc30::1/64"
    "fd61:eebf:aa34:dd40::1/64"
    "fd72:ff91:bb56:ee50::1/64"
    "fd83:ab12:cc78:ff60::1/64"
    "fd94:bc23:dd90:aa70::1/64"
    "fda5:cd34:eea1:bb80::1/64"
    "fdb6:de45:ffb2:cc90::1/64"
    "fdc7:ef56:aac3:dda0::1/64"
    "fdd8:f067:bbd4:eea0::1/64"
    "fde9:0178:ccd5:ffa0::1/64"
    "fdfa:1289:ddf6:aab0::1/64"
    "fdb1:239a:eef7:bbc0::1/64"
    "fdc2:34ab:fff8:ccc0::1/64"
    "fdd3:45bc:a109:ddd0::1/64"
    "fde4:56cd:b21a:eee0::1/64"
    "fdf5:67de:c32b:fff0::1/64"
)

function add_tunnel() {
    read -p "Enter tunnel name (e.g., sit1): " TUN_NAME
    read -p "Enter remote IPv4 address: " REMOTE_IP
    read -p "Enter local IPv4 address: " LOCAL_IP
    read -p "Enter the IPv6 address to use (e.g., fd1d:fc98:b73e:b481::1/64): " CHOSEN_IPV6

    CHOSEN_IPV6="${CHOSEN_IPV6%%/*}"
    FILE_NAME="$TUNNEL_DIR/${TUN_NAME}.sh"
    PING_FILE="$TUNNEL_DIR/${TUN_NAME}-ping.sh"

    {
        echo "#!/bin/bash"
        echo "ip tunnel add $TUN_NAME mode sit remote $REMOTE_IP local $LOCAL_IP ttl 255"
        echo "ip link set $TUN_NAME up"
        echo "ip link set dev $TUN_NAME mtu 1420"
        echo "ip -6 addr add $CHOSEN_IPV6 dev $TUN_NAME"
        echo "ip -6 route add default dev $TUN_NAME"
    } > "$FILE_NAME"

    chmod +x "$FILE_NAME"
    echo "Running tunnel script now..."
    bash "$FILE_NAME"

    {
        echo "#!/bin/bash"
        echo "ping -6 -c 1 $CHOSEN_IPV6 > /dev/null || echo \"[$(date)] IPv6 $CHOSEN_IPV6 is unreachable\" >> /var/log/tunnel-ping.log"
    } > "$PING_FILE"
    chmod +x "$PING_FILE"

    crontab -l 2>/dev/null > "$CRON_TMP"
    echo "@reboot bash $FILE_NAME" >> "$CRON_TMP"
    echo "0 * * * * bash $PING_FILE" >> "$CRON_TMP"
    crontab "$CRON_TMP"

    echo "Tunnel and ping script created:"
    echo "  - $FILE_NAME"
    echo "  - $PING_FILE"
}

function delete_tunnel() {
    echo "Available tunnels:"
    ls "$TUNNEL_DIR" | grep -E '\.sh$' | grep -v -- '-ping.sh' | nl
    read -p "Select the number to delete: " DEL_NUM
    FILE_NAME=$(ls "$TUNNEL_DIR" | grep -E '\.sh$' | grep -v -- '-ping.sh' | sed -n "${DEL_NUM}p")
    [ -z "$FILE_NAME" ] && echo "Invalid selection." && return

    FULL_PATH="$TUNNEL_DIR/$FILE_NAME"
    TUN_NAME="${FILE_NAME%.sh}"
    PING_PATH="$TUNNEL_DIR/${TUN_NAME}-ping.sh"

    TUN_NAME_LINE=$(grep -oP 'ip tunnel add \K\S+' "$FULL_PATH")
    if [ -n "$TUN_NAME_LINE" ]; then
        echo "Deleting tunnel interface: $TUN_NAME_LINE"
        ip tunnel del "$TUN_NAME_LINE" 2>/dev/null
    fi

    crontab -l 2>/dev/null | grep -v "$FULL_PATH" | grep -v "$PING_PATH" > "$CRON_TMP"
    crontab "$CRON_TMP"

    rm -f "$FULL_PATH" "$PING_PATH"
    echo "$FILE_NAME and related ping script deleted."
}

function edit_tunnel() {
    echo "Available tunnels:"
    ls "$TUNNEL_DIR" | grep -E '\.sh$' | grep -v -- '-ping.sh' | nl
    read -p "Select the number to edit: " EDIT_NUM
    FILE_NAME=$(ls "$TUNNEL_DIR" | grep -E '\.sh$' | grep -v -- '-ping.sh' | sed -n "${EDIT_NUM}p")
    [ -z "$FILE_NAME" ] && echo "Invalid selection." && return
    nano "$TUNNEL_DIR/$FILE_NAME"
}

function show_ipv6_list() {
    echo "Available IPv6 addresses (ULA range):"
    for i in "${!FIXED_IPV6_LIST[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${FIXED_IPV6_LIST[i]}"
    done
}

if [[ $# -eq 0 ]]; then
    while true; do
        echo ""
        echo "==== SIT Tunnel Manager ===="
        echo "1) Add new tunnel"
        echo "2) Delete tunnel"
        echo "3) Edit tunnel"
        echo "4) Show available IPv6 addresses"
        echo "0) Exit"
        echo "============================"
        read -p "Choose an option: " choice
        case $choice in
            1) add_tunnel ;;
            2) delete_tunnel ;;
            3) edit_tunnel ;;
            4) show_ipv6_list ;;
            0) break ;;
            *) echo "Invalid choice" ;;
        esac
    done
else
    TUN_NAME=$1
    REMOTE_IP=$2
    LOCAL_IP=$3
    CHOSEN_IPV6=$4

    [ -z "$TUN_NAME" ] || [ -z "$REMOTE_IP" ] || [ -z "$LOCAL_IP" ] || [ -z "$CHOSEN_IPV6" ] && {
        echo "Usage: $0 <tunnel_name> <remote_ip> <local_ip> <ipv6_address>"
        exit 1
    }

    CHOSEN_IPV6="${CHOSEN_IPV6%%/*}"
    FILE_NAME="$TUNNEL_DIR/${TUN_NAME}.sh"
    PING_FILE="$TUNNEL_DIR/${TUN_NAME}-ping.sh"

    {
        echo "#!/bin/bash"
        echo "ip tunnel add $TUN_NAME mode sit remote $REMOTE_IP local $LOCAL_IP ttl 255"
        echo "ip link set $TUN_NAME up"
        echo "ip link set dev $TUN_NAME mtu 1420"
        echo "ip -6 addr add $CHOSEN_IPV6 dev $TUN_NAME"
        echo "ip -6 route add default dev $TUN_NAME"
    } > "$FILE_NAME"
    chmod +x "$FILE_NAME"
    bash "$FILE_NAME"

    {
        echo "#!/bin/bash"
        echo "ping -6 -c 1 $CHOSEN_IPV6 > /dev/null || echo \"[$(date)] IPv6 $CHOSEN_IPV6 is unreachable\" >> /var/log/tunnel-ping.log"
    } > "$PING_FILE"
    chmod +x "$PING_FILE"

    crontab -l 2>/dev/null > "$CRON_TMP"
    echo "@reboot bash $FILE_NAME" >> "$CRON_TMP"
    echo "0 * * * * bash $PING_FILE" >> "$CRON_TMP"
    crontab "$CRON_TMP"

    echo "Tunnel and ping script created."
fi
