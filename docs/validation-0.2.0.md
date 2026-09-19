# 0.2.0 验证记录

本地验证日期：2026-09-19。系统：Windows；原生编译器：MSVC。

## 工具链

以下输出来自 `moon version --all`，省略机器相关的安装路径：

```text
moon 0.1.20260915 (2e1a46d 2026-09-15)
moonc v0.10.13+cbb11c36f (2026-09-15)
moonrun 0.1.20260915 (2e1a46d 2026-09-15)
```

这组版本是本次本地验证基线，不是所有旧版本或后续版本的兼容性承诺。CI 使用运行当时的 stable 渠道，并在日志中另行记录版本。

## 检查结果

| 检查 | 结果 |
| --- | --- |
| `moon check --target all --deny-warn` | 四个后端通过 |
| `moon test --target all --deny-warn` | wasm、wasm-gc、js、native 各 47 项通过 |
| `moon build --target native --release cmd/main` | 原生 CLI 构建通过 |
| `python scripts/smoke_cli.py` | 24 项通过，包括 HTML 文件输出、转义和输出限额 |
| `python scripts/stress_cli.py` | 328 项通过，随机种子 20260919 |
| `python scripts/count_lines.py --minimum 4000` | 4099 行生产有效代码；407 行测试代码不计入 |

`moon info` 与 `moon fmt` 已执行。公开接口变化为增加 `MappedText::source_range` 和 `cli.Command::Html`；后者要求对命令枚举做穷尽匹配的消费代码增加相应分支。

## 新增测试范围

- 选区跨样式 run、跨段落时的来源范围及段落编号。
- 空、反向、越界选区；只包含生成段落分隔符的选区。
- UTF-16 代理对中的偏移，以及隐藏文本过滤后的来源定位。
- HTML CLI 的正文及属性转义、链接协议限制、区域和隐藏文本过滤。
- HTML CLI 的截断输入、恢复模式、输出限额、退出码及文件写入。

源范围按 run 包围范围返回，不保证逐字符精确映射。HTML 是语义片段，不是页面排版复现。上述检查不代表完整 RTF 标准一致性；其余边界见 [支持矩阵](support-matrix.md)。
