# iPhone / Apple Watch 发现与电量获取设计方案

日期：2026-03-11

## 1. 背景

当前项目已经支持：

- Mac 本机电池读取
- 已连接蓝牙外设的发现与部分电量读取

当前项目尚未支持：

- iPhone / iPad 的发现与电量读取
- Apple Watch 的发现与电量读取

结合 AirBattery 的公开实现和 `libimobiledevice` 的能力，可以确认这条能力链路是可行的，但必须明确边界：

- 可行的是“发现已经与本机建立信任关系，并且当前可达的 iPhone / iPad”
- 可行的是“通过已发现的 iPhone，间接读取其配对 Apple Watch 的电量”
- 不可承诺的是“直接发现附近任意陌生 iPhone / Apple Watch 并读取电量”

这份文档的目标，是为当前仓库补充一份可实施的详细设计，指导后续实现 `IOSDeviceService` 及其相关 UI、权限和分发改造。

## 2. 调研结论

### 2.1 AirBattery 的实际实现路径

AirBattery 并不是通过纯 Wi-Fi 扫描“附近 Apple 设备”来拿电量，而是使用两条不同链路：

- iPhone / iPad：
  - 通过 `libimobiledevice` 的 `idevice_id -n` 枚举可通过网络访问的已配对设备
  - 通过 `idevice_id -l` 枚举 USB 连接的设备
  - 对 USB 发现的设备调用自定义 `wificonnection`，开启 `EnableWifiConnections`
  - 再通过 `ideviceinfo` 和 `com.apple.mobile.battery` 读取设备名称、型号、电量、充电状态
- Apple Watch：
  - 不直接扫描手表
  - 先发现一个已配对、可达的 iPhone
  - 通过 `companion_proxy` 拿到该 iPhone 关联的手表信息
  - 再通过 `diagnostics_relay` 读取手表的 `BatteryCurrentCapacity` 与 `BatteryIsCharging`

### 2.2 对“附近”的精确定义

后续产品与文档里不能继续使用模糊的“获取附近 iPhone / Apple Watch”表述，建议改成：

- iPhone / iPad：发现“已信任且当前可达”的设备
- Apple Watch：读取“已发现 iPhone 所配对手表”的电量
- 蓝牙方案：只作为补充发现信号，不作为 Watch 电量主链路

### 2.3 技术可行性判断

可行性矩阵如下：

| 能力 | 可行性 | 说明 |
| --- | --- | --- |
| 通过 USB 发现 iPhone / iPad | 高 | `libimobiledevice` 已成熟 |
| 通过同局域网发现已配对 iPhone / iPad | 高 | 依赖设备已信任本机且启用 Wi-Fi 连接 |
| 读取 iPhone / iPad 电量 | 高 | 通过 `com.apple.mobile.battery` |
| 读取配对 Apple Watch 电量 | 中高 | 依赖 `companion_proxy` + `diagnostics_relay` |
| 直接发现附近 Apple Watch | 低 | 无公开稳定路径，不纳入目标 |
| 发现未配对陌生 iPhone 并读取电量 | 低 | 不可行，不纳入目标 |

## 3. 目标与非目标

### 3.1 目标

本方案目标：

- 在当前 macOS 菜单栏应用中增加 `iPhone / iPad` 设备源
- 在满足条件时增加 `Apple Watch` 电量展示
- 保持现有 `DeviceManager` / `CompositeDeviceManager` 结构不被破坏
- 在 UI 中清楚表达“需要先 USB 信任一次”和“Watch 通过 iPhone 间接获取”
- 在权限、日志、失败状态、分发方式上可操作

### 3.2 非目标

本方案不做：

- 直接通过 Wi-Fi 扫描所有局域网 Apple 设备
- 直接通过蓝牙读取 Apple Watch 电量
- 支持未信任本机的 iPhone / iPad
- 支持 App Store 分发作为首要目标
- 支持历史电量曲线和跨设备同步

## 4. 当前工程约束

当前工程约束如下：

