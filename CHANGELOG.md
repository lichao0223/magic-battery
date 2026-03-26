# Changelog

This file records notable product-facing changes for MagicBattery.
It focuses on visible features, behavior changes, fixes, and known issues.

本文档记录 MagicBattery 面向用户可感知的版本变化，重点描述功能新增、体验变化、问题修复与已知限制。

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added / 新增功能

- Battery history persistence with a 24-hour trend chart in device details.
- Custom notification sound selection and preview.
- Appearance mode setting with system / light / dark options.
- Better support for AirPods-related battery parsing scenarios.

- 新增电池历史记录能力，并在设备详情中支持 24 小时趋势图展示。
- 新增通知声音选择与预览功能。
- 新增系统 / 浅色 / 深色外观模式设置。
- 增强了 AirPods 相关电量解析场景的支持。

### Changed / 功能与体验调整

- Refreshed README screenshots and aligned product documentation with the current UI.
- Improved device details history presentation and refined recent settings interactions.

- 更新了 README 截图，并使文档内容与当前界面保持一致。
- 优化了设备详情页中的历史信息展示，并调整了近期设置项的交互体验。

### Fixed / 问题修复

- Improved local build / run portability for development environments.
- Refined AirPods-related parsing to avoid inventing missing charging case battery values.

- 改善了本地构建与运行流程的兼容性。
- 修正了 AirPods 相关解析逻辑，避免在缺失数据时错误推断充电盒电量。

### Known Issues / 已知问题

- AirPods individual earbud / charging case presentation still needs improvement in some scenarios.
- Widget performance and battery trend presentation can be further optimized.
- Data export and cloud sync are not yet available.

- 在部分场景下，AirPods 单耳 / 充电盒电量展示仍有待继续完善。
- 小组件性能与电量趋势展示仍有进一步优化空间。
- 数据导出与云同步能力尚未提供。

---

## [0.0.1] - 2026-03-05

### Added / 新增功能

- Real-time Mac battery monitoring.
- Bluetooth battery monitoring for common devices such as keyboards, mice, headphones, and AirPods.
- Menu bar status display with quick access to battery information.
- Low battery notifications with configurable threshold.
- Device list with sorting and filtering support.
- Home screen / desktop widget support in multiple sizes.

- 支持 Mac 本机电池实时监控。
- 支持常见蓝牙设备电量监控，包括键盘、鼠标、耳机和 AirPods。
- 提供菜单栏常驻入口，方便快速查看电量状态。
- 提供可配置阈值的低电量通知提醒。
- 提供支持排序与筛选的设备列表。
- 提供多尺寸电池小组件展示能力。

### Changed / 功能与体验调整

- Established the first usable product flow for battery monitoring and quick viewing.
- Consolidated battery information into a lightweight menu bar experience.

- 建立了首个可用的电量监控与查看流程。
- 将电量信息整合为轻量的菜单栏查看体验。

### Fixed / 问题修复

- Initial release; no standalone fix-only items were called out for this version.

- 初始版本发布，本版本未单独列出仅修复类事项。

### Known Issues / 已知问题

- Some Bluetooth devices may report incomplete or unavailable battery values.
- AirPods individual earbud / charging case battery details are still limited.
- The first release focuses on core usability and will continue to be refined in later versions.

- 部分蓝牙设备的电量值可能不完整，或系统无法提供。
- AirPods 单耳与充电盒电量细节支持仍然有限。
- 首个版本以“先可用”为主，后续还会继续优化体验。

---

## Version History / 版本历史

- **0.0.1** (2026-03-05) - Initial release / 首个可运行版本
