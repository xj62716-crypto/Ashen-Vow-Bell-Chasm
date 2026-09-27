# Core Gameplay Plan r6 Implementation

## 2026-09-27 AX01–AX09 追身生命周期收口

`ProfessionArts` 现在提供统一的 `approach/contact/recovery/idle` 处决阶段和取消原因；遮挡、目标失效、移位及重置都会解除追身、恢复入口动量并发出取消事件。`FirstPersonArms` 消费该事件，立即清理执行刀光采样和瞬态能力状态。`PlayerCombat.impact_hold` 独立递减，不需要下一次攻击或死亡才能结束。专项 `execution_lifecycle_checks.gd` 通过 10/10（退出码 0）。这只是 AX01–AX09 的源码生命周期证据，正式关卡连续录像、动作审美和全量 QA 仍保持未关闭。

## 2026-09-25 R7 功能优先推进：残影军势与地脉塑形首核心

连续路线专项仍有 8 项高差／反向路线失败，属于路线质量收尾项，不能标为通过；正式路线合同、关卡网络、课程和遭遇空间没有因此回退。本轮先推进策划案中会直接改变游玩行为的两个第一核心：

- `shade_echo`：冲刺开始时记录真实起点；下一次真实近战挥刀才生成 `EchoSlash`，在起点按当前伤害、范围、宽斩状态和实际视线／碰撞补斩。补斩不会移动玩家、不能递归生成残影，超出可调触发窗口会清除；复活、换职业和重置会清理记录。新增 `shade_echo_trigger_window`、`shade_echo_reach`、`shade_echo_damage_scale` 与 `echo_sweep_launched` 接口。
- `arcane_shape`：创建可承重构造的同一次施法会沿视线攻击可见普通／精英目标，先破防、击退并抬升，再按真实 `receive_hit` 结算；Boss／小 Boss 不被该第一核心直接跳过。构造的碰撞、寿命、容量和原有放置规则保持不变，新增 `shape_attack` 事件和既有技能特效触发。

Godot 4.7.2 编辑器解析通过；新增专项 `shade_echo_checks.gd` 为 5/5，`shape_attack_checks.gd` 为 4/4；既有 `builds_ai_checks.gd` 回归为 57/57。以上是受控物理检查，不替代两职业正式关卡连续实机录像，也不代表 R7 八主题三阶段、五组联动或发布门禁已完成。

## 2026-09-25 继续推进：HUD 信息压缩

针对“UI 文字解释太多、削弱暗黑奇幻感”的实机反馈，正式 HUD 的路线教学和 Boss 状态已改为短状态标签：

- 教学只保留输入与动作关系，例如 `贴墙 · Shift`、`蹬墙 · 换侧`、`V · 残世`、`E · 牵引`。
- Boss HUD 保留破核数量、可伤窗口和地台崩塌倒计时，去掉重复的解释句。
- 目标提示保留祭坛、核心、出口和破核状态，不改动玩法门槛、输入映射或碰撞。

本轮通过 `git diff --check`；Godot 实机验证尚未完成，不能将 UI 人工观感标为完成。

随后补齐了阶段 2 的双向墙跑连接：现世保留连续承重点，残世使用偏移短墙作为替代路线；首个锻炉接收平台增加真实制动纵深。当前源码回归追加通过：`level_network_checks.gd` 146/146、`timeline_threat_checks.gd` 11/11、`level_configuration_checks.gd` 97/97、`gameplay_audio_checks.gd` 22/22、`synergy_construct_checks.gd` 18/18、`lifecycle_checks.gd` 24/24、`grapple_pull_checks.gd` 63/63、`grapple_transition_checks.gd` 16/16、`timeline_runtime_checks.gd` 14/14。

这些是自动和受控物理回归，不替代两职业三关连续人工通关；新导出包会保留这一发布边界。

日期：2026-09-23
范围：阶段 A/B 的第一批源工程实现。没有导出 EXE。

## 已接入