- 现有设备模型仍未启用 `iPhone / iPad / appleWatch` 类型
- `CompositeDeviceManager` 已具备并行聚合多个设备源的能力
- 工程已开启 App Sandbox，但当前 entitlement 只有蓝牙设备能力
- `Info.plist` 尚未声明本地网络用途说明
- 权限管理器当前仅覆盖通知、蓝牙、辅助功能

这些约束意味着后续实现必须同时处理：

- 模型扩展
- 新服务接入
- App Sandbox 网络能力补齐
- 设置页与权限提示补齐

## 5. 总体设计

### 5.1 设计原则

- 先做可证明有效的最小闭环，再做“更优雅”的 API 封装
- 先保证 iPhone / iPad 通路稳定，再接入 Apple Watch
- 避免一开始就把所有能力混进 `BluetoothDeviceService`
- 外部工具调用、输出解析、缓存、设备映射要分层
- 明确区分“可发现”“可读取电量”“可读取 Watch”三个状态

### 5.2 推荐实现路线

推荐采用“两层架构”：

- 上层：Swift 原生服务层，负责调度、缓存、模型映射、错误处理、UI 状态
- 下层：先使用捆绑在 App 内的 `libimobiledevice` 工具链，后续再视需要迁移到直接 C API 集成

推荐原因：

- 与 AirBattery 的已验证路径一致，最容易先跑通
- 避免首版就处理 Swift-C Bridge、静态/动态库打包、头文件暴露等复杂度
- CLI 输出虽然较脆弱，但足以完成 PoC 与第一版产品

不推荐首版直接做 Swift 对 `libimobiledevice` C API 直连，原因是：

- 引入成本高
- 签名、打包、架构兼容和调试成本更高
- 当前项目还处于功能扩展期，先验证产品闭环更重要

## 6. 新增模块设计

### 6.1 服务层新增模块

建议新增以下模块：

- `IOSDeviceService`
  - 负责 iPhone / iPad 发现、电量读取、Watch 间接读取
- `IDeviceToolRunner`
  - 对 `Process` 调用做统一封装
  - 负责超时、日志、退出码和标准输出采集
- `IDeviceParser`
  - 解析 `idevice_id`、`ideviceinfo`、`comptest` 输出
- `IDeviceCapabilityStore`
  - 缓存每个 UDID 的连接能力与最近结果
- `IDeviceBootstrapService`
  - 在 USB 已连接时尝试开启 `EnableWifiConnections`

### 6.2 模块职责边界

`IOSDeviceService` 不应直接拼接命令文本和解析字符串，建议职责如下：

- 调度扫描流程
- 管理刷新周期
- 维护设备状态缓存
- 生成统一 `Device`
- 将结果发布给 `CompositeDeviceManager`

`IDeviceToolRunner` 负责：

- 执行 `idevice_id`
- 执行 `ideviceinfo`
- 执行 `wificonnection`
- 执行 `comptest`
- 输出结构化执行结果

`IDeviceParser` 负责：

- 将文本输出转成结构体
- 屏蔽 CLI 文本格式变化的影响
- 做字段缺失和异常容错

## 7. 数据模型改造

### 7.1 DeviceType 扩展

需要启用当前被注释的类型：

- `iPhone`
- `iPad`
- `appleWatch`

### 7.2 Device 模型补充字段

当前 `Device` 只有统一的 `UUID` 标识，不足以表达外部设备关系。建议新增以下字段：

```swift
enum DeviceSource: String, Codable {
    case mac
    case bluetooth
    case libimobiledeviceUSB
    case libimobiledeviceNetwork
    case companionProxy
}

enum DeviceAvailability: String, Codable {
    case online
    case stale
    case unavailable
    case needsTrust
}
```

建议在 `Device` 中补充：

- `externalIdentifier: String?`
  - iPhone / iPad / Watch 使用 UDID 或稳定外部 ID
- `parentExternalIdentifier: String?`
  - Watch 指向所属 iPhone
- `source: DeviceSource`
- `availability: DeviceAvailability`
- `detailText: String?`
  - 用于显示“需 USB 配对一次”“已离线，显示上次结果”等信息

