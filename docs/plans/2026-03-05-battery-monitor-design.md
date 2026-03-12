# macOS 电量监控应用设计方案

日期：2026-03-05

## 1. 目标与范围

**目标：** 开发一个常驻菜单栏与小组件的 macOS 应用，用于展示附近 Apple 设备与已配对蓝牙设备的电量，并在低电量时发送系统通知。

**范围（全功能版）：**
- Apple 设备：iPhone / iPad / Apple Watch / AirPods
- 蓝牙设备：键盘 / 鼠标 / 耳机等
- 展示位置：菜单栏 + 小组件
- 界面风格：现代简约 + 毛玻璃 + 中文显示
- 提醒方式：系统通知
- 不记录历史数据（仅显示当前电量）

## 2. 架构设计

采用 **MVVM + 服务层** 的分层架构：

```
BatteryMonitor (macOS App)
├── UI Layer (SwiftUI)
│   ├── MenuBarView - 菜单栏弹出窗口
│   ├── WidgetView - 桌面小组件
│   └── SettingsView - 设置界面
│
├── ViewModel Layer
│   └── DeviceListViewModel - 统一管理所有设备状态
│
├── Service Layer (设备管理)
│   ├── DeviceManager (协议) - 设备抽象接口
│   ├── MacBatteryService - Mac 本机电池 (IOKit)
│   ├── BluetoothDeviceService - 标准蓝牙设备 (IOBluetooth)
│   ├── iOSDeviceService - iPhone/iPad (libimobiledevice)
│   └── AirPodsService - AirPods/Watch (蓝牙包解析)
│
└── Core Layer
    ├── Device (模型) - 统一设备数据结构
    ├── NotificationManager - 低电量通知
    └── PermissionManager - 蓝牙/网络权限管理
```

**关键设计原则：**
- 设备抽象统一（`DeviceManager` 协议）
- 模块独立初始化，互不影响
- 权限失败时优雅降级

## 3. 数据模型与抽象

### 统一设备模型

```swift
struct Device: Identifiable {
    let id: UUID
    let name: String              // "iPhone 15 Pro"
    let type: DeviceType          // .iPhone, .airPods, .keyboard
    let batteryLevel: Int         // 0-100
    let isCharging: Bool
    let lastUpdated: Date
    let icon: DeviceIcon          // 设备图标枚举
}
```

### 设备类型

```swift
enum DeviceType {
    case mac, iPhone, iPad, appleWatch
    case airPods, airPodsLeft, airPodsRight, airPodsCase
    case bluetoothKeyboard, bluetoothMouse, bluetoothHeadphone
}
```

### DeviceManager 协议

```swift
protocol DeviceManager {
    var devices: Published<[Device]> { get }
    func startMonitoring() async throws
    func stopMonitoring()
    var isAvailable: Bool { get }
}
```

## 4. UI 设计（现代简约 + 毛玻璃）

### 菜单栏
- 极简图标（默认电池图标）
- 有低电量设备时变红色
- 点击展开中文列表

**示例结构：**
```
电量监控

📱 iPhone 15 Pro      85%
⌚ Apple Watch         42%
🎧 AirPods Pro        78%
   ├─ 左耳            75%
   ├─ 右耳            80%
   └─ 充电盒          78%
⌨️  妙控键盘           65%
💻 MacBook Pro        92% ⚡

⚙️ 设置
❌ 退出
```

### 小组件
- **小尺寸**：最重要 2-3 设备
- **中尺寸**：所有设备网格显示
- **大尺寸**：预留趋势图（后续可选）

### 视觉风格
- **毛玻璃背景**：`.ultraThinMaterial` / `.regularMaterial`
- **半透明层次**：背景虚化，内容清晰
- **圆角卡片**：12pt 圆角 + 轻阴影
- **动态颜色**：绿色/默认色/红色电量分级

## 5. 技术实现方案（分阶段）

### Phase 1（MVP）
- Mac 本机电池（IOKit）
- 标准蓝牙设备电量（IOBluetooth）
- 基础 UI：菜单栏 + 小组件

### Phase 2（中级）
- iPhone / iPad（libimobiledevice）
- USB 首次配对 + WiFi 发现

### Phase 3（高级）
- AirPods / Apple Watch（蓝牙包解析）
- 解析 Apple 私有广播数据

## 6. 关键技术细节

### Mac 本机电池（IOKit）
- `IOPSCopyPowerSourcesInfo()`
- `IOPSCopyPowerSourcesList()`

### 蓝牙设备（IOBluetooth）
- `IOBluetoothDevice.pairedDevices()`
- `device.batteryLevel`（支持的设备）

### iPhone / iPad（libimobiledevice）
- `idevicepair pair`
- `ideviceinfo -k BatteryCurrentCapacity`

### AirPods（蓝牙包解析）
- CoreBluetooth 扫描广播包
- 解析 Apple Manufacturer Data

## 7. 错误处理与降级

- 权限拒绝：显示提示，功能降级
- 设备离线：显示灰色状态
- libimobiledevice 未安装：提供安装引导
- AirPods 解析失败：显示已连接但未知电量

## 8. 通知系统

- 使用 `UNUserNotificationCenter`
- 设备低于阈值时发送通知

## 9. 性能与刷新策略

- 默认 60 秒刷新
- 后台降低频率
- 菜单打开时即时刷新
- 5 秒缓存避免重复查询

---

**已确认需求：**
- 使用场景：日常监控（常驻后台）
- 菜单栏：极简图标 + 点击展开
- 支持小组件
- 全功能设备支持
- 提醒方式：系统通知
- 风格：现代简约 + 毛玻璃 + 中文
- 不记录历史数据
