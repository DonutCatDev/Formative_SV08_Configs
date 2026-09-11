#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
klipper_dir="${KLIPPER_DIR:-$HOME/klipper}"
calibration_script="$klipper_dir/scripts/calibrate_shaper.py"
output_dir="$script_dir/outputs"
x_data="/tmp/calibration_data_x_auto_calibrate.csv"
y_data="/tmp/calibration_data_y_auto_calibrate.csv"

if [[ ! -f "$calibration_script" ]]; then
    echo "Klipper calibration script not found: $calibration_script" >&2
    exit 1
fi

if [[ ! -f "$x_data" || ! -f "$y_data" ]]; then
    echo "Expected X and Y auto-calibration data files in /tmp." >&2
    echo "Run AUTO_CALIBRATE before invoking this script." >&2
    exit 1
fi

mkdir -p -- "$output_dir"

python3 "$calibration_script" "$x_data" -o "$output_dir/input_shaper_x.png"
python3 "$calibration_script" "$y_data" -o "$output_dir/input_shaper_y.png"

echo "Wrote $output_dir/input_shaper_x.png"
echo "Wrote $output_dir/input_shaper_y.png"
