# Release r11 记录

日期：2026-09-21

## 本轮刀光调整

- `blade_arc_width`：`0.18 -> 0.065`，保留沿刀身的完整扫掠但不覆盖刀体。
- 高速宽度增益改为封顶的轻量增益，避免速度直接把光带放大到 3 倍。
- `blade_arc_emission`：`5.0 -> 2.2`，`blade_arc_opacity`：`0.95 -> 0.52`。
- 强化宽度倍率、运动 smear 和残留时间同步下调；亮脊仍位于刀身中段。

## 发布包

- 文件：`release/AshenVow-Demo.exe`
- 源码提交：`c77501b`
- 文件大小：1,509,563,840 bytes
- SHA-256：`8FD4C87C3CC323CC80D5B9EDDBDE899FA25D28E9391A263CBD1CD973EA5BCDC6`
- 尾部 `GDPC`：已检测，PCK 内嵌。
- Git LFS：待本提交推送后与 `main` 对齐。

## 验证

- `blade_feedback_checks`：41/41 通过。
- Godot 4.7.2 headless editor：退出码 0，仅有已有 MCP 6550 端口占用提示。
- 发布包冷启动：退出码 0，Vulkan Forward+ 初始化成功，stderr 为 0。
