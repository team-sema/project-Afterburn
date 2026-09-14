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

## 기획 문서 기준

- 게임 구현 전에 `docs/design/README.md`와 관련 주제 기획서를 읽는다.
- 의도·동작·수치·예외·완료 조건은 같은 기획서에서 관리하고 변경 시 코드와 함께 갱신한다.
- `docs/design/history/`와 기존 Task는 과거 기록이며 현재 규칙보다 우선하지 않는다.
- 별도 시스템 설계서·구현 스펙을 만들지 않는다. Task에는 기획서 링크와 작업·검증 결과를 남긴다.
