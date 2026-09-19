# Changelog

## 0.2.0

- Add `MappedText::source_range` for half-open UTF-16 selections, with explicit invalid-range and generated-separator behavior.
- Add the `html` CLI command with region/hidden-text controls, escaped content, safe hyperlink schemes and output limits.
- Add selection-boundary and HTML command regression tests, and extend native CLI checks.
- Document complete MoonBit component versions, rolling CI behavior and dependency upgrade instructions.
- Compatibility: `cli.Command` gains the `Html` variant; consumers exhaustively matching this enum must handle the new variant. Existing root-library APIs remain available.

## 0.1.1

- Reject body text, escapes and nested groups before the RTF header.
- Add strict/recovery regression cases and deterministic native CLI mutation checks.

## 0.1.0

- Bounded byte-level parser, Unicode and scoped Windows-1252/UTF-8 decoding.
- Document model with styles, single-level tables, links, regions and metadata.
- Text, JSON, Markdown, semantic HTML and table CSV exports.
- Source mappings, exact search, token inspection and actionable diagnostics.
- Native CLI with bounded stdin/file input, output controls and explicit failure codes.
- Cross-backend unit tests, native end-to-end checks and reproducible source metrics.
