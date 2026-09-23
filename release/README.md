# Ashen Vow Demo · R6

这是 Windows 单文件 R6 发布包。PCK 已内嵌在 `AshenVow-Demo.exe`，不需要额外的 `.pck` 文件。

运行方式：双击 `AshenVow-Demo.exe`。首次启动可能需要几秒加载资源。

操作：WASD 移动，Space 跳跃/蹬墙，Shift 空中冲刺，Ctrl 或 C 滑铲，鼠标左键攻击/施法，鼠标右键格挡/副职业动作，E 奇幻牵引，F 专注时缓，G 影刃回溯，Esc 暂停。

R6 包含两职业、三段垂直路线、现世/残世切换、墙跑→空中冲刺→再墙跑、祭坛核心构筑门禁、敌人攻击承诺、Boss 跑酷破核、短促钩锁和正式游戏音频事件。钩锁一次按键完成锁定、瞬间牵引和自动脱钩，最长约 0.5 秒，不要求松手，也不进入长时间摆荡；脱钩保留出口冲量，可接墙跑或空中冲刺。

这是按 `core-gameplay-plan-r6.md` 完成回归后的玩法导出。历史美术 QA 仍以整合工程中的 QA 记录和人工筛选状态为准，不由本 README 自动宣称美术采用。

- 文件：`release/AshenVow-Demo.exe`
- SHA-256：`C24FC8EBAE56A4211615906876AEC273090AC72CB31A6097CD03F50736D24E2E`
- PCK 内嵌标记：GDPC
- 冷启动烟测：`--audio-driver Dummy --quit-after 180`，退出码 0
