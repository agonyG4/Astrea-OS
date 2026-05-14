#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
launch_manifest="${repo_root}/src/System/launch/Cargo.toml"
latencyd="${repo_root}/src/System/services/astrea_latencyd.py"
work_dir="$(mktemp -d)"
original_home="${HOME:-}"
latency_pid=""

cleanup() {
	if [[ -n "${latency_pid}" ]] && kill -0 "${latency_pid}" 2>/dev/null; then
		kill "${latency_pid}" 2>/dev/null || true
		wait "${latency_pid}" 2>/dev/null || true
	fi
	rm -rf "${work_dir}"
}
trap cleanup EXIT

export RUSTUP_HOME="${RUSTUP_HOME:-${original_home}/.rustup}"
export CARGO_HOME="${CARGO_HOME:-${original_home}/.cargo}"
export HOME="${work_dir}/home"
export XDG_CONFIG_HOME="${work_dir}/config"
export XDG_DATA_HOME="${work_dir}/share"
export XDG_STATE_HOME="${work_dir}/state"
export XDG_RUNTIME_DIR="${work_dir}/runtime"
mkdir -p "${HOME}" "${XDG_CONFIG_HOME}" "${XDG_DATA_HOME}/applications" "${XDG_STATE_HOME}" "${XDG_RUNTIME_DIR}"

cat >"${XDG_DATA_HOME}/applications/known.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Known Smoke App
Exec=/usr/bin/true --file=%f "quoted arg" escaped\ space %%
Terminal=false
DESKTOP

cargo run --quiet --manifest-path "${launch_manifest}" -- doctor >/dev/null
cargo run --quiet --manifest-path "${launch_manifest}" -- --desktop known.desktop >/dev/null

python3 "${latencyd}" serve &
latency_pid="$!"
for _ in {1..50}; do
	[[ -S "${XDG_RUNTIME_DIR}/Astrea/astrea-latencyd.sock" ]] && break
	sleep 0.1
done
[[ -S "${XDG_RUNTIME_DIR}/Astrea/astrea-latencyd.sock" ]]
python3 - <<'PYBOOST'
import json
import os
import socket

payload = {"op": "boost", "reason": "smoke", "duration_ms": 3000, "source": "smoke-launch-latency"}
path = os.path.join(os.environ["XDG_RUNTIME_DIR"], "Astrea", "astrea-latencyd.sock")
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.connect(path)
    client.sendall((json.dumps(payload) + "\n").encode("utf-8"))
PYBOOST
sleep 0.2
python3 "${latencyd}" status | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data.get("active") is True, data'
kill "${latency_pid}"
wait "${latency_pid}" 2>/dev/null || true
latency_pid=""
python3 -c 'import json, pathlib, sys; events=[json.loads(line) for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line.strip()]; assert any(event.get("event") == "rollback" for event in events), events' "${XDG_STATE_HOME}/Astrea/latencyd/history.jsonl"
