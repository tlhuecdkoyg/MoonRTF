# 来源与依赖

MoonRTF 是依据格式规范独立实现的 MoonBit 项目，不是 striprtf 或其他解析器的源码移植。

- RTF 1.9.1 规范：[微软规范引用](https://learn.microsoft.com/en-us/openspecs/exchange_server_protocols/ms-oxrtfex/3402a589-2578-4a15-99ce-04a91545f327)。仅引用规范；未复制附录 C 实现或整份文档。
- moonbitlang/core：MoonBit 标准库，按其开源许可使用。
- moonbitlang/async 0.21.0：官方异步文件与标准 I/O，Apache-2.0。
- moonbitlang/x 0.5.1：官方进程退出接口，Apache-2.0。
- fixtures/ 中 RTF 样例及测试字节串由本项目编写，按项目 Apache-2.0 许可提供，无私人数据。
- GitHub Actions 的 checkout/setup-node/setup-python 为 CI 工具，不作为产品源码或运行时发布。

Python striprtf 曾作为调研参考，当前实现未复制其代码或测试集，也不把它列为产品依赖。
