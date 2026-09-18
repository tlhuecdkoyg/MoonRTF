"""Deterministic generated-input checks; no downloaded or third-party fixtures."""
import json
import random
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
exe = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "_build/native/release/build/cmd/main/main.exe"
if not exe.exists():
    exe = exe.with_suffix("")
rng = random.Random(20260919)
checks = 0


def invoke(command, data, *flags):
    global checks
    result = subprocess.run([str(exe), command, "-", *flags], input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            cwd=root, timeout=10)
    assert result.returncode in (0, 1), (checks, data, result.returncode, result.stderr)
    checks += 1
    return result


def check_spans(value, size):
    if isinstance(value, dict):
        if set(value) == {"start", "end"}:
            assert 0 <= value["start"] <= value["end"] <= size, (value, size)
        for child in value.values():
            check_spans(child, size)
    elif isinstance(value, list):
        for child in value:
            check_spans(child, size)


corpus = []
for _ in range(64):
    words = ["".join(rng.choices("abcdef", k=rng.randrange(1, 20))) for _ in range(6)]
    body = " ".join("{\\b " + word + "}{\\*\\unknown ignored}" for word in words)
    data = ("{\\rtf1 " + body + "}").encode("ascii")
    result = invoke("text", data)
    assert result.returncode == 0 and result.stdout.decode() == " ".join(words)
    corpus.append(data[:rng.randrange(len(data))])
    damaged = bytearray(data)
    for _ in range(8):
        damaged[rng.randrange(len(damaged))] = rng.randrange(256)
    corpus.append(bytes(damaged))
corpus.extend([
    b"{\\rtf1" + b"{" * 300 + b"x" + b"}" * 301,
    b"{\\rtf1\\bin2147483647 x}",
    b"{\\rtf1\\u99999999999999999999999999 x}",
    b"{\\rtf1\\ansicpg65001 " + bytes(range(256)) + b"}",
])
for data in corpus:
    for flags in [(), ("--recover",)]:
        result = invoke("json", data, *flags)
        report = json.loads(result.stdout)
        assert report["schema"] == "moonrtf.document.v1"
        if result.returncode == 0:
            assert report["complete"]
        check_spans(report, len(data))
print(f"Native CLI generated-input checks passed: {checks}; seed=20260919")
