#!/bin/bash
#
# vlan-setup.sh
# Interactive script to create/delete VLAN sub-interfaces on top of eth* interfaces.
# Uses iproute2 (ip command) only. No persistence - changes are lost on reboot.

set -u

VERSION="1.0"

# ---------- Arguments ----------

if [[ "${1:-}" == "-v" || "${1:-}" == "--version" ]]; then
    echo "vlan-setup.sh version $VERSION"
    exit 0
fi

# ---------- Pre-checks ----------

if [[ $EUID -ne 0 ]]; then
    echo "Error: this script must be run as root (try: sudo $0)" >&2
    exit 1
fi

if ! command -v ip >/dev/null 2>&1; then
    echo "Error: 'ip' command not found. Please install iproute2." >&2
    exit 1
fi

# ---------- Helpers ----------

# List physical eth* interfaces (exclude existing VLAN sub-interfaces like ethX.Y)
list_eth_interfaces() {
    ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 | grep -E '^eth[0-9]+$'
}

# List existing VLAN interfaces (type vlan)
list_vlan_interfaces() {
    ip -o link show type vlan | awk -F': ' '{print $2}' | cut -d'@' -f1
}

pause() {
    read -rp "Press Enter to continue..." _
}

# ---------- Add VLAN ----------

add_vlan() {
    mapfile -t eth_list < <(list_eth_interfaces)

    if [[ ${#eth_list[@]} -eq 0 ]]; then
        echo "No eth* interfaces found on this system."
        pause
        return
    fi

    echo
    echo "Available eth interfaces:"
    for i in "${!eth_list[@]}"; do
        printf "  %d) %s\n" "$((i+1))" "${eth_list[$i]}"
    done

    local choice
    while true; do
        read -rp "Select an interface [1-${#eth_list[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#eth_list[@]} )); then
            break
        fi
        echo "Invalid selection. Please enter a number between 1 and ${#eth_list[@]}."
    done

    local iface="${eth_list[$((choice-1))]}"

    local vlan_id
    while true; do
        read -rp "Enter VLAN ID (1-4094): " vlan_id
        if [[ "$vlan_id" =~ ^[0-9]+$ ]] && (( vlan_id >= 1 && vlan_id <= 4094 )); then
            break
        fi
        echo "Invalid VLAN ID. Please enter a number between 1 and 4094."
    done

    local vlan_iface="${iface}.${vlan_id}"

    if ip link show "$vlan_iface" >/dev/null 2>&1; then
        echo "Error: interface $vlan_iface already exists."
        pause
        return
    fi

    echo "Creating VLAN interface $vlan_iface on $iface ..."
    ip link set "$iface" up
    if ! ip link add link "$iface" name "$vlan_iface" type vlan id "$vlan_id"; then
        echo "Error: failed to create $vlan_iface."
        pause
        return
    fi
    ip link set "$vlan_iface" up

    echo "VLAN interface $vlan_iface created successfully."

    local dhcp_choice
    read -rp "Enable DHCP on $vlan_iface? (y/n): " dhcp_choice
    if [[ "$dhcp_choice" =~ ^[Yy]$ ]]; then
        if command -v dhclient >/dev/null 2>&1; then
            echo "Requesting DHCP lease for $vlan_iface ..."
            if dhclient "$vlan_iface"; then
                echo "DHCP lease obtained for $vlan_iface."
            else
                echo "Warning: dhclient failed for $vlan_iface."
            fi
        else
            echo "Warning: dhclient not found. Skipping DHCP setup."
        fi
    else
        echo "Skipping DHCP setup."
    fi

    echo
    echo "Interface summary:"
    ip addr show "$vlan_iface"
    pause
}

# ---------- Delete VLAN ----------

delete_vlan() {
    mapfile -t vlan_list < <(list_vlan_interfaces)

    if [[ ${#vlan_list[@]} -eq 0 ]]; then
        echo "No VLAN interfaces found to delete."
        pause
        return
    fi

    echo
    echo "Existing VLAN interfaces:"
    for i in "${!vlan_list[@]}"; do
        printf "  %d) %s\n" "$((i+1))" "${vlan_list[$i]}"
    done

    local choice
    while true; do
        read -rp "Select a VLAN interface to delete [1-${#vlan_list[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#vlan_list[@]} )); then
            break
        fi
        echo "Invalid selection. Please enter a number between 1 and ${#vlan_list[@]}."
    done

    local vlan_iface="${vlan_list[$((choice-1))]}"

    if command -v dhclient >/dev/null 2>&1; then
        dhclient -r "$vlan_iface" >/dev/null 2>&1
    fi

    ip link set "$vlan_iface" down
    if ip link delete "$vlan_iface"; then
        echo "VLAN interface $vlan_iface deleted successfully."
    else
        echo "Error: failed to delete $vlan_iface."
    fi
    pause
}

# ---------- Show VLAN Status ----------

show_vlan_status() {
    mapfile -t vlan_list < <(list_vlan_interfaces)

    echo
    if [[ ${#vlan_list[@]} -eq 0 ]]; then
        echo "No VLAN interfaces found."
    else
        echo "===== VLAN Interface Status ====="
        printf "%-16s %-8s %s\n" "INTERFACE" "STATE" "IP ADDRESS(ES)"
        ip -br addr show type vlan
    fi
    pause
}

# ---------- Main Menu ----------

main_menu() {
    while true; do
        echo
        echo "===== VLAN Setup Menu (v$VERSION) ====="
        echo "1) Add VLAN"
        echo "2) Delete VLAN"
        echo "3) Show VLAN status"
        echo "4) Exit"
        read -rp "Select an option [1-4]: " opt

        case "$opt" in
            1) add_vlan ;;
            2) delete_vlan ;;
            3) show_vlan_status ;;
            4) echo "Bye."; exit 0 ;;
            *) echo "Invalid option. Please enter 1, 2, 3, or 4." ;;
        esac
    done
}

main_menu
