# R6 Release Evidence

日期：2026-09-23

源工程：`demo-source` at the export commit recorded by Git.

导出命令：

```powershell
godot --headless --path game --export-release "Windows Desktop" release/AshenVow-Demo.exe
```

本版新增：

- 相位资源、冷却和“独立于时流”提示。
- 独立时流/专注状态、时流回响、耗尽和复归提示。
- 影刃锋势、咒行者流势/法力、技能就绪和当前技能行为反馈。
- 钩锁命中、短促牵引、牵引兑现、落点确认以及击杀资源返还反馈。
- 墙跑、滑铲跳、相位返还通知。
- Boss 阶段、核心目标和破核提示；整合 HUD 避免与旧 HUD 重复。
- 祭坛动作槽、武器槽、路线槽，及基础/核心/核心联动/关键联动、移动要求、攻击条件、资源返还和路线收益。

验证结果：

- timeline runtime：12/12。
- focus binding：40/40。
- presentation：55/55。
- refit altar：52/52。
- boss mechanics：72/72。
- lifecycle：24/24。
- `git diff --check` 和 Godot 4.7.2 编辑器/脚本解析通过；仅有已有 MCP 6550 端口占用提示。
- 发布包冷启动以 Dummy audio 和 `--quit-after 180` 验证，退出码 0。

已知旧基线问题：

- `boss_room_checks.gd` 的 `priest and encounter origin follow expanded final district`、`formal tower binds its actual central platform` 仍失败；随后测试脚本因 `_bridge` 为 null 中断。
- `grapple_route_checks.gd` 第一关的 `class 0 auto-detaches and physically lands across authored void`、`class 1 auto-detaches and physically lands across authored void` 仍失败；阶段 2 短牵引路线通过。

SHA-256：`A669D0BA5ABC093AC4D38C51FB496CEE672BE0D461A36D18774D49D35D9E186E`

PCK 内嵌标记：`GDPC` 已在发布文件中确认。

冷启动烟测：退出码 `0`；Godot 启动日志无脚本错误。