如果不希望立即破坏现有模型，也可以在首版先保守增加：

- `externalIdentifier`
- `source`

其余状态先放在服务层内部，待 UI 确认后再升到模型。

### 7.3 稳定 ID 策略

当前项目大量逻辑依赖 `UUID`。对外部设备建议使用“稳定输入生成 UUID”的方式避免列表抖动：

- iPhone / iPad：`UUIDv5("idevice:<udid>")`
- Watch：`UUIDv5("watch:<watch_udid>")`
- 如暂时无法拿到 Watch UDID，则使用 `UUIDv5("watch:<parent_udid>:<watch_name>")`

这样可以兼容现有 `Identifiable` UI 结构，同时避免每次刷新都生成新 `UUID()`。

## 8. 工具链设计

### 8.1 首版依赖的 CLI

首版建议打包以下工具：

- `idevice_id`
- `ideviceinfo`
- `wificonnection`
- `comptest`

说明：

- `idevice_id`
  - `-l` 枚举 USB 设备
  - `-n` 枚举网络设备
- `ideviceinfo`
  - 读取设备基本信息
  - 读取 `com.apple.mobile.battery`
- `wificonnection`
  - 开启设备的 `EnableWifiConnections`
- `comptest`
  - 读取已配对 Apple Watch 信息和电量

### 8.2 目录建议

建议在工程内增加资源目录：

```text
battery/Resources/libimobiledevice/bin/
```

将外部二进制集中放置，避免散落在多个 target 中。

### 8.3 ToolRunner 接口建议

```swift
struct ToolExecutionResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: TimeInterval
}

protocol IDeviceToolRunning {
    func run(_ tool: IDeviceTool, arguments: [String], timeout: TimeInterval) async -> Result<ToolExecutionResult, Error>
}
```

这样后续可以：

- 单元测试中注入 mock runner
- 切换为直接 C API 实现时不影响上层服务逻辑

## 9. 设备发现与刷新流程

### 9.1 刷新总流程

每轮刷新建议流程如下：

1. 执行 `idevice_id -l`，获取 USB 连接设备列表
2. 对每个 USB 设备执行一次 `wificonnection -u <udid> true`
3. 执行 `idevice_id -n`，获取网络可达设备列表
4. 合并 USB 和网络结果，建立每台设备的最佳连接方式
5. 对每个设备执行 `ideviceinfo` 读取基础信息与电量
6. 若设备类型为 `iPhone`，尝试执行 `comptest` 获取 Watch
7. 生成 `Device` 列表并发布
8. 对本轮未出现但历史存在的设备标记为 `stale` 或清理

### 9.2 连接方式优先级

同一台设备可能同时通过 USB 和网络可达，建议优先级如下：

1. USB
2. Network
3. Bluetooth hint only

原因：

- USB 通路更稳定
- USB 通常更适合做首次 bootstrap
- Apple Watch 的读取也更依赖完整可信通路

### 9.3 刷新频率

建议默认刷新频率：

- `IOSDeviceService`：60 秒
- 设置页手动刷新：即时
- App 激活或菜单打开时：触发一次轻量刷新

不建议跟蓝牙扫描共用 30 秒高频策略，原因：

- `ideviceinfo` 和 `comptest` 的进程成本更高
- 网络设备存在可达性波动，高频调用更容易造成噪声日志

### 9.4 缓存策略

建议缓存以下内容：

- 最近一次 `idevice_id -n` 结果
- UDID -> 设备名称/型号/类型
- UDID -> 最近电量
- UDID -> 最近成功连接方式
- iPhone UDID -> Watch 信息

缓存有效期建议：

- 设备元数据：24 小时
- 电量数据：2 分钟
- Watch 映射：24 小时

## 10. Apple Watch 读取设计

### 10.1 Watch 读取前提

只有满足以下条件时才尝试读取 Watch：

- 父设备是 `iPhone`
- iPhone 当前可通过 USB 或网络通路访问
- iPhone 与 Mac 已建立信任

