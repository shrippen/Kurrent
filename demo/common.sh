# Shared by demo/start.sh and demo/shots.sh (internal, never part of a release).
# Builds the plugin with the demo compiled in (build-demo/, -DKURRENT_DEMO=ON; release builds
# leave it out) and prepares a scratch config home with the demo projects' colours.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_BUILD="${ROOT}/build-demo"
cmake -S "${ROOT}" -B "${DEMO_BUILD}" -DCMAKE_BUILD_TYPE=Release -DKURRENT_DEMO=ON -DBUILD_TESTING=OFF >/dev/null
cmake --build "${DEMO_BUILD}" --parallel "$(nproc)" --target kurrentplugin >/dev/null
DEMO_PLUGIN="${DEMO_BUILD}/qml/com/github/shrippen/kurrent/libkurrentplugin.so"

demo_config() {   # DIR: config home with kdeglobals and the demo project colours
    mkdir -p "$1/com.github.shrippen.kurrent"
    cp -p "${XDG_CONFIG_HOME:-${HOME}/.config}/kdeglobals" "$1/" 2>/dev/null || true
    python3 - "${ROOT}/demo/world.json" > "$1/com.github.shrippen.kurrent/kurrentrc" <<'PY'
import json, sys
collections = json.load(open(sys.argv[1]))["tasks"]["collections"]
colors = {str(9001 + i): c["color"] for i, c in enumerate(collections)}   # ids as in plugin/demodata.cpp
print("[General]\nprojectColors=" + json.dumps(colors, separators=(",", ":")))
PY
}
