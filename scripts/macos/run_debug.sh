#!/usr/bin/env bash
# Debug run on macOS (Android Studio / terminal). Requires config/env.local.json.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FLUTTER="${FLUTTER:-}"
if [[ -z "$FLUTTER" ]]; then
  if [[ -x "$ROOT/.fvm/flutter_sdk/bin/flutter" ]]; then
    FLUTTER="$ROOT/.fvm/flutter_sdk/bin/flutter"
  elif [[ -x "$HOME/fvm/versions/3.35.0/bin/flutter" ]]; then
    FLUTTER="$HOME/fvm/versions/3.35.0/bin/flutter"
  else
    FLUTTER="flutter"
  fi
fi

"$FLUTTER" pub get
exec "$FLUTTER" run -d macos --dart-define-from-file=config/env.local.json "$@"