- `TimelineRuntime` 作为正式关卡实例的单一时间线控制器。默认 `V` 单击切换现世/残世，切换消耗独立相位资源，不改写玩家坐标、速度、重力、冲刺、墙跑段数或相机。
- 三段正式关卡都加入真实残世墙面；第一段额外加入残世路线敌人。残世表面有独立碰撞，现世中同时隐藏并停用；切换回现世后碰撞和 AI 一起关闭。
- 现世/残世切换改变正式场景的环境光、雾和辉光参数。两条线共用建筑骨架，但路线实体和敌人状态不同。
- 影刃/咒行者共享“流势”接口：墙跑、滑铲跳、冲刺和有效命中产生流势，落地衰减；流势达到阈值的影刃攻击可破开普通守卫，击杀/移动继续返还路线资源。数值留在 `PlayerCombat` 导出接口。
- HUD 显示当前时间线、相位充能和专注状态；专注激活时增加明确的“专注 · 时流减速”状态文字与克制的角标符纹。
- 时间线切换、移动/击杀返还和检查点重置都绑定正式 `MovementTrial` 生命周期。

## 实际验证

| 检查 | 结果 |
| --- | --- |
| `timeline_runtime_checks.gd` | 12/12 |
| `movement_temporal_checks.gd` | 41/41 |
| `grapple_transition_checks.gd` | 16/16 |
| `synergy_construct_checks.gd` | 18/18 |
| `boss_room_checks.gd` | 15/15 |
| `environment_integration_checks.gd` | 30/30 |
| Godot 4.7.2 editor parse/import | 通过；仅已有 MCP 6550 端口占用提示 |

验证覆盖真实场景实例、正式房间生命周期、实际碰撞层、玩家状态保留和专注清理；静态节点数量没有作为完成依据。

## R6 之外的人工验收边界

- r6 的 90 秒完整人工连续录像和人工手感验收。
- 两时间线完整关卡拓扑、独占机关、全部八构筑三阶段、有限 GOAP、Boss 全阶段路线、教学重播、动态音乐和发布前完整清单。
- 这些是完整 Q01-Q83 与主观人工验收的边界；本轮 R6 源码回归和 R6 EXE 导出已在下方收口记录中完成。

## 2026-09-23 收口记录

本轮按 `core-gameplay-plan-r6.md` 完成源码整合与发布前回归。关键修正包括：

- 同墙／异墙的墙跑→空中冲刺→再墙跑共用空中段数预算，专注返还按单调递增的墙跑计数处理。
- Boss 进入距离与核心支撑面修正，核心位于跑酷攻击面前侧；影刃高速移动时的攻击可以兑现为短程刀波。
- 正式第一关敌人统一由 `LevelRunConfiguration` 生成，残世敌人通过配置元数据标记，避免重复生成。
- 敌方首次攻击预警只在原有延迟存在时补偿，不给真实输入和测试额外阻塞。
- 生命周期夹具按正式流程先完成职业核心构筑，再验证出口开启、暂停恢复和无隐形碰撞；没有放宽正式出口门槛。

本轮实际回归：核心玩法 20 组全部通过；level 7 组全部通过（236、21、154、16、97、12、26 项）；音频实机 22/22；Godot 4.7.2 编辑器导入和脚本检查通过。唯一日志是已有 MCP `127.0.0.1:6550` 被其他编辑器占用，不影响游戏脚本或导出。

本次 EXE 是 R6 源码整合包，发布文件和校验见 `release/AshenVow-Demo.exe`、`release/README.md` 及 `release/R6-RELEASE.md`。它记录的是 R6 玩法收口结果；人物、武器、敌人和材质的下一轮高精度美术返工仍由 Astra 决定是否介入，不属于本轮逻辑实现前置。

## 2026-09-24 R7 修正与策划覆盖

