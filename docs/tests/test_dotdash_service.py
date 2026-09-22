"""Run with python3 docs/tests/test_dotdash_service.py on Linux."""

import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
default = str(Path.home() / ".local/share/dotdash/app/server.js")
cases = [
    (None, default),
    ("", default),
    ("/tmp/dotdash-data", "/tmp/dotdash-data/dotdash/app/server.js"),
    ("/tmp/data with spaces/%h/$HOME", "/tmp/data with spaces/%%h/$$HOME/dotdash/app/server.js"),
]
for data_home, expected in cases:
    env = os.environ.copy()
    env.pop("XDG_DATA_HOME", None)
    if data_home is not None:
        env["XDG_DATA_HOME"] = data_home
    rendered = subprocess.check_output(
        ["chezmoi", "execute-template", "--file",
         str(repo / "dot_config/systemd/user/dotdash.service.tmpl")],
        env=env, text=True,
    )
    assert f'ExecStart=%h/.local/bin/mise exec -- node "{expected}"' in rendered
    with tempfile.TemporaryDirectory() as directory:
        unit = Path(directory) / "dotdash.service"
        unit.write_text(rendered)
        subprocess.run(["systemd-analyze", "--user", "verify", str(unit)], check=True)
print("PASS: default, empty, custom, and escaped XDG data paths")
