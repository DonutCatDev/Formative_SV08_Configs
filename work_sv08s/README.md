# Formative SV08 Configs

[Configuration and macro reference](documentation/README.md) includes line-by-line
explanations. Follow [the documentation workflow](documentation/WORKFLOW.md) when
changing macros.

This repository contains the shared SV08 configuration and per-machine entry
points prepared for deployment. It is maintained independently from the
development workspace and its baseline and validation records.

On a printer, the active configuration starts at its local `printer.cfg`. That
file is the per-machine boundary: it retains the two MCU USB identities and
Klipper's auto-generated `SAVE_CONFIG` block. It includes `machine.cfg`, which
owns the shared static machine definition and the rest of the active include
tree. Fleet updates replace the shared files without replacing `printer.cfg` or
its machine-specific generated calibration data. The numbered
`config/printer-*.cfg` files are reference entry points for their corresponding
machines; the installer does not link or copy them over a printer's local
`printer.cfg`.

Custom orchestration is split into explicit includes under `config/macros/`;
Mainsail owns pause, resume, and cancellation. The manual filament workflow adds
end/cancel withdrawal, M600 motor release, and a final purge after preparation.

START_PRINT now includes a guarded native tap reference using a measured Z-only
kinematic reset. It remains gated pending physical commissioning of this new
sequence. The standalone TAP_REFERENCE helper permits supervised testing after
homing, QGL, and nozzle cleaning. Physical pilot acceptance remains required
before treating behavior-changing configuration as fleet-ready.

## Install on a printer

The repository includes an idempotent installer that clones or fast-forwards this
repository, links the shared `machine.cfg`, `macros/`, `options/`, and `scripts/`
paths into `~/printer_data/config`, and registers the repository with Moonraker's
Update Manager:

```bash
git clone https://github.com/DonutCatDev/Formative_SV08_Configs.git
cd Formative_SV08_Configs
./install-sv08.sh
```

The existing `printer.cfg` is never changed and must already contain an active
`[include machine.cfg]` line. Existing shared paths are moved to a timestamped
`~/printer_data/config/.formative-sv08-backups/` directory before linking. Run
`./install-sv08.sh --no-restart` to defer the Moonraker restart.

## Tag a release

Run `./tag-release.sh` from a clean, fully pushed branch to create and push an
annotated timestamp tag. Tags use the Moonraker-compatible numeric form
`vYEAR.MONTH.DAYHHMMSS`; the annotation records the readable local timestamp and
the complete commit ID.
