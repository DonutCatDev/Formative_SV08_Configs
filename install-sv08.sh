#!/usr/bin/env bash

set -Eeuo pipefail

REPO_URL="${FORMATIVE_REPO_URL:-https://github.com/DonutCatDev/Formative_SV08_Configs.git}"
REPO_DIR="${FORMATIVE_REPO_DIR:-$HOME/Formative_SV08_Configs}"
CONFIG_DIR="${PRINTER_CONFIG_DIR:-$HOME/printer_data/config}"
SOURCE_SUBDIR="${FORMATIVE_SOURCE_SUBDIR:-work_sv08s/config}"
PRIMARY_BRANCH="${FORMATIVE_PRIMARY_BRANCH:-main}"
RESTART_MOONRAKER=1

usage() {
    printf 'Usage: %s [--no-restart]\n' "${0##*/}"
    printf '\nEnvironment overrides:\n'
    printf '  FORMATIVE_REPO_URL       Git repository URL\n'
    printf '  FORMATIVE_REPO_DIR       Clone destination\n'
    printf '  FORMATIVE_SOURCE_SUBDIR  Config path inside the repository\n'
    printf '  FORMATIVE_PRIMARY_BRANCH Moonraker update branch\n'
    printf '  PRINTER_CONFIG_DIR       Klipper/Moonraker config directory\n'
}

case "${1:-}" in
    "") ;;
    --no-restart) RESTART_MOONRAKER=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

for command_name in git ln mv mkdir grep date; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

if [[ ! -d "$CONFIG_DIR" ]]; then
    printf 'Printer config directory does not exist: %s\n' "$CONFIG_DIR" >&2
    exit 1
fi

if [[ ! -f "$CONFIG_DIR/printer.cfg" ]]; then
    printf 'Missing per-machine config: %s/printer.cfg\n' "$CONFIG_DIR" >&2
    exit 1
fi

MOONRAKER_CONFIG="$CONFIG_DIR/moonraker.conf"
if [[ ! -f "$MOONRAKER_CONFIG" ]]; then
    printf 'Missing Moonraker config: %s\n' "$MOONRAKER_CONFIG" >&2
    exit 1
fi

if ! grep -Eq '^[[:space:]]*\[include[[:space:]]+machine\.cfg\][[:space:]]*(#.*)?$' "$CONFIG_DIR/printer.cfg"; then
    printf '%s\n' 'printer.cfg must contain an active [include machine.cfg] line.' >&2
    printf '%s\n' 'Refusing to alter the per-machine file or its SAVE_CONFIG data.' >&2
    exit 1
fi

if [[ -e "$REPO_DIR" && ! -d "$REPO_DIR/.git" ]]; then
    printf 'Clone destination exists but is not a Git repository: %s\n' "$REPO_DIR" >&2
    exit 1
fi

if [[ -d "$REPO_DIR/.git" ]]; then
    CURRENT_ORIGIN="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ "$CURRENT_ORIGIN" != "$REPO_URL" ]]; then
        printf 'Repository origin mismatch at %s\n' "$REPO_DIR" >&2
        printf 'Expected: %s\nActual:   %s\n' "$REPO_URL" "$CURRENT_ORIGIN" >&2
        exit 1
    fi
    printf 'Updating %s\n' "$REPO_DIR"
    git -C "$REPO_DIR" pull --ff-only
else
    printf 'Cloning %s into %s\n' "$REPO_URL" "$REPO_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
fi

SOURCE_DIR="$REPO_DIR/$SOURCE_SUBDIR"
for source_name in machine.cfg macros options scripts; do
    if [[ ! -e "$SOURCE_DIR/$source_name" ]]; then
        printf 'Repository is missing required path: %s/%s\n' "$SOURCE_DIR" "$source_name" >&2
        exit 1
    fi
done

BACKUP_DIR="$CONFIG_DIR/.formative-sv08-backups/$(date +%Y%m%d-%H%M%S)-$$"
backup_created=0

link_config() {
    local name="$1"
    local source="$SOURCE_DIR/$name"
    local target="$CONFIG_DIR/$name"

    if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
        printf 'Already linked: %s\n' "$target"
        return
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        if (( backup_created == 0 )); then
            mkdir -p "$BACKUP_DIR"
            backup_created=1
        fi
        printf 'Backing up %s to %s/\n' "$target" "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/"
    fi

    ln -s "$source" "$target"
    printf 'Linked %s -> %s\n' "$target" "$source"
}

for config_name in machine.cfg macros options scripts; do
    link_config "$config_name"
done

MOONRAKER_INCLUDE="$CONFIG_DIR/formative-sv08-update.conf"
cat > "$MOONRAKER_INCLUDE" <<EOF
# Managed by install-sv08.sh. This repository supplies shared SV08 configuration.
[update_manager formative_sv08_configs]
type: git_repo
channel: dev
path: $REPO_DIR
origin: $REPO_URL
primary_branch: $PRIMARY_BRANCH
managed_services: klipper
EOF

if ! grep -Eq '^[[:space:]]*\[include[[:space:]]+formative-sv08-update\.conf\][[:space:]]*(#.*)?$' "$MOONRAKER_CONFIG"; then
    printf '\n[include formative-sv08-update.conf]\n' >> "$MOONRAKER_CONFIG"
    printf 'Added Moonraker include to %s\n' "$MOONRAKER_CONFIG"
else
    printf 'Moonraker include already present\n'
fi

if (( RESTART_MOONRAKER == 1 )); then
    if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active moonraker.service >/dev/null 2>&1; then
        systemctl --user restart moonraker.service
        printf 'Restarted user service moonraker.service\n'
    elif command -v sudo >/dev/null 2>&1 && sudo systemctl restart moonraker.service; then
        printf 'Restarted system service moonraker.service\n'
    else
        printf '%s\n' 'Could not restart Moonraker automatically. Restart it before using Update Manager.' >&2
    fi
else
    printf '%s\n' 'Moonraker restart skipped; restart it before using Update Manager.'
fi

printf '\nInstallation complete. Restart Klipper and confirm it reaches Ready before printing.\n'
if (( backup_created == 1 )); then
    printf 'Previous shared paths were saved in %s\n' "$BACKUP_DIR"
fi
