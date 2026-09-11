#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
klipper_dir="${KLIPPER_DIR:-$HOME/klipper}"
graph_script="$klipper_dir/scripts/graph_accelerometer.py"
output_dir="$script_dir/outputs"
output_file="$output_dir/belt_resonances.png"

shopt -s nullglob
belt_a_files=(/tmp/raw_data_axis=*_belt_a.csv)
belt_b_files=(/tmp/raw_data_axis=*_belt_b.csv)

if [[ ! -f "$graph_script" ]]; then
    echo "Klipper graph script not found: $graph_script" >&2
    exit 1
fi

if (( ${#belt_a_files[@]} != 1 || ${#belt_b_files[@]} != 1 )); then
    echo "Expected one belt_a and one belt_b data file in /tmp." >&2
    echo "Run the LCD Belt resonance test after reboot, then retry." >&2
    exit 1
fi

mkdir -p -- "$output_dir"

python3 "$graph_script" \
    "${belt_a_files[0]}" \
    "${belt_b_files[0]}" \
    -o "$output_file"

echo "Wrote $output_file"