以下场景不尝试：

- 设备仅通过蓝牙广播被识别
- 设备类型为 iPad
- iPhone 电量读取本身失败

### 10.2 Watch 设备呈现模型

建议将 Watch 作为独立 `Device` 放入列表，而不是嵌入在 iPhone 行内，仅通过 `parentExternalIdentifier` 建立归属关系。

好处：

- 兼容当前扁平列表 UI
- 后续支持排序、筛选、通知更简单
- Widget 与菜单栏共享同一套数据结构

### 10.3 失败行为

如果 iPhone 可用但 Watch 读取失败：

- iPhone 仍正常显示
- 不生成 Watch 设备，或将历史 Watch 标记为 `stale`
- 调试日志中保留失败原因
- 设置页可展示“当前 iPhone 未返回 Watch 信息”

## 11. UI 与交互设计

### 11.1 设置页新增项

建议在设置页增加一个新分组：`Apple 设备`

包含以下开关和说明：

- `启用 iPhone / iPad 发现`
- `启用 Apple Watch 电量读取`
- `优先通过网络连接已配对设备`
- `显示离线设备的最近一次结果`

说明文案建议：

- “iPhone / iPad 需要先通过数据线连接并信任此 Mac 一次”
- “Apple Watch 电量通过其配对 iPhone 间接读取”
- “局域网读取需要设备与 Mac 处于同一网络中”

### 11.2 设备状态提示

建议在设备行增加状态文案，优先使用短文本：

- `USB`
- `网络`
- `通过 iPhone`
- `需信任`
- `已离线`

### 11.3 首次引导

如果用户启用了该功能但尚未发现任何 iPhone / iPad，建议在设置页展示 3 步引导：

1. 用数据线连接 iPhone / iPad
2. 在设备上点击“信任此电脑”
3. 保持 Mac 与设备处于同一局域网

## 12. 权限、沙盒与分发

### 12.1 App Sandbox 改造

当前 target 已启用 App Sandbox，但尚未声明网络客户端能力。需要增加：

- `com.apple.security.network.client`

是否需要 `network.server`：

- 当前设计不需要
- 除非未来增加 Nearcast 或本地广播能力

### 12.2 Info.plist 改造

建议增加：

- `NSLocalNetworkUsageDescription`

文案建议：

- “需要访问本地网络以发现已配对的 iPhone、iPad 并读取其电量信息”

当前阶段不计划增加 `NSBonjourServices`，因为方案不依赖 Bonjour 服务发现。

### 12.3 分发风险

需要明确：

- `libimobiledevice` 和 `companion_proxy` 相关方案更适合独立分发
- 不应默认以 Mac App Store 兼容为目标
- 外部二进制需要统一签名、校验、随 App 一起打包

### 12.4 授权与许可证

需要在仓库和应用关于页中明确第三方依赖：

- `libimobiledevice`
- `libplist`
- `usbmuxd`
- `comptest` 来源

首版实现前应完成一次许可证清点，确认：

- 可否直接打包二进制
- 是否需要附带许可证文本
- 是否需要提供源码获取路径

## 13. 错误处理与可观测性

### 13.1 错误分类

建议将错误分为：

- `toolMissing`
- `toolExecutionFailed`
- `deviceNotTrusted`
- `deviceOffline`
- `wifiConnectionEnableFailed`
- `batteryServiceUnavailable`
- `watchLookupFailed`
- `parseFailed`

### 13.2 日志策略

Debug 日志建议记录：

- 执行了哪个工具
- 参数摘要
- 耗时
- 退出码
- 解析失败原因

Release 日志仅保留摘要：

- 本轮发现设备数量
- 成功数量 / 失败数量
- 首个关键失败原因

### 13.3 用户可见反馈

用户侧不应看到底层错误码，建议映射为：

- “设备尚未信任此 Mac”
- “设备当前不在同一网络中”
- “无法读取 Apple Watch 信息”
- “辅助组件缺失或损坏”

## 14. 测试方案

