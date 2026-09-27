# R7 Release Evidence

日期：2026-09-24

源工程：`demo-source`

本版修正：

- 现世专属平台切换到残世时，碰撞平台、表面和非碰撞地基一起隐藏，不再留下可见假地面。
- 残世高线踏板由同一个实体承载外观和碰撞，避免模型边缘超出承重范围。
- 移除第一关钩锁飞行线上的隐形装饰横梁。
- 钩锁按显式时间线归属判断锚点可用性，普通锚点不再受渲染节点可见性误判。
- 自动脱钩兑现锚点配置的最低抬升冲量，保持 0.5 秒上限和前向冲量。
- 第三关 Boss 出生高度同步扩建后的最终平台，破核、平台崩塌和外围路线重新绑定。

验证结果：

- `grapple_route_checks.gd`：26/26。
- `grapple_pull_checks.gd`：63/63。
- `grapple_transition_checks.gd`：16/16。
- `timeline_runtime_checks.gd`：14/14。
- `environment_integration_checks.gd`：45/45，图形模式亦通过。
- `level_route_checks.gd`：21/21。
- `level_network_checks.gd`：146/146。
- `boss_room_checks.gd`：15/15。
- `boss_mechanics_checks.gd`：72/72。
- `level_configuration_checks.gd`：97/97。
- `lifecycle_checks.gd`：24/24。
- `synergy_construct_checks.gd`：18/18。
- `presentation_checks.gd`：55/55。

SHA-256：`EDAAF24FDD70AC93C930ACAB46523FBC70B7DE537B2EDA36B3C841CB78C87B51`

PCK 内嵌标记：`GDPC`。导出期间唯一错误日志为已运行编辑器占用 MCP `127.0.0.1:6550`，导出进程退出码为 `0`。

冷启动：以 `--audio-driver Dummy --quit-after 180` 启动导出 EXE，退出码 `0`，无脚本错误。

尚未宣称完成：两职业完整人工通关录像、八构筑逐条三阶段人工验收、有限 GOAP、教学重播/跳过、全事件人工试听和最终美术验收。

## 2026-09-27 R7 状态接口收口

- `RuneCatalog.build_state()` 与 `PlayerCombat.build_state()` 统一暴露核心/扩展数量、构筑阶段、联动、缺失核心和职业资源，供 HUD、祭坛和调参读取。
- 两职业四核心的独立 stage-one 契约回归 32/32；联动 18/18、构筑与敌人 57/57、处决生命周期 10/10。
- 本次未改路线拓扑；路线仍按用户要求保留给实机跑通，发布记录不把自动契约当成人工通行证明。

## 当前发布包

- 文件：`release/AshenVow-Demo.exe`
- 源码提交：`9e06893`
- 文件大小：`1,509,667,912` bytes
- SHA-256：`1FBADF93B94EE6ABBCD99B3E4A15F34B8E7FA85A4BCBDF0D9D558C722351DDE3`
- PCK 内嵌尾标记：`GDPC`
