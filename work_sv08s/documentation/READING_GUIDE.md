# Reading the configuration reference

Start with [the file and macro index](README.md). Each source configuration has
a matching `.md` document at the same relative path. For example,
`config/macros/client.cfg` maps to `documentation/macros/client.cfg.md`.
Files with no macros still have a page listing their configuration sections.
The configuration's `readme.md` is prose, not another config file.

The top of each page identifies whether it is reached by any current printer
entry point. A canonical `printer.cfg` is used when present; otherwise every
numbered `printer-NN.cfg` is treated as a fleet entry point. Optional files,
saved data and backups are not presented as active printer behavior. Moonraker
and Crowsnest load their own service configuration independently. A listed
saved calibration section is data, not a command to run. Commented macro
examples are explicitly inactive.

For each macro, read its purpose, then the source/explanation table in order.
Every nonblank line in its definition is represented, including comments,
variables, conditions and commands. Empty separator lines are omitted. Multi-line
expressions have a row for every physical line; continuation rows belong to the
same expression and do not run as independent commands. Source-line links open
the matching config; GitHub understands their `#L` line anchors.

Macro calls link directly to the called macro's explanation, even across folders.
The calls/state-reference list also links variable owners, delayed callback IDs
and configured hooks. It is not an unconditional execution list: branches may
skip calls, and reading another macro's variables does not execute that macro.
Runtime-selected names such as Mainsail hooks and timelapse's stored pause/resume
commands are labelled. The known owners are linked; arbitrary external values
cannot be resolved statically. Renamed base commands are native implementations,
not missing custom macros. External commands such as NETWORK_STATUS_REFRESH
are marked as extension interfaces.

## Timing and units

Klipper evaluates a macro's entire Jinja template first, then executes its
resulting command sequence. Local `{% set ... %}` expressions calculate values;
they do not execute motion. A called macro gets a new evaluation when reached.
`action_raise_error` and other `action_*` functions act during evaluation, so
their effects can precede commands printed earlier in the source.
[Klipper template timing](https://www.klipper3d.org/Command_Templates.html#template-expansion).

Positions and filament distances use millimeters. `G90` chooses absolute XYZ
positions and `G91` chooses relative movement. `M83` selects relative filament
movement; `M82` allows absolute E when XYZ is absolute. `F` is mm/min; a helper's
`SPEED` parameter can instead be mm/s, as explained on that helper's page.
Omitted movement coordinates and feed rate retain previous values.
`M400` waits for motion to finish. Restoring G-code state without `MOVE=1` restores
modes/accounting but does not return the nozzle to the saved XYZ location.
[Klipper movement/state guidance](https://www.klipper3d.org/Command_Templates.html#save-restore-state-for-g-code-moves).

`variable_*` lines supply restart defaults; SET_GCODE_VARIABLE changes runtime
state without rewriting config. Heater targets differ from measured temperatures.
TURN_OFF_HEATERS does not instantly cool the nozzle. A disabled extruder can be
turned manually, and subsequent E movement can enable it again.
[Command definitions](https://www.klipper3d.org/G-Codes.html),
[status fields](https://www.klipper3d.org/Status_Reference.html).

## Current operating limits

Documentation explains the saved candidate; it does not certify that any macro
has passed physical testing. In particular, TAP_REFERENCE currently aborts, and
the commissioning flag alone cannot make START_PRINT work. Initial Eddy setup
is a different operation, blocked when calibration exists. The reference keeps
those distinctions visible rather than describing intended future behavior as
implemented behavior.

For maintenance, follow [the update workflow](WORKFLOW.md).
