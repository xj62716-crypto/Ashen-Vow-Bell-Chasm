# Release r9 记录

日期：2026-09-21

## 本轮修复

- `player_controller.gd` 增加公开的 `wall_jump_transfer_window`（默认 0.5 秒）。蹬墙后的短窗口只允许接入不同墙面，解决同墙两段后空中跳向另一墙被正面接近条件拒绝的问题；同墙段数和落地重置规则保持不变。
- `viewmodel_r16/arms.gd` 将刀光从刀尖偏置改为整段 `edge_root → edge_tip` 的时间 × 刀身扫掠面，长度采样从 4 段提高到 8 段；备用带状路径也覆盖完整刃长。
- `blade_arc_r3.gdshader` 将亮脊移到刀身中段并放宽主体 alpha，保留加法混合和现有可调接口。
- 新增 `docs/design/core-gameplay-plan-r3.md`，明确换墙、锚点地形联动、Boss 跑酷核心、八构筑质变和下一批验收顺序。

## 验证

- Godot 4.7.2 `--headless --editor --quit`：退出码 0；仅有已有 MCP 6550 端口占用提示。
- `wall_chain_checks`：26/26 通过。
- `blade_feedback_checks`：41/41 通过。
- `git diff --check`：通过。

整合套件中仍有历史环境、敌人和关卡生命周期失败；它们不属于本轮修改，未被改写为通过。本轮没有重新导出 EXE，正式导出仍需两职业连续流程与人工实机画面确认。
