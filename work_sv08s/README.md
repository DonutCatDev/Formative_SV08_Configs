# Pilot candidate

[Configuration and macro reference](documentation/README.md) includes line-by-line
explanations. Follow [the documentation workflow](documentation/WORKFLOW.md) when
changing macros.

This tree is a local modernization candidate, not a deployed or physically
validated configuration. `work_sv08s/` remains the immutable baseline.

The active configuration starts at `config/printer.cfg`. That file is the
per-machine boundary: it retains the two MCU USB identities and Klipper's
auto-generated `SAVE_CONFIG` block. It includes `config/machine.cfg`, which owns
the shared static machine definition and the rest of the active include tree.
Fleet updates should replace the shared files without replacing `printer.cfg`
or its machine-specific generated calibration data. Custom orchestration is
split into explicit includes under `config/macros/`; Mainsail owns pause, resume
and cancellation.

The [manual filament workflow](../../validation/modernization/work_sv08s/manual-filament-workflow.md)
adds end/cancel withdrawal, M600 motor release and a final purge after preparation.
Physical checks remain pending; see the linked report for current test limits.

START_PRINT now includes a guarded native tap reference using a measured Z-only
kinematic reset. It remains gated pending physical commissioning of this new
sequence. The standalone TAP_REFERENCE helper permits supervised testing after
homing, QGL and nozzle cleaning. See the [implementation and acceptance procedure](../../validation/modernization/work_sv08s/tap-reference.md).

See [change reasoning and evidence](../../validation/modernization/work_sv08s/reasoning.md),
[offline checks](../../validation/modernization/work_sv08s/results.json), and
[pilot acceptance](../../validation/modernization/work_sv08s/acceptance.md).
