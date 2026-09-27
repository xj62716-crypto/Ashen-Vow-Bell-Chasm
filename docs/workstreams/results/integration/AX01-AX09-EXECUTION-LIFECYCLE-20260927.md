# AX01–AX09 追身与视觉残留收口记录

日期：2026-09-27。范围只覆盖当前整合工程的追身/切入处决生命周期和命中停顿，不宣称全量 R6/R7 或最终美术人工验收完成。

## 实现

- `ProfessionArts.execution_phase` 现在由 `approach → contact → recovery → idle` 驱动；公开 `execution_status()` 供 HUD、音频和实机录像读取同一权威状态。
- 目标失效、目标移位、路径遮挡和控制重置都经过 `cancel_execution(reason)`；取消会恢复入口动量、解除 `blade_approach_active`，并发出 `pursuit_cancelled`。
- `FirstPersonArms` 订阅取消事件，立即清理执行相关能力状态、刃身采样和 `ImmediateMesh`，避免取消后刀光拖留到下一次攻击。
- `PlayerCombat._physics_process()` 保持 `impact_hold` 独立递减；它不依赖下一次普攻或死亡清理。
- `blocks_primary_attack()` 在 approach/recovery 的可调解锁窗口内阻止普攻抢占，恢复结束后自动回到 idle。

## 自动运行证据

命令：

```text
godot.windows.opt.tools.64.exe --headless --audio-driver Dummy --path game --script res://tests/workstreams/gameplay/execution_lifecycle_checks.gd
```

结果：**10/10，0 失败，退出码 0**。

覆盖：命中停顿独立结束、追身进入、阶段状态、普攻抢占拒绝、遮挡取消、取消后的视图刀光清理、取消后再次追身、真实接触后的恢复和恢复解锁。

该结果证明源码生命周期契约，不替代正式关卡正常速度连续录像、关闭特效动作对比、真实音频试听或用户最终美术筛选。
