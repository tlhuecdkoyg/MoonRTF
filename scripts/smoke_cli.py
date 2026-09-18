"""End-to-end checks against the built native executable, without external packages."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
exe = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "_build/native/release/build/cmd/main/main.exe"
if not exe.exists():
    exe = exe.with_suffix("")
checks = 0


def run(*args, data=None, code=0):
    global checks
    result = subprocess.run([str(exe), *map(str, args)], input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            cwd=root, timeout=30)
    assert result.returncode == code, (args, result.returncode, result.stderr.decode("utf-8", "replace"))
    checks += 1
    return result.stdout.decode("utf-8")


assert "Usage:" in run("--help")
assert "0.1.0" in run("--version")
text = run("text", "fixtures/basic.rtf")
assert "中文 😀" in text and "MoonRTF" in text
document = json.loads(run("json", "fixtures/basic.rtf", "--pretty"))
assert document["schema"] == "moonrtf.document.v1" and document["complete"]
assert "**MoonRTF**" in run("markdown", "fixtures/basic.rtf")
assert "Input bytes:" in run("inspect", "fixtures/basic.rtf")
assert json.loads(run("validate", "fixtures/basic.rtf", "--json"))["valid"]
assert run("csv", "fixtures/table.rtf") == "Name,Value\r\nA,42\r\n"
assert "tokens" in json.loads(run("tokens", "fixtures/basic.rtf", "--json"))
assert json.loads(run("source-map", "fixtures/basic.rtf"))["offset_unit"] == "utf16"
assert run("text", "-", data=b"{\\rtf1 stdin}") == "stdin"
run("validate", "fixtures/malformed.rtf", code=1)
run("text", "fixtures/basic.rtf", "--max-input", "1", code=1)
run("text", "-", "--max-input", "1", data=b"{\\rtf1 x}", code=1)
run("text", "fixtures/basic.rtf", "--max-output", "1", code=1)
run("text", "missing-file.rtf", code=2)
run("text", "--unknown", code=2)
with tempfile.TemporaryDirectory() as directory:
    output = Path(directory) / "out.txt"
    run("text", "fixtures/basic.rtf", "-o", output)
    assert "中文" in output.read_text(encoding="utf-8")
    run("text", "fixtures/basic.rtf", "-o", output, code=2)
    run("text", "fixtures/basic.rtf", "-o", output, "--force")
print(f"Native CLI smoke checks passed: {checks}")
