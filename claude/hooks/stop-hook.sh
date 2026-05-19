#!/bin/sh
# No-op. Per-process cost/time tracking lives entirely in the statusline
# script (~/.claude/statusline/statusline-command.sh), which writes the
# current raw counters to ~/.claude/processes/<pid>-<ns>.json on every
# render. The Stop hook input doesn't include /usage's cost fields, so it
# has nothing useful to add. Kept as a stub so the existing Stop hook
# registration in settings.json continues to succeed.
exit 0
