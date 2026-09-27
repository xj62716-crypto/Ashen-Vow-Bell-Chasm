# Ashen Vow Demo · R9 route build

这是 Windows 单文件 R9 发布包。PCK 已内嵌在 `AshenVow-Demo.exe`，不需要额外的 `.pck` 文件。

运行方式：双击 `AshenVow-Demo.exe`。首次启动可能需要几秒加载资源。

操作：WASD 移动，Space 跳跃/蹬墙，Shift 空中冲刺，Ctrl 或 C 滑铲，鼠标左键攻击/施法，鼠标右键格挡/副职业动作，E 奇幻牵引，F 专注时缓，G 影刃回溯，Esc 暂停。

R9 包含两职业、三段垂直路线、现世/残世实体路线切换、墙跑→空中冲刺→再墙跑、祭坛核心构筑门禁、敌人攻击承诺、Boss 跑酷破核、短促钩锁和正式游戏音频事件。钩锁一次按键完成锁定、瞬间牵引和自动脱钩，最长约 0.5 秒，不要求松手，也不进入长时间摆荡；脱钩保留出口冲量和锚点配置的抬升，可接墙跑或空中冲刺。R9 同步收口了 R7 路线合同、时间线实体碰撞、阶段专属敌人分配、配置快照死锁，以及无渲染模式下的关卡回归性能。

本版 HUD 已补齐新策划案所需的玩法反馈：相位与冷却、独立时流/专注、影刃锋势与咒行者法力、技能就绪与当前行为、钩锁阶段、击杀返还、墙跑/滑铲跳/相位返还、Boss 阶段与核心目标，以及祭坛的动作槽、武器槽、路线槽和行为合同。

本版修复残世可见假地面、现世隐形横梁阻断钩锁、时间线锚点误判和第三关 Boss 出生高度/中心平台绑定。历史美术 QA 仍以整合工程中的 QA 记录和人工筛选状态为准，不由本 README 自动宣称美术采用。

- 文件：`release/AshenVow-Demo.exe`
- 来源：Godot Windows Desktop release export from the current integration worktree
- SHA-256：`4E5AF4AEE953988AB0987CD895023B2B6B8BD301224B3906ED97D095E248EE48`
- PCK 内嵌标记：GDPC
- 冷启动烟测：`--audio-driver Dummy --quit-after 180`，退出码 0；Vulkan 初始化正常，无 `SCRIPT ERROR` 或资源导入错误

当前自动回归中，生命周期、路线合同、课程和配置套件通过；连续路线、网络路线和两项战斗绕行距离约束仍有失败，不能视为全部 QA 已关闭。自动回归结果不替代人工验收。详见 `docs/workstreams/results/integration/R6-IMPLEMENTATION.md`。
