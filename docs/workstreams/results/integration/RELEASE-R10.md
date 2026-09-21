# Release r10 记录

日期：2026-09-21

## 发布包

- 文件：`release/AshenVow-Demo.exe`
- 源码提交：`7b1dbfa`（墙跑空中换墙与整段刀身扫掠修复）
- 文件大小：1,509,563,920 bytes
- SHA-256：`C1AB5BC923C6ED341F664D17349ECE75B61A47CF919384781131CD1B97BA57C2`
- 尾部 `GDPC`：已检测，PCK 内嵌；`release/` 不需要额外 `.pck` 文件。
- Git LFS：EXE 指针已更新并推送到 GitHub `main`。

## 发布烟测

命令：`AshenVow-Demo.exe --audio-driver Dummy --quit-after 180`

- 退出码：0
- Vulkan Forward+ 初始化成功，设备为 NVIDIA GeForce RTX 3060 Laptop GPU。
- 进程退出时 Godot 报告 18 个 ObjectDB 泄漏和 4 个资源仍在使用；不影响启动和退出码，但保留在 `release/startup-r10.err.log` 供后续清理。

本包与提交 `7b1dbfa` 对齐；整合 worktree 中未提交的关卡实验改动没有混入该发布包。
