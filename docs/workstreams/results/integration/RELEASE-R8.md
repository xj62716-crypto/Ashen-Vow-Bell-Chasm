# Release r8 记录

日期：2026-09-21

## 本批修复

- 正式运行适配器 `game/viewmodel_r16/arms.gd` 的刀光参数提高宽度、寿命、亮度和边缘发光；`blade_arc_r3.gdshader` 改为加法混合并提高核心/外缘不透明度。
- 正式命中特效 `game/viewmodel_r16/blade_impact.gd` 与 `blade_contact_mist.gdshader` 改为亮红加法混合血雾，扩大尺寸并延长扩散；碎片仍保留为受力方向提示。
- `player_controller.gd` 在空中切换到不同墙面时重置当前墙跑段数和墙面计时；同一表面再次附着仍受段数限制，落地仍完整重置。
- 旧 `scripts/player/first_person_arms.gd` 的备用刀光带也修复了 ImmediateMesh 的 surface 结束位置，避免兼容路径生成断裂带。

## 发布包

`release/AshenVow-Demo.exe`

- 单文件，PCK 内嵌：文件尾部检测到 `GDPC`。
- SHA256：`0BAD854B71D99D24BF0825FB1C2559DF738421F78C5F468E63F7DA4845A122F3`。
- Git 通过 LFS 跟踪 `release/*.exe`；索引保存指针，工作区保留完整 1.5 GB EXE，避免普通 Git 对象超过远程限制。
- Godot 4.7.2 Windows Desktop 导出成功。
- 以 `--headless --quit-after 180` 启动发布包，退出码 0。
- 墙跑物理回归 `26/26` 通过；刀光/命中特效回归 `41/41` 通过，包含可配置血雾寿命。

README 与 EXE 已放在同一 `release/` 目录；构建缓存仍在被 Git 忽略的 `builds/`。

## 验证边界

静态导入与导出烟测通过。当前工作树的 Godot MCP 6550 端口被已有编辑器占用，因此命令行日志中的 MCP socket 报错不代表脚本解析失败；本批尚未把主观美术验收写成自动通过，需在发布包内实际挥刀和命中观察刀光、血雾的可读性。
