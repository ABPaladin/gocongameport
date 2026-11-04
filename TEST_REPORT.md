# Test report

No migration gameplay tests have passed yet. Static baseline inspection completed.
2026-11-03: python -B -m unittest discover -s tests: 4/4 PASS.
Checks: immutable source SHA256 manifest, 13 maps' command/plane equality,
102 asset references resolve, original message/choice translations preserved.
git diff --exit-code -- legacy: PASS (no changes).
MCP diagnostics confirmed the wrong project root; no mutations were sent.
Tests and exact results will be recorded as implementation progresses.

Godot 4.7.2 headless: startup smoke passed. Runtime suite now has 151 passing
checks: all 13 maps, branch exclusion, choice selection, loop/break/budget,
route waits, picture motion, timers, translation lookups, self-switch conditions,
opcode declarations, actual intro, source-identity transfer continuation,
rock-paper-scissors random outcomes and duplicate-reward prevention,
projectile timeout/reset and win-result reward/transfer.
This is synthetic execution of real content, not a human full playthrough.
Initial intro test exposed stale autorun restart; fixed page-refresh ordering.
Accelerated logic tests exposed OGG mixer cleanup warnings when many audio
streams were replaced within a tight simulation loop. The logic suite now
loads resources without starting the real mixer; separate real-time audio
validation remains required. The checker now fails on any engine ERROR.

2026-11-04: runtime suite 166/166 PASS, no engine errors or cleanup warnings.
Added actual QTE timed-input success and reward-page locking; checkpoint write,
atomic replacement, restoration, missing/corrupt/unknown-version rejection.
Four Python content tests pass; git diff against baseline legacy is empty.
Screen blend-mode mapping was corrected (MV mode 3 is screen, not multiply).
Visual screen-shader output and real-time audio are not yet verified.
