"""Compile and run the two smoke programs with the bundled Win64 compiler."""

import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
CASES = (
    ("examples/helloworld.idk", "Hello World!"),
    ("tests/language_smoke.idk", "IDEKA language smoke passed"),
)


def main():
    if sys.platform != "win32" or platform.machine().upper() not in {"AMD64", "X86_64"}:
        raise SystemExit("This test requires an x64 Windows host.")
    env = {**os.environ, "IDEKA_SRCDIR": str(ROOT)}
    (ROOT / "build").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ci-win64-", dir=ROOT / "build") as scratch:
        work = Path(scratch)
        for relative, expected in CASES:
            source = ROOT / relative
            subprocess.run([ROOT / "idkc.exe", source], cwd=work, env=env, check=True, timeout=90)
            executable = work / "build" / source.stem / f"{source.stem}.exe"
            result = subprocess.run(
                [executable], cwd=work, capture_output=True, text=True, timeout=15
            )
            if result.returncode or result.stdout.rstrip("\r\n") != expected:
                raise SystemExit(
                    f"{relative}: exit={result.returncode}, expected {expected!r}, "
                    f"stdout={result.stdout!r}, stderr={result.stderr!r}"
                )
            print(f"PASS {relative}", flush=True)


if __name__ == "__main__":
    main()
