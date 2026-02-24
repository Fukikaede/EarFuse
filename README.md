# EarFuse Menubar（MVP 脚手架）

这是一个 macOS 菜单栏应用脚手架，用于实时电平监控与护耳“保险丝”应急保护。

## 当前实现范围（Milestone 1 基础）

- 菜单栏应用 + 实时 `Peak/RMS` 显示。
- `Backend A`：默认优先尝试系统输出捕获（Core Audio 输出设备回调）。
- 系统输出不可用时自动回退到输入设备（麦克风/音频接口）。
- 安全状态机（`safe/yellow/red`），采用“持续时间 + 滞回”策略。
- 菜单栏弹窗内支持 `Production/Listening` 一键切换。
- 菜单栏弹窗支持 `Capture Source` 切换（System Output / Input Device / Mock）。
- 最近 60 秒历史曲线（RMS 主线 + Peak 细线）及阈值色带。
- 保险丝引擎骨架（已抽象系统音量控制接口）。
- 事件日志持久化到本地 JSON，并显示今日/本周危险时长与最近事件。
- `Meter/Policy` 单元测试样例文件已预置。

## 构建与运行

```bash
cd /Users/kaede/Codex/earfuse-menubar
swift build
swift run EarFuseApp
```

说明：当前环境仅有 Command Line Tools。若要进行完整的 macOS App 打包、签名、权限能力配置，请在安装完整 Xcode 的机器上打开该工程。
首次启动会申请麦克风权限；未授权时不会有实时电平更新。
若系统输出捕获受系统环境限制，会自动回退到输入设备。

## 仓库结构

- `App/`：应用入口
- `MenuBarUI/`：菜单栏 Scene 与弹窗界面
- `SettingsUI/`：设置相关公共 UI 组件
- `Audio/`：采集、计量、监控服务编排
- `Core/`：策略、配置、告警、保险丝、日志、共享模型
- `Tests/UnitTests/`：单元测试样例（待完整测试环境接入）
- `docs/TechnicalDesign.md`：技术设计文档

## 下一步开发任务

1. 实现真实输出捕获后端 A（Core Audio 输出监控路径）。
2. 增加后端 B（虚拟设备）配置与兼容流程。
3. 接入本地 JSON 持久化与今日/本周统计聚合。
4. 用真实系统音量控制实现替换 `StubVolumeController`，并加入能力检测与降级策略。