### 14.1 单元测试

建议补充以下测试：

- `idevice_id` 输出解析
- `ideviceinfo` 基本信息解析
- `com.apple.mobile.battery` 输出解析
- `comptest` Watch 输出解析
- 稳定 ID 生成测试
- 设备合并与去重测试

### 14.2 集成测试

建议准备 4 类手工验证设备：

- 仅 USB 连接的 iPhone
- 已启用 Wi-Fi 连接的 iPhone
- 同局域网 iPad
- 已配对 Apple Watch 的 iPhone

### 14.3 回归测试重点

需要重点回归：

- `CompositeDeviceManager` 聚合后列表是否抖动
- 菜单栏排序是否合理
- Widget 是否能显示新设备类型
- 低电量通知是否会误报 Watch

## 15. 分阶段实施计划

### Phase A：设计与基础改造

- 启用 `DeviceType` 中的 `iPhone / iPad / appleWatch`
- 为 `Device` 增加稳定外部标识字段
- 在设置页预留 Apple 设备分组

### Phase B：iPhone / iPad MVP

- 增加 `IOSDeviceService`
- 打包 `idevice_id`、`ideviceinfo`、`wificonnection`
- 跑通 USB 与网络发现
- 展示 iPhone / iPad 电量和连接来源

### Phase C：Apple Watch

- 打包 `comptest` 或等价 helper
- 通过已发现 iPhone 间接读取 Watch
- 在 UI 中显示父子关系与错误状态

### Phase D：产品化收尾

- 补齐设置文案与引导
- 增加错误提示与诊断日志
- 完成许可证与签名整理
- 验证打包、运行、升级兼容性

## 16. 实现建议与取舍

### 16.1 推荐先做的版本

推荐先做：

- `iPhone / iPad over USB + Wi-Fi`
- 不做 Watch UI 分组，只先扁平展示
- 不做直连 C API
- 不做“蓝牙发现 iPhone 后再补电量”的混合策略

这是风险最低、收益最高的第一步。

### 16.2 暂不建议做的版本

暂不建议：

- 把所有逻辑直接塞进 `BluetoothDeviceService`
- 首版就引入直接链接 `libimobiledevice` 动态库
- 在未明确许可证与签名策略前直接提交二进制到仓库

## 17. 开放问题

在真正编码前，还需要确认以下问题：

1. `libimobiledevice` 工具链是直接随仓库提交，还是走下载脚本生成
2. `comptest` 是直接复用现有公开实现，还是自己编译并固化版本
3. `Device` 模型是否一次性补全 `source/availability/parentExternalIdentifier`
4. 是否允许显示最近一次离线设备结果
5. 产品是否接受“需要先插线信任一次”的前提文案

## 18. 结论

基于当前调研，项目完全可以增加 iPhone / iPad 电量读取能力，并在此基础上间接支持 Apple Watch。

最重要的产品边界有两条：

- 这不是“扫描附近所有 Apple 设备”的能力，而是“访问已信任且当前可达的设备”
- Apple Watch 不是独立发现，而是“依附于已发现 iPhone 的伴生读取”

因此，建议后续实现顺序明确固定为：

1. 先完成 `IOSDeviceService` 和工具链封装
2. 先跑通 iPhone / iPad
3. 再接入 Watch
4. 最后处理设置、文案、签名和许可证

## 19. 参考资料

- AirBattery README
  - https://github.com/lihaoyun6/AirBattery/blob/main/README.md
- AirBattery `IDeviceBattery.swift`
  - https://github.com/lihaoyun6/AirBattery/blob/main/AirBattery/BatteryInfo/IDeviceBattery.swift
- AirBattery `wificonnection.c`
  - https://github.com/lihaoyun6/AirBattery/blob/main/AirBattery/libimobiledevice/bin/wificonnection.c
- `comptest` 公开实现
  - https://gist.github.com/nikias/ebc6e975dc908f3741af0f789c5b1088
- `libimobiledevice` 项目
  - https://github.com/libimobiledevice/libimobiledevice
