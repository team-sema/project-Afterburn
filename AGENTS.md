# Project Afterburn agent instructions

## Running Godot

- Run Godot commands through `tools/run-godot.cmd`. Do not invoke the Godot executable directly from an agent sandbox.
- The wrapper sets `--path` to the repository root and redirects Godot's log to a unique file under `.godot/codex-logs/`. This avoids crashes when the sandbox cannot write to Godot's default `user://logs` directory in `%APPDATA%`.
- Example smoke test:

  ```powershell
  .\tools\run-godot.cmd --headless --script res://tests/example_test.gd
  ```

- Example project parse check:

  ```powershell
  .\tools\run-godot.cmd --headless --editor --quit
  ```

- Do not request elevated execution solely for the `user://logs` error. The wrapper handles that error inside the writable workspace. Escalate only if a different sandbox restriction still blocks a required check.
- Judge a smoke test by its exit code and explicit PASS/failure output. Report unrelated Godot editor/cache warnings separately from test failures.
