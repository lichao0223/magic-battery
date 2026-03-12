# iPhone / Apple Watch 接入 TodoList

日期：2026-03-11

## 目标

在不破坏现有 Mac / 蓝牙设备能力的前提下，为项目增加：

- iPhone / iPad 设备模型与 UI 展示能力
- `libimobiledevice` 工具链封装
- `IOSDeviceService` 发现与电量读取主链路
- Apple Watch 经 iPhone 间接读取的接口与占位流程

## 本轮实施范围

本轮优先完成：

- [x] 补齐设备模型，支持 iPhone / iPad / Apple Watch
- [x] 给设备增加来源、外部 ID、父设备 ID、状态文案字段
- [x] 更新设备行 UI，显示连接来源和状态
- [x] 增加 iDevice 设置项
- [x] 实现 `IDeviceToolRunner`
- [x] 实现 `IDeviceParser`
- [x] 实现 `IOSDeviceService`
- [x] 将 `IOSDeviceService` 接入 `CompositeDeviceManager`
- [x] 增加本地网络 entitlement / plist 描述
- [x] 增加最基础的解析与稳定 ID 测试文件或测试占位

## 阶段拆分

### Phase 1: 模型与界面

- [x] 启用 `DeviceType.iPhone`
- [x] 启用 `DeviceType.iPad`
- [x] 启用 `DeviceType.appleWatch`
- [x] 启用对应 `DeviceIcon`
- [x] 为 `Device` 添加 `externalIdentifier`
- [x] 为 `Device` 添加 `parentExternalIdentifier`
- [x] 为 `Device` 添加 `source`
- [x] 为 `Device` 添加 `detailText`
- [x] 为 `Device` 添加 `isStale`
- [x] 更新 `DeviceRowView` 的展示文案

### Phase 2: 工具链基础设施

- [x] 新增 `IDeviceTool`
- [x] 新增 `ToolExecutionResult`
- [x] 新增 `IDeviceToolRunning` 协议
- [x] 新增 `IDeviceToolRunner`
- [x] 支持查找 bundle 内置工具路径
- [x] 支持回退到系统 PATH
- [x] 支持超时和退出码处理
- [x] 支持 stdout/stderr 捕获

### Phase 3: 解析与稳定 ID

- [x] 新增 `IDeviceInfoRecord`
- [x] 新增 `IDeviceBatteryRecord`
- [x] 新增 `WatchBatteryRecord`
- [x] 实现 `idevice_id` 输出解析
- [x] 实现 `ideviceinfo` 键值输出解析
- [x] 实现 `com.apple.mobile.battery` 解析
- [x] 实现 `comptest` 输出解析
- [x] 新增稳定设备 ID 生成工具

### Phase 4: IOSDeviceService

- [x] 新增 `IOSDeviceService`
- [x] 扫描 USB 设备
- [x] 扫描网络设备
- [x] 对 USB 设备尝试开启 Wi-Fi 连接
- [x] 读取 iPhone / iPad 基础信息
- [x] 读取 iPhone / iPad 电量
- [x] 对 iPhone 尝试读取 Apple Watch 电量
- [x] 合并设备结果并发布
- [x] 对缺失工具做优雅降级
- [x] 对失败命令做日志输出

### Phase 5: 应用接入

- [x] 将 `IOSDeviceService` 接入 `AppDelegate`
- [x] 设置页增加“Apple 设备”分组
- [x] 增加“启用 iPhone / iPad 发现”开关
- [x] 增加“启用 Apple Watch 电量读取”开关
- [x] 增加“显示离线设备最近结果”开关
- [x] 增加首次 USB 信任提示文案

### Phase 6: 工程配置

- [x] 在 entitlements 中增加网络客户端能力
- [x] 在 build settings 中增加 `NSLocalNetworkUsageDescription`
- [x] 记录外部工具尚未随 App 打包的现状

### Phase 7: 验证与收尾

- [ ] 复查模型变更对 Widget 编码是否兼容
- [ ] 复查通知逻辑对新设备类型是否兼容
- [ ] 复查排序和筛选是否可正常工作
- [x] 记录当前环境无法执行 `xcodebuild` 的限制
- [x] 更新 TodoList 完成状态

## 本轮开发策略

优先顺序：

1. 先完成 Phase 1-5 中不依赖外部二进制的部分
2. 再实现依赖二进制但可优雅降级的 `IOSDeviceService`
3. 最后补工程配置与文档说明

## 暂不做

- [ ] 随仓库提交 `libimobiledevice` 二进制
- [ ] 直接接入 `libimobiledevice` C API
- [ ] 支持直接发现附近 Apple Watch
- [ ] 支持未信任本机的 iPhone / iPad

## 当前环境限制

- `xcodebuild` 当前不可用，因为 active developer directory 指向 `CommandLineTools`
- `swiftc -typecheck` 也受当前 SDK / toolchain 不匹配影响，无法完成本地类型检查
- 因此本轮验证以源码静态复查为主，未完成真实编译运行
