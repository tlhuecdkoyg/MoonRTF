# v0.1 支持矩阵

| 能力 | 支持范围 | 验证文件 |
| --- | --- | --- |
| 词法 | 控制词、符号、hex、32 位参数、二进制长度 | lexer_wbtest.mbt |
| 文档结构 | 单根分组、作用域恢复、截断及深度限制 | parse_test.mbt, features_test.mbt |
| Unicode | 有符号 UTF-16 控制值、代理对、fallback | parse_test.mbt |
| 代码页 | CP1252、显式 CP65001；其他编码诊断 | encoding_test.mbt |
| 格式 | 粗斜体、下划线、删除线、隐藏、上下标、字号、颜色、对齐 | parse_test.mbt, render_test.mbt |
| 表格 | 单层行/单元格；不重建合并与嵌套 | parse_test.mbt, render_test.mbt |
| 字段 | 显示文本、普通 HYPERLINK 地址；不求值 | parse_test.mbt |
| 元数据 | 标题作者等文本，创建/修订/打印/备份时间 | encoding_test.mbt |
| 图片/对象 | 记录位置、尺寸；不解码图像，不执行对象 | fixtures 与解析分支 |
| 区域 | 正文、页眉、页脚、脚注、注释 | parse_test.mbt |
| 导出 | 文本、JSON、基本 Markdown、语义 HTML、表格 CSV | render_test.mbt, features_test.mbt |
| 来源与检索 | 输出 UTF-16 范围到输入字节范围；跨 run 搜索 | features_test.mbt |
| 验证 | 语法、资源、字体/颜色引用、链接策略 | conversion_test.mbt, render_test.mbt |
| CLI | stdin/文件、错误退出码、覆盖保护 | scripts/smoke_cli.py |

来源映射是包围范围，不保证每个字符对应唯一连续输入字节；生成的段落分隔符不指向源码。JSON schema 是版本化的，不依赖 MoonBit enum 默认编码。RTF 时间无时区信息，不伪造 UTC。

`scan` 是词法检查，不等同于完整文档验证。`validate` 验证 MoonRTF 支持子集，不是完整标准认证。字体 family 和字体名在模型中保留；HTML 不注入任意字体 CSS。链接仅激活 http、https、mailto 和 fragment。
