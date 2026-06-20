# Active Hooks

Hooks are configured in `.claude/settings.json` and fire automatically:

| Hook | Event | Trigger | Action |
| ---- | ----- | ------- | ------ |
| `validate-commit.sh` | PreToolUse (Bash) | `git commit` commands | Validates design doc sections, JSON data files, hardcoded values, TODO format |
| `validate-push.sh` | PreToolUse (Bash) | `git push` commands | Warns on pushes to protected branches (develop/main) |
| `validate-assets.sh` | PostToolUse (Write/Edit) | Asset file changes | Checks naming conventions and JSON validity for files in `assets/` |
| `session-start.sh` | SessionStart | Session begins | Loads sprint context, milestone, git activity; detects and previews active session state file for recovery |
| `detect-gaps.sh` | SessionStart | Session begins | Detects fresh projects (suggests /start) and missing documentation when code/prototypes exist, suggests /reverse-document or /project-stage-detect |
| `pre-compact.sh` | PreCompact | Context compression | Dumps session state (active.md, modified files, WIP design docs) into conversation before compaction so it survives summarization |
| `post-compact.sh` | PostCompact | After compaction | Reminds Claude to restore session state from `active.md` checkpoint |
| `notify.sh` | Notification | Notification event | Shows a native desktop notification — Windows toast (PowerShell), macOS (`osascript`/`terminal-notifier`), Linux (`notify-send`); falls back to stdout |
| `session-stop.sh` | Stop | Session ends | Summarizes accomplishments and updates session log |
| `log-agent.sh` | SubagentStart | Agent spawned | Audit trail start — logs subagent invocation with timestamp |
| `log-agent-stop.sh` | SubagentStop | Agent stops | Audit trail stop — completes subagent record |
| `validate-skill-change.sh` | PostToolUse (Write/Edit) | Skill file changes | Advises running `/skill-test` after any `.claude/skills/` file is written or edited |

Hook reference documentation: `.claude/docs/hooks-reference/`
Hook input schema documentation: `.claude/docs/hooks-reference/hook-input-schemas.md`

## Hook Path Resilience

Each hook command in `.claude/settings.json` is anchored to the project root and
guarded so it works no matter the current directory and never crashes the
session when a script is absent:

```
cd "${CLAUDE_PROJECT_DIR:-.}" && { [ ! -f .claude/hooks/<name>.sh ] || bash .claude/hooks/<name>.sh; }
```

- **Project root, not the current directory.** Claude Code may invoke a hook
  while working in a sub-directory. `cd "${CLAUDE_PROJECT_DIR:-.}"` first moves
  to the project root (`$CLAUDE_PROJECT_DIR` is set by Claude Code), so the hook
  is found and its own relative paths (`git`, `production/...`) resolve. This
  avoids the `bash: .claude/hooks/<name>.sh: No such file or directory` error
  that occurs when a hook is launched from a sub-directory. If the variable is
  unset, it falls back to the current directory.
- **Missing script is a no-op.** If the script is absent the command exits 0
  silently instead of erroring.
- **Exit codes preserved.** When the script is present its real exit code is
  returned, so blocking validators (for example `validate-commit.sh`, which can
  `exit 2`) still block as intended. stdin is still passed through to the hook.
