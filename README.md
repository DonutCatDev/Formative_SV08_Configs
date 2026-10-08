# Formative SV08 configurations

This repository is the release and update boundary for shared configuration on
the Formative Sovol SV08 fleet. It keeps common machine behavior separate from
each printer's local identity and Klipper-generated calibration.

## Documentation

- [Configuration overview and installation](work_sv08s/README.md)
- [Generated configuration reference](work_sv08s/documentation/README.md)
- [How to read the reference](work_sv08s/documentation/READING_GUIDE.md)
- [Macro documentation workflow](work_sv08s/documentation/WORKFLOW.md)

The reference pages mirror active configuration source. Any pilot macro change
must update its annotations, regenerate the reference, and pass the freshness
test in the same commit.

## Repository layout

| Path | Purpose |
| --- | --- |
| `work_sv08s/config/machine.cfg` | Shared static machine definition and include root |
| `work_sv08s/config/macros/` | Homing, preparation, cleaning, filament, client, and calibration orchestration |
| `work_sv08s/config/options/` | Active LCD, probe, and thermistor configuration |
| `work_sv08s/config/printer-*.cfg` | Per-machine reference entry points, not installer overwrite targets |
| `work_sv08s/documentation/` | Generated and maintained configuration reference |
| `install-sv08.sh` | Idempotent shared-file installer |
| `install-usb-automount.sh` | Separately scoped removable-media setup |

## Preservation boundary

On every printer, `~/printer_data/config/printer.cfg` remains local. It owns MCU
serial identities and Klipper's generated `SAVE_CONFIG` block. The installer
links shared paths but never replaces that file. Calibration, PID, input shaper,
probe/tap data, and any mechanically derived machine value must remain
individual unless a specific measurement and review says otherwise.

## Change workflow

1. Trace the active include tree and all callers before changing shared behavior.
2. Keep one migration phase or subsystem per coherent commit.
3. Regenerate macro documentation when required.
4. Run local documentation/configuration tests.
5. Validate behavior on the SV08-15 pilot, including the relevant physical checks.
6. Roll out serially without replacing local entry points or calibration.

Local success is not fleet acceptance. Record which checks ran locally, on the
pilot, and on production hardware.

## Installation and release

Follow [the working configuration README](work_sv08s/README.md) for installation.
Release tags are created by the repository workflow when a pushed `main` commit
contains `[release]`, or through the reviewed manual workflow. Creating a local
commit does not deploy or publish it.

Fleet automation may set `FORMATIVE_SKIP_UPDATE=1` after it has independently
verified and pinned the checkout to a reviewed commit. The installer still
validates the repository origin and preservation boundaries; the flag only
suppresses its own `git pull` so the checkout cannot race past the approved
revision.
