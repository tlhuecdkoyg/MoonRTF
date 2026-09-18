# 发布步骤

1. 在候选提交执行 README 中的全部验证命令，保存工具链版本与生产有效代码统计。
2. 检查远程 main 已包含至少 5 次真实开发提交，README 示例可从干净克隆运行。
3. `moon publish --dry-run` 检查打包范围，不包含 .mooncakes、_build、凭据或私有资料。
4. 以模块所有者登录，执行 `moon publish`；如果版本已发布，不能覆盖，先递增版本。
5. 在独立项目 `moon add tlhuecdkoyg/MoonRTF@0.1.0` 并运行示例，确认真正从注册表取包。
6. 核对 Mooncakes 文档/仓库链接，GitHub v0.1.0 标签对应实际发布源码。

推送成功、CI 成功、Mooncakes 发布成功是三个独立状态；不能互相替代。比赛报名和审核状态也需独立核对。
