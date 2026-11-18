#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
trap 'rc=$?; [ "$rc" -eq 0 ] || echo "GATE: FAIL"' EXIT

python3 - <<'PY'
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class Links(HTMLParser):
    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ("href", "src") and value:
                check_target(value)


checked = 0


def check_target(value):
    global checked
    target = urlsplit(value)
    if target.scheme or target.netloc or not target.path:
        return
    path = Path(unquote(target.path))
    if path.is_absolute() or not path.is_file():
        raise SystemExit(f"Missing local target: {value}")
    checked += 1


config = json.loads(Path("config.json").read_text())
server = urlsplit(config["apiBaseURL"])
if server.scheme != "https" or not server.netloc:
    raise SystemExit("config.json must name an HTTPS server")
for page in Path(".").glob("*.html"):
    Links().feed(page.read_text())
for value in re.findall(r"url\(['\"]?([^)'\"]+)", Path("style.css").read_text()):
    check_target(value)
print(f"Verified config.json and {checked} local page/asset references")
PY

echo "GATE: PASS"
