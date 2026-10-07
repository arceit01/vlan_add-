# vlan-setup.sh

**Version:** 1.0

Interactive shell script to create and delete VLAN sub-interfaces on top of
`eth*` network interfaces using `iproute2` (`ip` command).

## Features

- Automatically detects all physical `eth*` interfaces on the system.
- Lets you pick an interface and a VLAN ID to create a VLAN sub-interface
  (e.g. `eth0.100` for VLAN ID `100` on `eth0`).
- Optionally enables DHCP on the newly created VLAN interface via `dhclient`.
- Lists existing VLAN interfaces and lets you delete any of them.
- Shows the current status (UP/DOWN) and IP address(es) of all VLAN
  interfaces.
- Menu-driven: keeps running until you choose to exit, so you can add/delete
  multiple VLANs in one session.

## Requirements

- Linux with `iproute2` (the `ip` command).
- `dhclient` installed if you want to use the DHCP option (optional —
  the script still works without it, DHCP setup will simply be skipped
  with a warning).
- Root privileges (`ip link add/delete` requires root).

## Important Notes

- **No persistence**: all changes are applied immediately with `ip` commands
  only. Nothing is written to `/etc/network/interfaces`, netplan, or
  `systemd-networkd` configuration files. **VLAN interfaces created by this
  script will be lost after a reboot.**
- Only interfaces named `ethN` (e.g. `eth0`, `eth1`) are detected as
  selectable physical interfaces. Existing VLAN sub-interfaces (e.g.
  `eth0.100`) are excluded from this list.

## Usage

```bash
sudo ./vlan-setup.sh
```

Show the script version:

```bash
./vlan-setup.sh --version
# or
./vlan-setup.sh -v
```

### Main Menu

```
===== VLAN Setup Menu (v1.0) =====
1) Add VLAN
2) Delete VLAN
3) Show VLAN status
4) Exit
```

#### 1) Add VLAN

1. Select a physical `eth*` interface from the detected list.
2. Enter a VLAN ID (1–4094).
3. The script creates `ethX.VID` and brings it up.
4. Optionally enable DHCP (`y`/`n`) — if enabled, `dhclient` requests an
   address on the new VLAN interface.
5. The resulting interface configuration is shown (`ip addr show`).

#### 2) Delete VLAN

1. Select an existing VLAN interface from the detected list.
2. The script releases any DHCP lease (`dhclient -r`), brings the interface
   down, and deletes it.

#### 3) Show VLAN status

Displays all current VLAN interfaces with their state (UP/DOWN) and assigned
IP address(es):

```
===== VLAN Interface Status =====
INTERFACE        STATE    IP ADDRESS(ES)
eth0.100@eth0    UP       192.168.100.10/24
```

#### 4) Exit

Exits the script.

## Example Session

```
$ sudo ./vlan-setup.sh

===== VLAN Setup Menu (v1.0) =====
1) Add VLAN
2) Delete VLAN
3) Show VLAN status
4) Exit
Select an option [1-4]: 1

Available eth interfaces:
  1) eth0
  2) eth1
Select an interface [1-2]: 2
Enter VLAN ID (1-4094): 100
Creating VLAN interface eth1.100 on eth1 ...
VLAN interface eth1.100 created successfully.
Enable DHCP on eth1.100? (y/n): y
Requesting DHCP lease for eth1.100 ...
DHCP lease obtained for eth1.100.

Interface summary:
...
Press Enter to continue...
```

## License

Internal use script, no specific license applied.
