# Release r12 记录

日期：2026-09-22

## 本轮内容

- 保留并整合上一版之后的 14 个关卡、Boss、环境、钩锁、回溯和存档工作区改动。
- 拱门立柱回收到路线平台中心线，修正斜向窄平台的视觉支撑与碰撞支撑不一致。
- 刀光亮度小幅提升：`blade_arc_emission 2.2 -> 2.45`、`blade_arc_opacity .52 -> .56`；宽度、寿命和真实刀身扫掠几何保持不变。
- 刀光外缘与影刃四条构筑联动：残影、弹反、滑铲、飞檐分别读取构筑色，并由就绪状态提供轻微脉冲。
- 第一人称命中血雾和旧战斗血雾统一为暗酒红/褐红、低发光材质，避免鲜红覆盖刀身。

## 验证

- Godot 4.7.2 导入：通过。
- `blade_feedback_checks`：41/41 通过。
- `build_appearance_checks`：44/44 通过。
- `enemy_hit_event_checks`：43/43 通过。
- `environment_integration_checks`：30/30 通过。
- `boss_route_checks`：8/8 通过。
- `boss_room_checks`：15/15 通过。
- `grapple_transition_checks`：16/16 通过。
- `level_route_checks`：21/21 通过。
- 发布包冷启动：退出码 0，stderr 0 字节。

完整回归仍记录了若干既有移动、敌人 AI、焦点退款、钩锁删除锚点和关卡配置类失败；这些失败不由本轮刀光、血雾或环境支撑改动引入，未被改写为通过。

## 发布包

- 文件：`release/AshenVow-Demo.exe`
- 源码提交：`7caf1fe`
- 文件大小：1,509,578,688 bytes
- SHA-256：`936D4DA5A6A5C608FABE67059EE3C7570D940E215D15FABCB442707D2BBF92C6`
- 尾部 `GDPC`：已检测，PCK 内嵌。
- Git LFS：随本次整合提交推送到 `main`。
