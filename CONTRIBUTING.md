# Contributing

Thanks for helping make MacConvert better. The codebase is small on purpose —
plain zsh, no build step — so most contributions are a single file.

## Project layout

```
bin/macconvert      CLI entry point (command dispatch only)
lib/                CLI modules; manifest.sh is the single source of truth
                    for every action (label, UTIs, script, dependencies)
scripts/            runtime conversion scripts — one per Quick Action,
                    all built on scripts/_common.sh
tests/              verify.sh (end-to-end), unit.sh (fast checks),
                    generate-samples.sh (reproducible test corpus)
install.sh          bootstrap installer
```

## Adding a new conversion

1. Write `scripts/convert-<from>-to-<to>.sh`. Copy an existing one — define
   `process_file`, call `run_batch "$@"`. Use absolute tool paths from
   `_common.sh` (Automator strips `$PATH`).
2. Add one row to `MC_ACTIONS` in `lib/manifest.sh` with the action's
   dependencies. That row is all the CLI needs — the menu, installer,
   dependency resolution and doctor pick it up automatically.
3. Add a `test_row` to `tests/verify.sh` (and extend
   `tests/generate-samples.sh` if the input format has no sample yet).
4. Run the tests (below).

## Running tests

```sh
tests/unit.sh                  # fast: syntax, manifest integrity, bundle lint
./install.sh --all             # install everything locally
tests/verify.sh                # end-to-end: runs every action via automator
```

`verify.sh` runs each Quick Action through the same `automator` CLI path that
Finder uses, with a stripped `$PATH` matching Finder's environment — if it
passes, the right-click works.

## Guidelines

- zsh, not bash — macOS's default shell. Mind zsh's special variables
  (`path`, `status` are tied to the environment).
- Conversion scripts must never overwrite the input or an existing output
  (`unique_output_path` handles suffixing).
- Failures notify; successes stay silent. Log everything to
  `~/Library/Logs/macconvert/<action>.log`.
- One behavior change per PR, with the test that proves it.
