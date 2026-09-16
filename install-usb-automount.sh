#!/usr/bin/env bash

set -Eeuo pipefail

PRINTER_USER="${PRINTER_USER:-${SUDO_USER:-biqu}}"

if [[ "$PRINTER_USER" == "root" ]]; then
    printf '%s\n' 'Refusing to configure the USB mount for root.' >&2
    printf '%s\n' 'Run with sudo from the printer account or set PRINTER_USER explicitly.' >&2
    exit 1
fi

if ! id "$PRINTER_USER" >/dev/null 2>&1; then
    printf 'Printer user does not exist: %s\n' "$PRINTER_USER" >&2
    exit 1
fi

PRINTER_HOME="$(getent passwd "$PRINTER_USER" | cut -d: -f6)"
PRINTER_GROUP="$(id -gn "$PRINTER_USER")"
GCODE_DIR="${GCODE_DIR:-$PRINTER_HOME/printer_data/gcodes}"
MOUNT_POINT="$GCODE_DIR/USB"

if [[ ${EUID} -ne 0 ]]; then
    printf 'This installer needs root privileges. Run: sudo %s\n' "${0##*/}" >&2
    exit 1
fi

for command_name in blkid cut findmnt flock getent id install logger mount mountpoint systemctl udevadm umount; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

if [[ ! -d "$GCODE_DIR" ]]; then
    printf 'G-code directory does not exist: %s\n' "$GCODE_DIR" >&2
    printf '%s\n' 'Install Klipper/Moonraker first or set GCODE_DIR explicitly.' >&2
    exit 1
fi

install -d -o "$PRINTER_USER" -g "$PRINTER_GROUP" -m 0755 "$MOUNT_POINT"

install -m 0755 /dev/stdin /usr/local/sbin/formative-usb-mount <<'HELPER'
#!/usr/bin/env bash

set -Eeuo pipefail

readonly config_file=/etc/default/formative-usb-automount
[[ -r "$config_file" ]] || { printf 'Missing %s\n' "$config_file" >&2; exit 1; }
# The installer creates this root-owned file from validated local values.
# shellcheck source=/dev/null
source "$config_file"

readonly action="${1:-}"
readonly device_name="${2:-}"
readonly device="/dev/$device_name"
readonly state_dir=/run/formative-usb-automount
readonly state_file="$state_dir/$device_name"

log() {
    logger -t formative-usb-mount -- "$*"
    printf '%s\n' "$*"
}

mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock 9

case "$action" in
    mount)
        [[ "$device_name" =~ ^[a-zA-Z0-9._-]+$ ]] || { log "Invalid device name: $device_name"; exit 1; }
        [[ -b "$device" ]] || { log "Block device is unavailable: $device"; exit 1; }

        filesystem="$(blkid -o value -s TYPE "$device" 2>/dev/null || true)"
        [[ -n "$filesystem" ]] || { log "No filesystem detected on $device"; exit 1; }

        if mountpoint -q "$MOUNT_POINT"; then
            current_source="$(findmnt -n -o SOURCE --target "$MOUNT_POINT" || true)"
            log "USB mountpoint is already occupied by $current_source; ignoring $device"
            exit 1
        fi

        options='nosuid,nodev,noexec'
        case "$filesystem" in
            vfat|exfat|ntfs|ntfs3)
                printer_uid="$(id -u "$PRINTER_USER")"
                printer_gid="$(id -g "$PRINTER_USER")"
                options+=",uid=$printer_uid,gid=$printer_gid,umask=0022"
                ;;
        esac

        mount -o "$options" "$device" "$MOUNT_POINT"
        printf '%s\n' "$device" > "$state_file"
        log "Mounted $device ($filesystem) at $MOUNT_POINT"
        ;;
    unmount)
        if [[ ! -e "$state_file" ]]; then
            exit 0
        fi

        if mountpoint -q "$MOUNT_POINT"; then
            current_source="$(findmnt -n -o SOURCE --target "$MOUNT_POINT" || true)"
            expected_source="$(<"$state_file")"
            if [[ "$current_source" == "$expected_source" ]]; then
                umount "$MOUNT_POINT"
                log "Unmounted $expected_source from $MOUNT_POINT"
            else
                log "Refusing to unmount unexpected source $current_source from $MOUNT_POINT"
            fi
        fi
        rm -f "$state_file"
        ;;
    *)
        printf 'Usage: %s {mount|unmount} DEVICE_NAME\n' "${0##*/}" >&2
        exit 2
        ;;
esac
HELPER

printf 'PRINTER_USER=%q\nMOUNT_POINT=%q\n' "$PRINTER_USER" "$MOUNT_POINT" \
    | install -m 0644 /dev/stdin /etc/default/formative-usb-automount

install -m 0644 /dev/stdin /etc/systemd/system/formative-usb-mount@.service <<'SERVICE'
[Unit]
Description=Mount USB filesystem %I in the Klipper G-code directory
BindsTo=dev-%i.device
After=dev-%i.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/formative-usb-mount mount %I
ExecStop=/usr/local/sbin/formative-usb-mount unmount %I
TimeoutStartSec=30
TimeoutStopSec=30
SERVICE

install -m 0644 /dev/stdin /etc/udev/rules.d/90-formative-usb-automount.rules <<'RULE'
# Mount complete filesystems on USB mass-storage devices for Klipper.
ACTION=="add", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", ENV{ID_FS_USAGE}=="filesystem", TAG+="systemd", ENV{SYSTEMD_WANTS}+="formative-usb-mount@%k.service"
RULE

systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger --subsystem-match=block --action=add

printf 'USB G-code automount installed. Mountpoint: %s\n' "$MOUNT_POINT"
printf '%s\n' 'Insert one USB storage filesystem at a time; it will appear in the USB folder.'
printf '%s\n' 'Never remove the drive while printing a file from it.'
