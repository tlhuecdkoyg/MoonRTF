# 0.1.1 validation

Local validation on Windows, 2026-09-19, using MoonBit stable 2026-09-15.

- `python scripts/count_lines.py --minimum 4000`: 4086 production lines; 326 test lines excluded. Comments, blank lines, help text, examples, generated interfaces and dependencies are excluded.
- `moon check --target all --deny-warn`: passed.
- `moon test --target all --deny-warn`: 41 tests passed on each of wasm, wasm-gc, js and native.
- `moon build --target native --release cmd/main`: passed.
- `python scripts/smoke_cli.py`: 20 end-to-end checks passed, including stdin, files, exports, limits, exit codes and overwrite protection.
- `python scripts/stress_cli.py`: 328 deterministic generated-input checks passed, using seed 20260919. Checks cover styled/ignored text equivalence, truncated and mutated documents, nesting exhaustion, huge numeric parameters, invalid UTF-8, strict/recovery modes, valid JSON and bounded source spans. Each subprocess has a 10-second timeout.
- `moon info`: public API unchanged.

The iteration fixes acceptance of body text, escapes and nested groups before the RTF version header. Regression tests verify rejection in strict and recovery modes and retention of recoverable body text.

These checks establish reproducible behavior for the documented subset; they do not establish full RTF conformance or support for every producer. GBK/CP936, nested/merged tables and embedded object rendering remain outside the supported scope. Output size checks do not provide a peak-memory bound for serialization. See [support matrix](support-matrix.md).
