#!/usr/bin/env bash
# Notification hook — fires when Claude Code sends a notification
# Shows a native desktop notification on Windows, macOS, or Linux.
# Falls back to plain stdout if no notifier is available. Never blocks the
# session: the platform notifier is launched in the background and all errors
# are suppressed.

# Read notification JSON from stdin
INPUT=$(cat)

# Extract message — try jq first, fall back to grep
if command -v jq &>/dev/null; then
  MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
fi
if [ -z "$MESSAGE" ]; then
  MESSAGE=$(echo "$INPUT" | grep -oE '"message":"[^"]*"' | sed 's/"message":"//;s/"//')
fi
if [ -z "$MESSAGE" ]; then
  MESSAGE="Claude Code needs your attention"
fi

# Truncate to a sane length for any notifier
MESSAGE=$(echo "$MESSAGE" | head -c 200)

TITLE="Claude Code"

# Detect platform via uname (OSTYPE is bash-specific; uname is more portable)
UNAME=$(uname -s 2>/dev/null)

case "$UNAME" in
  Darwin)
    # macOS — prefer terminal-notifier if installed, else osascript
    if command -v terminal-notifier &>/dev/null; then
      # terminal-notifier takes plain arguments (no shell-quoting concerns)
      terminal-notifier -title "$TITLE" -message "$MESSAGE" &>/dev/null &
    elif command -v osascript &>/dev/null; then
      # Escape backslashes and double quotes for the AppleScript string literals
      MSG_SAFE=$(printf '%s' "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')
      TITLE_SAFE=$(printf '%s' "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
      osascript -e "display notification \"$MSG_SAFE\" with title \"$TITLE_SAFE\"" &>/dev/null &
    fi
    ;;
  Linux)
    # Linux — use notify-send if a notification daemon/tool is available
    if command -v notify-send &>/dev/null; then
      # notify-send takes plain arguments; -- guards against messages starting with '-'
      notify-send -- "$TITLE" "$MESSAGE" &>/dev/null &
    fi
    ;;
  *)
    # Windows (Git Bash / MSYS reports MINGW*/MSYS*/CYGWIN*) or unknown
    if command -v powershell.exe &>/dev/null; then
      # Sanitize message for PowerShell single-quoted string embedding
      MESSAGE_SAFE=$(echo "$MESSAGE" | sed "s/'/''/g")
      powershell.exe -NonInteractive -WindowStyle Hidden -Command "
        Add-Type -AssemblyName System.Windows.Forms
        \$notify = New-Object System.Windows.Forms.NotifyIcon
        \$notify.Icon = [System.Drawing.SystemIcons]::Information
        \$notify.BalloonTipTitle = 'Claude Code'
        \$notify.BalloonTipText = '$MESSAGE_SAFE'
        \$notify.Visible = \$true
        \$notify.ShowBalloonTip(5000)
        Start-Sleep -Seconds 6
        \$notify.Dispose()
      " 2>/dev/null &
    fi
    ;;
esac

# Always echo to stdout so the notification is visible even without a GUI notifier
echo "Notification: $MESSAGE"
