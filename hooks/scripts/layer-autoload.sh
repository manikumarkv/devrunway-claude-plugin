#!/usr/bin/env bash
# Auto-loads layer standards for the file Claude just read or edited.
# See layer_autoload.py. Needs python3; without it, silently does nothing.
command -v python3 >/dev/null 2>&1 || exit 0
exec python3 "$(dirname "$0")/layer_autoload.py"
