#!/usr/bin/env bash
set -euo pipefail
python3 src/System/i18n/validate_i18n.py
python3 src/System/i18n/test_i18n.py
python3 src/Core/bridge/test_state_json.py
python3 src/Quickshell/desktop/test_app_index.py
python3 -m unittest src/Apps/Explorer/tests/test_explorer_helper.py
(cd src/Core/bridge/apps/explorer && cargo test -q)
