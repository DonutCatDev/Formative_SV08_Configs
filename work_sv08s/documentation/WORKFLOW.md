# Updating macro documentation

The source configs and `_tools/annotations.json` are the inputs. Per-file pages
and README.md are generated; edit the inputs rather than those output pages.
The generator uses only Python's standard library and never runs printer G-code.

## Whenever a config macro changes

1. Edit the candidate config. Inspect its callers and called macros as required
   by the workspace guidance. Do not edit either baseline snapshot.
2. Review the matching purpose summary and any line-specific explanations in
   [_tools/annotations.json](_tools/annotations.json). Change explanations to
   describe the implementation actually present, including defaults, conditions,
   motor/heater effects and unresolved work. For a new macro, add a purpose entry
   under `macros` or provide a clear `description:` in the source.
3. Run the command below. For a changed macro with a curated summary it reports
   a new `reviews` digest. After reviewing the summary and source lines, replace
   that macro's digest in `reviews` with the reported value. This prevents a
   changed retract length, for example, retaining a stale summary of the old
   distance. Do not bulk-accept digests without reviewing the explanations.
4. Run `--write` again, review the regenerated pages and cross-links, then run
   `--check` and the documentation tests. Include source, annotations and docs
   together in the same change.

From the workspace root in PowerShell:

```powershell
.venv/Scripts/python.exe -B updated_configs/work_sv08s/documentation/_tools/generate.py --write
.venv/Scripts/python.exe -B updated_configs/work_sv08s/documentation/_tools/generate.py --check
.venv/Scripts/python.exe -B validation/documentation/test_documentation.py
```

`--check` is read-only and fails for stale/missing/generated-orphan pages,
unreviewed macro summaries, missing includes or unexplained commands. `--write`
regenerates changed pages, updates line numbers/links and removes only obsolete
pages bearing the generator's marker. Unmarked handwritten documents are kept.
File renames or deletions update the index and dependent references on regeneration.

For automatic local updates while editing, leave this running in a terminal:

```powershell
.venv/Scripts/python.exe -B updated_configs/work_sv08s/documentation/_tools/generate.py --watch
```

The watcher detects changes to configs, annotations and the generator every
second and attempts regeneration. If review is required, it reports the exact
macro and waits for the annotation edit; it does not invent a new purpose.
Ctrl+C stops it. The watcher is provided but is not automatically installed as
a background service or started by opening this workspace.

## Adding an unfamiliar command or template

Unknown named commands cause generation to fail. Add a plain explanation in the
`commands` map after checking its official implementation. Use the `lines` map
for context-specific explanations keyed by the exact trimmed source line. For
a runtime-selected macro name, add its expression and known targets under
`dynamic_calls`; distinguish native aliases, external commands, state references
and actual custom-macro calls. Extend `_tools/generate.py` and its tests when a
new syntax needs different parsing. No model/API calls or network requests are
made by the generator.

## GitHub workflow

[macro-documentation.yml](../../../.github/workflows/macro-documentation.yml)
runs on pushes and pull requests that change the pilot configs, documentation
or documentation tests, and can also be dispatched manually. It checks freshness
and coverage. If the checked-in docs are stale, the check fails; a subsequent
step attempts regeneration and uploads the regenerated documentation as an
artifact for review. Unreviewed changes must still be explained before that
generation can succeed. Generated artifacts do not automatically commit back
to a branch. This avoids silently accepting stale human-written explanations.

The workflow needs only read access to repository contents; it does not deploy,
contact a printer, push commits or post messages. To require freshness before
merging, select its check in the repository's branch rules when appropriate.
No remote workflow run or branch-rule change was performed during local setup.

Validation results belong under `validation/documentation/`; progress notes
belong under `progression/work_sv08s/`. Link those records from progress rather
than placing test logs alongside these reference pages.