本轮修复了两项会直接破坏正式路线的问题：残世切换后，现世专属平台的非碰撞地基仍可见，形成“看似地面、实际落空”的假表面；现世装饰架还生成了一根没有可见模型的碰撞横梁，阻断第一关主钩锁飞行。现在现世平台、表面和地基按同一相位隐藏，残世高线踏板由同一个 `StaticBody3D` 同时承载外观和碰撞；装饰架不再生成隐形阻挡。钩锁只按显式时间线归属过滤目标，普通锚点不再受渲染节点可见性误判，自动脱钩会兑现锚点配置的最低抬升冲量。

第三关最终平台在路线扩建时下调 1 米，Boss 配置仍保留旧高度。本轮同步默认/变体配置到 `y=9.04`，Boss 本体、核心路线与可崩塌中心平台重新绑定。

| 策划阶段 | 当前状态 | 仍未关闭 |
| --- | --- | --- |
| A 核心循环骨架 | 已接入流势、移动攻击条件、击杀/移动返还、三关高/中/低路线与真实移动门 | 缺两职业 90 秒连续人工录像，不能宣称“所有遭遇均杜绝走地平A” |
| B 双时间线和资源 | 已实现实体路线切换、相位/专注独立资源、状态保留、三关结构与光照差异、相位锚点 | 每关独占机关、敌人弱点与风险收益仍未全部人工验证 |
| C 敌人与 Boss | 六职责敌人、普通/精英/小 Boss/大 Boss、攻击前摇与有限威胁租约已接入；Boss 跑酷破核、崩塌和外围路线通过回归 | 策划指定的有限 GOAP 目标选择尚未完整实现；缺完整 Boss 人工流程录像 |
| D 八构筑与祭坛 | 两职业八核心方向、构筑联动、动作/武器/路线槽 UI 与行为合同已接入 | 八条构筑都达到“基础→核心→关键联动”的路线质变和逐条人工验收尚未完成 |
| E 教学、音频、画面与发布 | 动态分层音乐、动作音频事件、相位/专注/Boss/祭坛 HUD 已接入 | 教学重播/跳过、全事件人工试听、两职业菜单到结算长流程与最终美术验收未完成 |

本轮回归：`grapple_route_checks` 26/26、`grapple_pull_checks` 63/63、`grapple_transition_checks` 16/16、`timeline_runtime_checks` 14/14、`environment_integration_checks` 45/45（图形模式亦通过）、`level_route_checks` 21/21、`level_network_checks` 146/146、`boss_room_checks` 15/15、`boss_mechanics_checks` 72/72、`level_configuration_checks` 97/97、`lifecycle_checks` 24/24、`synergy_construct_checks` 18/18、`presentation_checks` 55/55。

## 2026-09-25 R8 发布

候选导出包 `builds/windows/AshenVow-Demo-r8.exe` 已完成冷启动烟测并复制为 `release/AshenVow-Demo.exe`。命令为 `--audio-driver Dummy --quit-after 180`，退出码 0；启动日志无 `SCRIPT ERROR` 或资源导入错误。发布包 PCK 已内嵌（文件尾标记 `GDPC`），SHA-256 为 `182BF6581207D86661A4B44CD3BC0F9A3D15C249203522415508CD6A1E459DBE`。自动回归通过项与人工验收边界见 `release/R8-RELEASE.md`；本次发布不把尚未完成的连续人工通关、八构筑完整循环、GOAP、教学重播/跳过、全事件试听和最终美术审美验收标记为完成。

## 2026-09-25 R7 route follow-up

R7 路线与敌人时间线合同已在同一整合工作树中完成：`r7_route_contract_checks` 77/77、`level_network_checks` 30/30、`level_encounter_spatial_checks` 26/26、`level_course_checks` 16/16。旧 `level_configuration_checks` 因高模重复重建超过 600 秒，未计入通过；这批源码也没有导出新的 EXE。当前结论只覆盖路线/分配和相关自动回归，不覆盖连续人工通关、八构筑完整循环、最终美术和全量发布门禁。

为降低无窗口回归的重复成本，`CombatRoom._build()` 现在只在非 headless 窗口执行环境合批；headless 保留同一原始网格与碰撞。该保护已在上述四套 R7 回归中通过，不改变正式窗口渲染路径。
