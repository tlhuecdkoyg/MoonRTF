# MoonRTF

[![CI](https://github.com/tlhuecdkoyg/MoonRTF/actions/workflows/ci.yml/badge.svg)](https://github.com/tlhuecdkoyg/MoonRTF/actions/workflows/ci.yml)

纯 MoonBit 的 RTF 文档解析与文本提取库，附原生 CLI。面向文档导入、搜索索引和格式转换。支持中文 Unicode、基础样式、简单表格、超链接、元数据、错误诊断和来源定位。

Pure MoonBit RTF parsing and extraction with bounded inputs, source ranges, diagnostics, and a native command-line interface. The parser does not invoke Word, Python, LibreOffice or an OS rich-text control.

## 快速运行

需要最新稳定版 [MoonBit](https://www.moonbitlang.com/download/)。本地验证版本：`moonc 0.10.13` / `moon 20260915`。原生 CLI 需要 C 编译环境；库本身支持 wasm、wasm-gc、js、native。

```sh
git clone https://github.com/tlhuecdkoyg/MoonRTF.git
cd MoonRTF
moon update
moon run examples/basic
moon run --target native cmd/main -- text fixtures/basic.rtf
moon run --target native cmd/main -- json fixtures/basic.rtf --pretty
moon run --target native cmd/main -- markdown fixtures/basic.rtf
moon run --target native cmd/main -- csv fixtures/table.rtf
moon run --target native cmd/main -- validate fixtures/malformed.rtf
```

最后一个命令故意返回 1，展示截断文件的诊断。普通正文输出包含 `中文 😀`。命令的所有选项见 `moon run --target native cmd/main -- --help`。

## 库接口

模块发布名为 `tlhuecdkoyg/MoonRTF`；发布状态见 [Releases](https://github.com/tlhuecdkoyg/MoonRTF/releases) 和 [Mooncakes](https://mooncakes.io/docs/tlhuecdkoyg/MoonRTF)。仅当该版本实际发布后才可从注册表安装：

```sh
moon add tlhuecdkoyg/MoonRTF@0.1.1
```

在消费包的 `moon.pkg` 导入模块并指定别名 `@rtf`。以下是直接针对本包运行的文档测试：

```mbt check
///|
test "README extraction" {
  let result = @MoonRTF.parse(
    b"{\\rtf1 Hello {\\b MoonRTF}! \\u20013?\\u25991?}",
  )
  assert_true(result.acceptable())
  assert_eq(result.document.to_text(), "Hello MoonRTF! 中文")
  assert_eq(result.document.find_text("MoonRTF").length(), 1)
}
```

推荐使用 `parse` 并检查 `complete` / `diagnostics`。`extract_text` 是便捷接口，不返回诊断，不能用于判断输入是否有效。`validate` 可额外检查未定义字体、颜色和链接策略。

主要 API：

- `parse` / `validate` / `scan`：结构解析、语义校验、词法检查。
- `Document::to_text` / `to_markdown` / `to_html`：可配置正文导出。
- `ParseResult::to_json_text`：`moonrtf.document.v1` 结构化输出。
- `Document::tables` / `Table::to_csv`：简单表格提取。
- `Document::mapped_text` / `find_text`：定位到原始字节范围。
- `MappedText::source_range(start, end)`：将非空 UTF-16 半开选区映射到相关 run 的输入字节范围及段落编号。越界、空选区、反向选区返回 `None`；仅包含生成分隔符的合法选区返回空来源列表。
- `ParseResult::convert`：返回转换结果、格式损失诊断及输出限额状态。
- `Document::statistics` / `created_time` / `revised_time`：统计与时间元数据。

## 支持边界

正确处理 `\uN` / `\ucN`、代理对、Windows-1252，以及显式 `\ansicpg65001` UTF-8。GBK/CP936 等其他传统编码尚不支持；受影响字符会有诊断，结果标记为不完整。Unicode 转义形式的中文不受此限制。

支持单层表格、基础字符/段落样式和字段显示文本。图片与对象只记录元数据，不渲染。默认正文导出排除隐藏文字、页眉、页脚和注释，可显式启用。JSON 保留已解析的隐藏文字，因此分享结构化输出前应考虑这一点。

不承诺完整 Word 排版、RTF 写回、嵌套/合并表格、自动列表编号、压缩 RTF、宏执行或完整 RTF 1.9.1 一致性。Markdown 将首行视为表头，复杂格式会降级；HTML 为语义片段，不是像素级渲染。详细矩阵见 [support-matrix](docs/support-matrix.md)。

## CLI 与限额

命令：`text`、`json`、`markdown`、`inspect`、`validate`、`tokens`、`source-map`、`csv`。省略文件名或使用 `-` 从 stdin 读取。`-o FILE` 写文件，默认拒绝覆盖，`--force` 才允许覆盖已有输出；输入文件受到保护。

退出码：0 成功；1 文档错误、资源限额或所选校验策略失败；2 参数/文件 I/O 错误。诊断与正常输出分流。`--recover` 保留可恢复内容，但错误仍返回 1；`--strict` 使警告也影响成功判定。

默认输入上限 32 MiB、嵌套 256 层、文档节点 200000、解码文本 33554432 个 UTF-16 单元、诊断 1000 条。CLI 在读取时检查输入上限。输出上限在序列化后检查，不是序列化期间的峰值内存保证。

## 验证与代码规模

```sh
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
python scripts/count_lines.py --minimum 4000
moon build --target native --release cmd/main
python scripts/smoke_cli.py
python scripts/stress_cli.py
```

行数脚本仅统计手写生产 `.mbt`，排除注释、空行、帮助文字块、测试、示例、生成接口和依赖。测试覆盖随机字节、逐字节截断、Unicode、编码错误、分组作用域、表格、导出、来源映射与 CLI。CI 在 Linux/Windows 运行。

工程设计见 [design](docs/design.md)，发布步骤见 [release](docs/release.md)，许可证与参考资料见 [THIRD_PARTY](THIRD_PARTY.md)。

## 许可证

Apache-2.0。依据公开规范独立实现。样例为项目自制；AI 辅助代码经过编译、测试与审查，具体限制在上述文档中公开。
