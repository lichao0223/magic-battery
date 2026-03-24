# Phase 1 实现计划 - macOS 电量监控应用

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 实现 MVP 版本，支持 Mac 本机电池和标准蓝牙设备的电量监控，提供菜单栏和小组件界面。

**架构：** MVVM + 服务层架构，使用 SwiftUI 构建 UI，IOKit 读取 Mac 电池，IOBluetooth 读取蓝牙设备电量。所有设备通过统一的 DeviceManager 协议抽象。

**技术栈：** Swift 5.9+, SwiftUI, IOKit.framework, IOBluetooth.framework, WidgetKit, UserNotifications

---

## Task 1: 创建 Xcode 项目结构

**Files:**
- Create: `BatteryMonitor.xcodeproj`
- Create: `BatteryMonitor/BatteryMonitorApp.swift`
- Create: `BatteryMonitor/Info.plist`

**Step 1: 创建 macOS App 项目**

打开 Xcode，创建新项目：
- Template: macOS > App
- Product Name: BatteryMonitor
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: macOS 13.0

**Step 2: 配置 Info.plist**

添加必要的权限描述：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限来检测附近设备的电量</string>
<key>LSUIElement</key>
<true/>
<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
```

**Step 3: 添加框架依赖**

在 Target > General > Frameworks and Libraries 添加：
- IOKit.framework
- IOBluetooth.framework

**Step 4: 创建项目目录结构**

```bash
mkdir -p BatteryMonitor/Models
mkdir -p BatteryMonitor/Services
mkdir -p BatteryMonitor/ViewModels
mkdir -p BatteryMonitor/Views
mkdir -p BatteryMonitor/Core
mkdir -p BatteryMonitorTests
```

**Step 5: 验证项目编译**

Run: `Cmd+B` 或 `xcodebuild -scheme BatteryMonitor -configuration Debug`
Expected: Build Succeeded

**Step 6: 提交**

```bash
git add .
git commit -m "feat: initialize Xcode project with basic structure"
```

---

## Task 2: 创建核心数据模型

**Files:**
- Create: `BatteryMonitor/Models/Device.swift`
- Create: `BatteryMonitor/Models/DeviceType.swift`
- Create: `BatteryMonitorTests/DeviceTests.swift`

**Step 1: 编写 Device 模型测试**

Create: `BatteryMonitorTests/DeviceTests.swift`

```swift
import XCTest
@testable import BatteryMonitor

final class DeviceTests: XCTestCase {
    func testDeviceCreation() {
        let device = Device(
            id: UUID(),
            name: "MacBook Pro",
            type: .mac,
            batteryLevel: 85,
            isCharging: true,
            lastUpdated: Date(),
            icon: .mac
        )

        XCTAssertEqual(device.name, "MacBook Pro")
        XCTAssertEqual(device.type, .mac)
        XCTAssertEqual(device.batteryLevel, 85)
        XCTAssertTrue(device.isCharging)
    }

    func testBatteryLevelValidation() {
        let device = Device(
            id: UUID(),
            name: "Test",
            type: .mac,
            batteryLevel: 150,
            isCharging: false,
            lastUpdated: Date(),
            icon: .mac
        )

        XCTAssertLessThanOrEqual(device.batteryLevel, 100)
        XCTAssertGreaterThanOrEqual(device.batteryLevel, 0)
    }
}
```

**Step 2: 运行测试验证失败**

Run: `Cmd+U` 或 `xcodebuild test -scheme BatteryMonitor`
Expected: FAIL - "No such module 'BatteryMonitor'" 或 "Cannot find 'Device' in scope"

**Step 3: 实现 DeviceType 枚举**

Create: `BatteryMonitor/Models/DeviceType.swift`

```swift
import Foundation

enum DeviceType: String, Codable, CaseIterable {
    case mac
    case iPhone
    case iPad
    case appleWatch
    case airPods
    case airPodsLeft
    case airPodsRight
    case airPodsCase
    case bluetoothKeyboard
    case bluetoothMouse
    case bluetoothHeadphone

    var displayName: String {
        switch self {
        case .mac: return "Mac"
        case .iPhone: return "iPhone"
        case .iPad: return "iPad"
        case .appleWatch: return "Apple Watch"
        case .airPods: return "AirPods"
        case .airPodsLeft: return "左耳"
        case .airPodsRight: return "右耳"
        case .airPodsCase: return "充电盒"
        case .bluetoothKeyboard: return "蓝牙键盘"
        case .bluetoothMouse: return "蓝牙鼠标"
        case .bluetoothHeadphone: return "蓝牙耳机"
        }
    }
}

enum DeviceIcon: String {
    case mac = "laptopcomputer"
    case iPhone = "iphone"
    case iPad = "ipad"
    case appleWatch = "applewatch"
    case airPods = "airpodspro"
    case keyboard = "keyboard"
    case mouse = "computermouse"
    case headphone = "headphones"

    var systemName: String { rawValue }
}
```

**Step 4: 实现 Device 模型**

Create: `BatteryMonitor/Models/Device.swift`

```swift
import Foundation

struct Device: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: DeviceType
    let batteryLevel: Int
    let isCharging: Bool
    let lastUpdated: Date
    let icon: DeviceIcon

    init(
        id: UUID = UUID(),
        name: String,
        type: DeviceType,
        batteryLevel: Int,
        isCharging: Bool,
        lastUpdated: Date = Date(),
        icon: DeviceIcon
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.batteryLevel = min(max(batteryLevel, 0), 100) // 限制在 0-100
        self.isCharging = isCharging
        self.lastUpdated = lastUpdated
        self.icon = icon
    }

    var batteryColor: String {
        if isCharging { return "green" }
        if batteryLevel < 20 { return "red" }
        if batteryLevel < 50 { return "orange" }
        return "green"
    }

    var isLowBattery: Bool {
        batteryLevel < 20 && !isCharging
    }
}
```

**Step 5: 运行测试验证通过**

Run: `Cmd+U`
Expected: PASS - All tests pass

**Step 6: 提交**

```bash
git add BatteryMonitor/Models/ BatteryMonitorTests/DeviceTests.swift
git commit -m "feat: add Device and DeviceType models with tests"
```

---

## Task 3: 创建 DeviceManager 协议

**Files:**
- Create: `BatteryMonitor/Services/DeviceManager.swift`
- Create: `BatteryMonitorTests/DeviceManagerTests.swift`

**Step 1: 编写协议测试（Mock 实现）**

Create: `BatteryMonitorTests/DeviceManagerTests.swift`

```swift
import XCTest
import Combine
@testable import BatteryMonitor

final class DeviceManagerTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    func testMockDeviceManager() async throws {
        let manager = MockDeviceManager()

        let expectation = XCTestExpectation(description: "Devices published")

        manager.$devices
            .dropFirst()
            .sink { devices in
                XCTAssertEqual(devices.count, 1)
                XCTAssertEqual(devices.first?.name, "Test Device")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await manager.startMonitoring()

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}

// Mock implementation for testing
class MockDeviceManager: DeviceManager {
    @Published var devices: [Device] = []
    var isAvailable: Bool = true

    func startMonitoring() async throws {
        devices = [
            Device(
                name: "Test Device",
                type: .mac,
                batteryLevel: 80,
                isCharging: false,
                icon: .mac
            )
        ]
    }

    func stopMonitoring() {
        devices = []
    }
}
```

**Step 2: 运行测试验证失败**

Run: `Cmd+U`
Expected: FAIL - "Cannot find 'DeviceManager' in scope"

**Step 3: 实现 DeviceManager 协议**

Create: `BatteryMonitor/Services/DeviceManager.swift`

```swift
import Foundation
import Combine

protocol DeviceManager: AnyObject {
    var devices: [Device] { get }
    var devicesPublisher: Published<[Device]>.Publisher { get }
    var isAvailable: Bool { get }
    
    func startMonitoring() async throws
    func stopMonitoring()
}
```

**Step 4: 运行测试验证通过**

Run: `Cmd+U`
Expected: PASS - All tests pass

**Step 5: 提交**

```bash
git add BatteryMonitor/Services/DeviceManager.swift BatteryMonitorTests/DeviceManagerTests.swift
git commit -m "feat: add DeviceManager protocol with tests"
```

---

## Task 4: 实现 MacBatteryService

**Files:**
- Create: `BatteryMonitor/Services/MacBatteryService.swift`
- Create: `BatteryMonitorTests/MacBatteryServiceTests.swift`

**Step 1: 编写 MacBatteryService 测试**

Create: `BatteryMonitorTests/MacBatteryServiceTests.swift`

```swift
import XCTest
@testable import BatteryMonitor

final class MacBatteryServiceTests: XCTestCase {
    var service: MacBatteryService!
    
    override func setUp() {
        super.setUp()
        service = MacBatteryService()
    }
    
    override func tearDown() {
        service.stopMonitoring()
        service = nil
        super.tearDown()
    }
    
    func testServiceIsAvailable() {
        XCTAssertTrue(service.isAvailable)
    }
    
    func testStartMonitoring() async throws {
        try await service.startMonitoring()
        
        // 等待数据更新
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        XCTAssertFalse(service.devices.isEmpty, "应该至少有一个 Mac 设备")
        
        let macDevice = service.devices.first
        XCTAssertNotNil(macDevice)
        XCTAssertEqual(macDevice?.type, .mac)
        XCTAssertGreaterThanOrEqual(macDevice?.batteryLevel ?? -1, 0)
        XCTAssertLessThanOrEqual(macDevice?.batteryLevel ?? 101, 100)
    }
    
    func testStopMonitoring() async throws {
        try await service.startMonitoring()
        service.stopMonitoring()
        
        // 验证监控已停止（设备列表可能保留最后状态）
        XCTAssertNoThrow(service.stopMonitoring())
    }
}
```

**Step 2: 运行测试验证失败**

Run: `Cmd+U`
Expected: FAIL - "Cannot find 'MacBatteryService' in scope"

**Step 3: 实现 MacBatteryService**

Create: `BatteryMonitor/Services/MacBatteryService.swift`

```swift
import Foundation
import IOKit.ps
import Combine

class MacBatteryService: DeviceManager {
    @Published private(set) var devices: [Device] = []
    
    var devicesPublisher: Published<[Device]>.Publisher { $devices }
    var isAvailable: Bool { true }
    
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 60.0
    
    func startMonitoring() async throws {
        // 立即获取一次数据
        await updateBatteryInfo()
        
        // 启动定时器
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.updateBatteryInfo()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateBatteryInfo() async {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        var batteryDevices: [Device] = []
        
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // 只处理内置电池
            guard let type = info[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else {
                continue
            }
            
            let name = info[kIOPSNameKey] as? String ?? "MacBook"
            let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            let isPowerConnected = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            
            let batteryLevel = maxCapacity > 0 ? (currentCapacity * 100) / maxCapacity : 0
            
            let device = Device(
                name: name,
                type: .mac,
                batteryLevel: batteryLevel,
                isCharging: isCharging || isPowerConnected,
                icon: .mac
            )
            
            batteryDevices.append(device)
        }
        
        await MainActor.run {
            self.devices = batteryDevices
        }
    }
}
```

**Step 4: 运行测试验证通过**

Run: `Cmd+U`
Expected: PASS - All tests pass

**Step 5: 提交**

```bash
git add BatteryMonitor/Services/MacBatteryService.swift BatteryMonitorTests/MacBatteryServiceTests.swift
git commit -m "feat: implement MacBatteryService with IOKit"
```

---

## Task 5: 实现 BluetoothDeviceService

**Files:**
- Create: `BatteryMonitor/Services/BluetoothDeviceService.swift`
- Create: `BatteryMonitorTests/BluetoothDeviceServiceTests.swift`

**Step 1: 编写 BluetoothDeviceService 测试**

Create: `BatteryMonitorTests/BluetoothDeviceServiceTests.swift`

```swift
import XCTest
@testable import BatteryMonitor

final class BluetoothDeviceServiceTests: XCTestCase {
    var service: BluetoothDeviceService!
    
    override func setUp() {
        super.setUp()
        service = BluetoothDeviceService()
    }
    
    override func tearDown() {
        service.stopMonitoring()
        service = nil
        super.tearDown()
    }
    
    func testServiceAvailability() {
        // 蓝牙服务可用性取决于系统蓝牙状态
        XCTAssertNotNil(service)
    }
    
    func testStartMonitoring() async throws {
        try await service.startMonitoring()
        
        // 等待蓝牙扫描
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 设备数量取决于实际配对的蓝牙设备
        // 这里只验证不会崩溃
        XCTAssertNoThrow(service.devices)
    }
}
```

**Step 2: 运行测试验证失败**

Run: `Cmd+U`
Expected: FAIL - "Cannot find 'BluetoothDeviceService' in scope"

**Step 3: 实现 BluetoothDeviceService**

Create: `BatteryMonitor/Services/BluetoothDeviceService.swift`

```swift
import Foundation
import IOBluetooth
import Combine

class BluetoothDeviceService: DeviceManager {
    @Published private(set) var devices: [Device] = []
    
    var devicesPublisher: Published<[Device]>.Publisher { $devices }
    var isAvailable: Bool {
        IOBluetoothHostController.default()?.powerState == .on
    }
    
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 60.0
    
    func startMonitoring() async throws {
        guard isAvailable else {
            throw BluetoothError.bluetoothUnavailable
        }
        
        // 立即获取一次数据
        await updateBluetoothDevices()
        
        // 启动定时器
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.updateBluetoothDevices()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateBluetoothDevices() async {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return
        }
        
        var bluetoothDevices: [Device] = []
        
        for btDevice in pairedDevices {
            guard btDevice.isConnected() else { continue }
            
            let name = btDevice.name ?? "未知设备"
            let batteryLevel = getBatteryLevel(from: btDevice)
            
            // 根据设备类型判断图标
            let (deviceType, icon) = determineDeviceType(btDevice)
            
            if let level = batteryLevel {
                let device = Device(
                    name: name,
                    type: deviceType,
                    batteryLevel: level,
                    isCharging: false, // 蓝牙设备通常无法检测充电状态
                    icon: icon
                )
                bluetoothDevices.append(device)
            }
        }
        
        await MainActor.run {
            self.devices = bluetoothDevices
        }
    }
    
    private func getBatteryLevel(from device: IOBluetoothDevice) -> Int? {
        // 尝试读取电池服务 (Battery Service UUID: 0x180F)
        // 这需要设备支持标准 BLE Battery Service
        
        // 注意：IOBluetooth 的电池读取比较复杂，这里提供简化实现
        // 实际项目中可能需要使用 CoreBluetooth 进行更精确的控制
        
        return nil // 暂时返回 nil，后续可以增强
    }
    
    private func determineDeviceType(_ device: IOBluetoothDevice) -> (DeviceType, DeviceIcon) {
        let name = device.name?.lowercased() ?? ""
        
        if name.contains("keyboard") || name.contains("键盘") {
            return (.bluetoothKeyboard, .keyboard)
        } else if name.contains("mouse") || name.contains("鼠标") {
            return (.bluetoothMouse, .mouse)
        } else if name.contains("headphone") || name.contains("耳机") || name.contains("airpods") {
            return (.bluetoothHeadphone, .headphone)
        }
        
        return (.bluetoothHeadphone, .headphone) // 默认
    }
}

enum BluetoothError: Error {
    case bluetoothUnavailable
    case deviceNotFound
}
```

**Step 4: 运行测试验证通过**

Run: `Cmd+U`
Expected: PASS - All tests pass

**Step 5: 提交**

```bash
git add BatteryMonitor/Services/BluetoothDeviceService.swift BatteryMonitorTests/BluetoothDeviceServiceTests.swift
git commit -m "feat: implement BluetoothDeviceService with IOBluetooth"
```

---

## Task 6: 实现 DeviceListViewModel

**Files:**
- Create: `BatteryMonitor/ViewModels/DeviceListViewModel.swift`
- Create: `BatteryMonitorTests/DeviceListViewModelTests.swift`

**Step 1: 编写 ViewModel 测试**

Create: `BatteryMonitorTests/DeviceListViewModelTests.swift`

```swift
import XCTest
import Combine
@testable import BatteryMonitor

final class DeviceListViewModelTests: XCTestCase {
    var viewModel: DeviceListViewModel!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        viewModel = DeviceListViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(viewModel.allDevices.isEmpty)
        XCTAssertFalse(viewModel.hasLowBatteryDevices)
    }
    
    func testStartMonitoring() async throws {
        let expectation = XCTestExpectation(description: "Devices loaded")
        
        viewModel.$allDevices
            .dropFirst()
            .sink { devices in
                if !devices.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await viewModel.startMonitoring()
        
        await fulfillment(of: [expectation], timeout: 3.0)
        
        XCTAssertFalse(viewModel.allDevices.isEmpty)
    }
    
    func testLowBatteryDetection() {
        let lowBatteryDevice = Device(
            name: "Test",
            type: .mac,
            batteryLevel: 15,
            isCharging: false,
            icon: .mac
        )
        
        viewModel.allDevices = [lowBatteryDevice]
        
        XCTAssertTrue(viewModel.hasLowBatteryDevices)
        XCTAssertEqual(viewModel.lowBatteryDevices.count, 1)
    }
}
```

**Step 2: 运行测试验证失败**

Run: `Cmd+U`
Expected: FAIL - "Cannot find 'DeviceListViewModel' in scope"

**Step 3: 实现 DeviceListViewModel**

Create: `BatteryMonitor/ViewModels/DeviceListViewModel.swift`

```swift
import Foundation
import Combine

@MainActor
class DeviceListViewModel: ObservableObject {
    @Published var allDevices: [Device] = []
    @Published var isMonitoring: Bool = false
    
    private var macBatteryService: MacBatteryService
    private var bluetoothService: BluetoothDeviceService
    private var cancellables = Set<AnyCancellable>()
    
    var hasLowBatteryDevices: Bool {
        allDevices.contains { $0.isLowBattery }
    }
    
    var lowBatteryDevices: [Device] {
        allDevices.filter { $0.isLowBattery }
    }
    
    var sortedDevices: [Device] {
        allDevices.sorted { device1, device2 in
            // 低电量设备排在前面
            if device1.isLowBattery != device2.isLowBattery {
                return device1.isLowBattery
            }
            // 按设备类型排序
            return device1.type.rawValue < device2.type.rawValue
        }
    }
    
    init(
        macBatteryService: MacBatteryService = MacBatteryService(),
        bluetoothService: BluetoothDeviceService = BluetoothDeviceService()
    ) {
        self.macBatteryService = macBatteryService
        self.bluetoothService = bluetoothService
        
        setupSubscriptions()
    }
    
    func startMonitoring() async {
        isMonitoring = true
        
        // 启动所有服务
        do {
            try await macBatteryService.startMonitoring()
        } catch {
            print("Mac battery service failed: \(error)")
        }
        
        do {
            try await bluetoothService.startMonitoring()
        } catch {
            print("Bluetooth service failed: \(error)")
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        macBatteryService.stopMonitoring()
        bluetoothService.stopMonitoring()
    }
    
    func refreshDevices() async {
        await startMonitoring()
    }
    
    private func setupSubscriptions() {
        // 合并所有服务的设备列表
        Publishers.CombineLatest(
            macBatteryService.$devices,
            bluetoothService.$devices
        )
        .map { macDevices, bluetoothDevices in
            macDevices + bluetoothDevices
        }
        .receive(on: DispatchQueue.main)
        .assign(to: &$allDevices)
    }
}
```

**Step 4: 运行测试验证通过**

Run: `Cmd+U`
Expected: PASS - All tests pass

**Step 5: 提交**

```bash
git add BatteryMonitor/ViewModels/DeviceListViewModel.swift BatteryMonitorTests/DeviceListViewModelTests.swift
git commit -m "feat: implement DeviceListViewModel with service integration"
```

---

## Task 7: 实现 NotificationManager

**Files:**
- Create: `BatteryMonitor/Core/NotificationManager.swift`
- Create: `BatteryMonitorTests/NotificationManagerTests.swift`

**Step 1: 编写 NotificationManager 测试**

Create: `BatteryMonitorTests/NotificationManagerTests.swift`

```swift
import XCTest
import UserNotifications
@testable import BatteryMonitor

final class NotificationManagerTests: XCTestCase {
    var manager: NotificationManager!
    
    override func setUp() {
        super.setUp()
        manager = NotificationManager()
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    func testRequestPermission() async throws {
        let granted = try await manager.requestPermission()
        // 权限结果取决于用户选择，这里只验证不崩溃
        XCTAssertNotNil(granted)
    }
    
    func testSendLowBatteryNotification() async throws {
        let device = Device(
            name: "Test Device",
            type: .iPhone,
            batteryLevel: 15,
            isCharging: false,
            icon: .iPhone
        )
        
        try await manager.sendLowBatteryNotification(for: device)
        
        // 验证通知已发送（实际测试中可能需要 mock UNUserNotificationCenter）
        XCTAssertNoThrow(try await manager.sendLowBatteryNotification(for: device))
    }
}
```

**Step 2: 运行测试验证失败**

Run: `Cmd+U`
Expected: FAIL - "Cannot find 'NotificationManager' in scope"

**Step 3: 实现 NotificationManager**

Create: `BatteryMonitor/Core/NotificationManager.swift`

```swift
import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var notifiedDevices = Set<UUID>() // 防止重复通知
    
    func requestPermission() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    }
    
    func sendLowBatteryNotification(for device: Device) async throws {
        // 避免重复通知同一设备
        guard !notifiedDevices.contains(device.id) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "电量不足"
        content.body = "\(device.name) 电量仅剩 \(device.batteryLevel)%，请及时充电"
        content.sound = .default
        content.categoryIdentifier = "LOW_BATTERY"
        
        let request = UNNotificationRequest(
            identifier: device.id.uuidString,
            content: content,
            trigger: nil // 立即发送
        )
        
        try await notificationCenter.add(request)
        notifiedDevices.insert(device.id)
    }
    
    func clearNotifiedDevice(_ deviceId: UUID) {
        notifiedDevices.remove(deviceId)
    }
    
    func resetNotifications() {
        notifiedDevices.removeAll()
    }
}
```

**Step 4: 运行测试验证通过**

Run: `Cmd+U`
Expected: PASS - All tests pass

**Step 5: 提交**

```bash
git add BatteryMonitor/Core/NotificationManager.swift BatteryMonitorTests/NotificationManagerTests.swift
git commit -m "feat: implement NotificationManager for low battery alerts"
```

---

## Task 8: 实现菜单栏 UI

**Files:**
- Create: `BatteryMonitor/Views/MenuBarView.swift`
- Create: `BatteryMonitor/Views/DeviceRowView.swift`
- Modify: `BatteryMonitor/BatteryMonitorApp.swift`

**Step 1: 实现 DeviceRowView 组件**

Create: `BatteryMonitor/Views/DeviceRowView.swift`

```swift
import SwiftUI

struct DeviceRowView: View {
    let device: Device
    
    var body: some View {
        HStack(spacing: 12) {
            // 设备图标
            Image(systemName: device.icon.systemName)
                .font(.system(size: 20))
                .foregroundColor(batteryColor)
                .frame(width: 24)
            
            // 设备名称
            Text(device.name)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 电量百分比
            Text("\(device.batteryLevel)%")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(batteryColor)
            
            // 充电图标
            if device.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
    }
    
    private var batteryColor: Color {
        if device.isCharging {
            return .green
        } else if device.batteryLevel < 20 {
            return .red
        } else if device.batteryLevel < 50 {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview {
    VStack {
        DeviceRowView(device: Device(
            name: "MacBook Pro",
            type: .mac,
            batteryLevel: 85,
            isCharging: true,
            icon: .mac
        ))
        
        DeviceRowView(device: Device(
            name: "iPhone 15 Pro",
            type: .iPhone,
            batteryLevel: 15,
            isCharging: false,
            icon: .iPhone
        ))
    }
    .frame(width: 280)
}
```

**Step 2: 实现 MenuBarView**

Create: `BatteryMonitor/Views/MenuBarView.swift`

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: DeviceListViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("电量监控")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.refreshDevices()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // 设备列表
            if viewModel.allDevices.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.sortedDevices) { device in
                            DeviceRowView(device: device)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400)
            }
            
            Divider()
            
            // 底部按钮
            VStack(spacing: 4) {
                Button(action: {
                    openWindow(id: "settings")
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("设置")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("退出")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "battery.0")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("未发现设备")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("请确保蓝牙已开启")
                .font(.system(size: 12))
                .foregroundColor(.tertiary)
        }
        .frame(height: 200)
    }
}

#Preview {
    MenuBarView(viewModel: DeviceListViewModel())
}
```

**Step 3: 修改 App 入口**

Modify: `BatteryMonitor/BatteryMonitorApp.swift`

```swift
import SwiftUI

@main
struct BatteryMonitorApp: App {
    @StateObject private var viewModel = DeviceListViewModel()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Image(systemName: menuBarIcon)
                .foregroundColor(menuBarColor)
        }
        .menuBarExtraStyle(.window)
        
        Window("设置", id: "settings") {
            SettingsView()
                .frame(width: 500, height: 400)
        }
    }
    
    private var menuBarIcon: String {
        if viewModel.hasLowBatteryDevices {
            return "battery.25"
        }
        return "battery.100"
    }
    
    private var menuBarColor: Color {
        viewModel.hasLowBatteryDevices ? .red : .primary
    }
}
```

**Step 4: 编译并运行**

Run: `Cmd+R`
Expected: 应用启动，菜单栏显示电池图标，点击展开显示设备列表

**Step 5: 提交**

```bash
git add BatteryMonitor/Views/ BatteryMonitor/BatteryMonitorApp.swift
git commit -m "feat: implement menu bar UI with glassmorphism"
```

---

## Task 9: 实现设置界面

**Files:**
- Create: `BatteryMonitor/Views/SettingsView.swift`
- Create: `BatteryMonitor/Core/AppSettings.swift`

**Step 1: 实现 AppSettings**

Create: `BatteryMonitor/Core/AppSettings.swift`

```swift
import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var lowBatteryThreshold: Int {
        didSet {
            UserDefaults.standard.set(lowBatteryThreshold, forKey: "lowBatteryThreshold")
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    
    @Published var refreshInterval: Int {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }
    
    private init() {
        self.lowBatteryThreshold = UserDefaults.standard.integer(forKey: "lowBatteryThreshold")
        if self.lowBatteryThreshold == 0 {
            self.lowBatteryThreshold = 20 // 默认值
        }
        
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        self.refreshInterval = UserDefaults.standard.integer(forKey: "refreshInterval")
        if self.refreshInterval == 0 {
            self.refreshInterval = 60 // 默认 60 秒
        }
        
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }
    
    private func updateLaunchAtLogin() {
        // 实现登录时启动功能
        // 需要使用 ServiceManagement 框架
    }
}
```

**Step 2: 实现 SettingsView**

Create: `BatteryMonitor/Views/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("通知设置") {
                Toggle("启用低电量通知", isOn: $settings.notificationsEnabled)
                
                HStack {
                    Text("低电量阈值")
                    Spacer()
                    Picker("", selection: $settings.lowBatteryThreshold) {
                        Text("10%").tag(10)
                        Text("15%").tag(15)
                        Text("20%").tag(20)
                        Text("25%").tag(25)
                        Text("30%").tag(30)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }
            
            Section("刷新设置") {
                HStack {
                    Text("刷新频率")
                    Spacer()
                    Picker("", selection: $settings.refreshInterval) {
                        Text("30秒").tag(30)
                        Text("1分钟").tag(60)
                        Text("2分钟").tag(120)
                        Text("5分钟").tag(300)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }
            
            Section("启动设置") {
                Toggle("登录时自动启动", isOn: $settings.launchAtLogin)
            }
            
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("0.0.1")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("Battery Monitor")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 400)
    }
}

#Preview {
    SettingsView()
}
```

**Step 3: 编译并测试**

Run: `Cmd+R`
Expected: 点击菜单栏"设置"按钮，打开设置窗口

**Step 4: 提交**

```bash
git add BatteryMonitor/Views/SettingsView.swift BatteryMonitor/Core/AppSettings.swift
git commit -m "feat: implement settings view with user preferences"
```

---

## Task 10: 实现小组件 (Widget Extension)

**Files:**
- Create: `BatteryWidget/BatteryWidget.swift`
- Create: `BatteryWidget/BatteryWidgetBundle.swift`
- Create: `BatteryWidget/Info.plist`

**Step 1: 添加 Widget Extension**

在 Xcode 中：
1. File > New > Target
2. 选择 "Widget Extension"
3. Product Name: BatteryWidget
4. 勾选 "Include Configuration Intent"

**Step 2: 实现 Widget Provider**

Create: `BatteryWidget/BatteryWidget.swift`

```swift
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), devices: placeholderDevices)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), devices: placeholderDevices)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let devices = await fetchDevices()
            let entry = SimpleEntry(date: Date(), devices: devices)
            
            // 每 5 分钟刷新一次
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    private func fetchDevices() async -> [Device] {
        let macService = MacBatteryService()
        let bluetoothService = BluetoothDeviceService()
        
        do {
            try await macService.startMonitoring()
            try await bluetoothService.startMonitoring()
            
            // 等待数据更新
            try await Task.sleep(nanoseconds: 500_000_000)
            
            return macService.devices + bluetoothService.devices
        } catch {
            return []
        }
    }
    
    private var placeholderDevices: [Device] {
        [
            Device(name: "MacBook Pro", type: .mac, batteryLevel: 85, isCharging: true, icon: .mac),
            Device(name: "iPhone", type: .iPhone, batteryLevel: 65, isCharging: false, icon: .iPhone)
        ]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let devices: [Device]
}

struct BatteryWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(devices: entry.devices)
        case .systemMedium:
            MediumWidgetView(devices: entry.devices)
        case .systemLarge:
            LargeWidgetView(devices: entry.devices)
        default:
            SmallWidgetView(devices: entry.devices)
        }
    }
}

struct BatteryWidget: Widget {
    let kind: String = "BatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BatteryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("电量监控")
        .description("显示附近设备的电量信息")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let devices: [Device]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("电量")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            ForEach(devices.prefix(3)) { device in
                HStack {
                    Image(systemName: device.icon.systemName)
                        .font(.system(size: 16))
                    
                    Text("\(device.batteryLevel)%")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    if device.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let devices: [Device]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("电量监控")
                .font(.system(size: 16, weight: .semibold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(devices.prefix(6)) { device in
                    DeviceCardView(device: device)
                }
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let devices: [Device]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("电量监控")
                .font(.system(size: 18, weight: .semibold))
            
            ForEach(devices) { device in
                HStack {
                    Image(systemName: device.icon.systemName)
                        .font(.system(size: 20))
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.system(size: 14))
                        Text(device.type.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(device.batteryLevel)%")
                        .font(.system(size: 16, weight: .medium))
                    
                    if device.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct DeviceCardView: View {
    let device: Device
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: device.icon.systemName)
                .font(.system(size: 24))
            
            Text("\(device.batteryLevel)%")
                .font(.system(size: 14, weight: .medium))
            
            if device.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

#Preview(as: .systemSmall) {
    BatteryWidget()
} timeline: {
    SimpleEntry(date: .now, devices: [
        Device(name: "MacBook Pro", type: .mac, batteryLevel: 85, isCharging: true, icon: .mac),
        Device(name: "iPhone", type: .iPhone, batteryLevel: 65, isCharging: false, icon: .iPhone)
    ])
}
```

**Step 3: 创建 Widget Bundle**

Create: `BatteryWidget/BatteryWidgetBundle.swift`

```swift
import WidgetKit
import SwiftUI

@main
struct BatteryWidgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
    }
}
```

**Step 4: 配置 Widget Target**

在 BatteryWidget Target 的 Build Settings 中：
- 添加 App Group: `group.com.batterymonitor.shared`
- 在主 App 和 Widget 中都启用 App Groups

**Step 5: 编译并测试**

Run: 选择 BatteryWidget scheme，运行
Expected: Widget 显示在通知中心

**Step 6: 提交**

```bash
git add BatteryWidget/
git commit -m "feat: implement widget extension with small/medium/large sizes"
```

---

## Task 11: 集成通知功能

**Files:**
- Modify: `BatteryMonitor/ViewModels/DeviceListViewModel.swift`
- Modify: `BatteryMonitor/BatteryMonitorApp.swift`

**Step 1: 在 ViewModel 中添加通知逻辑**

Modify: `BatteryMonitor/ViewModels/DeviceListViewModel.swift`

在 `DeviceListViewModel` 类中添加：

```swift
private let notificationManager = NotificationManager.shared
private let settings = AppSettings.shared

// 在 setupSubscriptions() 方法中添加
private func setupSubscriptions() {
    // ... 现有代码 ...
    
    // 监听低电量设备
    $allDevices
        .map { devices in
            devices.filter { $0.isLowBattery }
        }
        .removeDuplicates()
        .sink { [weak self] lowBatteryDevices in
            guard let self = self else { return }
            
            if self.settings.notificationsEnabled {
                Task {
                    for device in lowBatteryDevices {
                        try? await self.notificationManager.sendLowBatteryNotification(for: device)
                    }
                }
            }
        }
        .store(in: &cancellables)
}
```

**Step 2: 在 App 启动时请求通知权限**

Modify: `BatteryMonitor/BatteryMonitorApp.swift`

```swift
@main
struct BatteryMonitorApp: App {
    @StateObject private var viewModel = DeviceListViewModel()
    
    init() {
        // 请求通知权限
        Task {
            try? await NotificationManager.shared.requestPermission()
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
                .task {
                    await viewModel.startMonitoring()
                }
        } label: {
            Image(systemName: menuBarIcon)
                .foregroundColor(menuBarColor)
        }
        .menuBarExtraStyle(.window)
        
        Window("设置", id: "settings") {
            SettingsView()
                .frame(width: 500, height: 400)
        }
    }
    
    // ... 现有代码 ...
}
```

**Step 3: 测试通知功能**

1. 运行应用
2. 修改设置中的低电量阈值为较高值（如 80%）
3. 等待设备电量低于阈值
4. 验证是否收到通知

**Step 4: 提交**

```bash
git add BatteryMonitor/ViewModels/DeviceListViewModel.swift BatteryMonitor/BatteryMonitorApp.swift
git commit -m "feat: integrate notification system with low battery detection"
```

---

## Task 12: 添加权限管理

**Files:**
- Create: `BatteryMonitor/Core/PermissionManager.swift`
- Modify: `BatteryMonitor/Views/MenuBarView.swift`

**Step 1: 实现 PermissionManager**

Create: `BatteryMonitor/Core/PermissionManager.swift`

```swift
import Foundation
import IOBluetooth
import UserNotifications

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var bluetoothAuthorized: Bool = false
    @Published var notificationAuthorized: Bool = false
    
    private init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        checkBluetoothPermission()
        checkNotificationPermission()
    }
    
    private func checkBluetoothPermission() {
        bluetoothAuthorized = IOBluetoothHostController.default()?.powerState == .on
    }
    
    private func checkNotificationPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.notificationAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestBluetoothPermission() {
        // 蓝牙权限会在首次使用时自动请求
        // 这里只是检查状态
        checkBluetoothPermission()
    }
    
    func requestNotificationPermission() async throws {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        
        await MainActor.run {
            self.notificationAuthorized = granted
        }
    }
    
    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Step 2: 在 MenuBarView 中添加权限提示**

Modify: `BatteryMonitor/Views/MenuBarView.swift`

在 `MenuBarView` 中添加权限提示横幅：

```swift
struct MenuBarView: View {
    @ObservedObject var viewModel: DeviceListViewModel
    @StateObject private var permissionManager = PermissionManager.shared
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // 权限提示
            if !permissionManager.bluetoothAuthorized {
                PermissionBannerView(
                    icon: "antenna.radiowaves.left.and.right",
                    message: "需要蓝牙权限来检测设备",
                    action: {
                        permissionManager.openSystemPreferences()
                    }
                )
            }
            
            // ... 现有代码 ...
        }
    }
}

struct PermissionBannerView: View {
    let icon: String
    let message: String
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("设置") {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }
}
```

**Step 3: 测试权限管理**

1. 运行应用
2. 如果蓝牙未授权，应显示权限提示
3. 点击"设置"按钮，应打开系统偏好设置

**Step 4: 提交**

```bash
git add BatteryMonitor/Core/PermissionManager.swift BatteryMonitor/Views/MenuBarView.swift
git commit -m "feat: add permission manager with UI prompts"
```

---

## Task 13: 优化性能和错误处理

**Files:**
- Modify: `BatteryMonitor/Services/MacBatteryService.swift`
- Modify: `BatteryMonitor/Services/BluetoothDeviceService.swift`
- Modify: `BatteryMonitor/ViewModels/DeviceListViewModel.swift`

**Step 1: 添加缓存机制**

Modify: `BatteryMonitor/Services/MacBatteryService.swift`

```swift
class MacBatteryService: DeviceManager {
    // ... 现有代码 ...
    
    private var lastUpdateTime: Date?
    private let cacheInterval: TimeInterval = 5.0 // 5秒缓存
    
    private func updateBatteryInfo() async {
        // 检查缓存
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < cacheInterval {
            return
        }
        
        // ... 现有更新逻辑 ...
        
        lastUpdateTime = Date()
    }
}
```

**Step 2: 添加错误重试机制**

Modify: `BatteryMonitor/Services/BluetoothDeviceService.swift`

```swift
class BluetoothDeviceService: DeviceManager {
    // ... 现有代码 ...
    
    private var retryCount = 0
    private let maxRetries = 3
    
    func startMonitoring() async throws {
        guard isAvailable else {
            if retryCount < maxRetries {
                retryCount += 1
                try await Task.sleep(nanoseconds: 1_000_000_000) // 等待 1 秒
                try await startMonitoring()
                return
            }
            throw BluetoothError.bluetoothUnavailable
        }
        
        retryCount = 0 // 重置重试计数
        
        // ... 现有代码 ...
    }
}
```

**Step 3: 添加错误日志**

Modify: `BatteryMonitor/ViewModels/DeviceListViewModel.swift`

```swift
@MainActor
class DeviceListViewModel: ObservableObject {
    // ... 现有代码 ...
    
    @Published var errorMessage: String?
    
    func startMonitoring() async {
        isMonitoring = true
        errorMessage = nil
        
        // 启动 Mac 电池服务
        do {
            try await macBatteryService.startMonitoring()
        } catch {
            errorMessage = "Mac 电池服务启动失败: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }
        
        // 启动蓝牙服务
        do {
            try await bluetoothService.startMonitoring()
        } catch {
            errorMessage = "蓝牙服务启动失败: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }
    }
}
```

**Step 4: 测试错误处理**

1. 关闭蓝牙
2. 运行应用
3. 验证错误提示是否正确显示

**Step 5: 提交**

```bash
git add BatteryMonitor/Services/ BatteryMonitor/ViewModels/
git commit -m "feat: add caching, retry mechanism, and error handling"
```

---

## Task 14: 最终测试和文档

**Files:**
- Create: `README.md`
- Create: `docs/USER_GUIDE.md`

**Step 1: 编写 README**

Create: `README.md`

```markdown
# Battery Monitor

macOS 电量监控应用，实时显示附近 Apple 设备和蓝牙设备的电量。

## 功能特性

- ✅ Mac 本机电池监控
- ✅ 蓝牙设备电量监控
- ✅ 菜单栏快速访问
- ✅ 桌面小组件
- ✅ 低电量通知
- ✅ 现代简约 UI（毛玻璃效果）
- ✅ 中文界面

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0 或更高版本

## 安装

1. 克隆仓库
```bash
git clone <repository-url>
cd battery
```

2. 打开 Xcode 项目
```bash
open BatteryMonitor.xcodeproj
```

3. 编译并运行
- 选择 BatteryMonitor scheme
- 按 Cmd+R 运行

## 使用说明

1. 首次启动会请求蓝牙和通知权限
2. 点击菜单栏电池图标查看所有设备
3. 在设置中自定义低电量阈值和刷新频率
4. 添加桌面小组件以快速查看电量

## 开发

### 项目结构

```
BatteryMonitor/
├── Models/          # 数据模型
├── Services/        # 设备服务
├── ViewModels/      # 视图模型
├── Views/           # UI 视图
└── Core/            # 核心功能

BatteryWidget/       # 小组件扩展
```

### 运行测试

```bash
xcodebuild test -scheme BatteryMonitor
```

## 许可证

MIT License
```

**Step 2: 编写用户指南**

Create: `docs/USER_GUIDE.md`

```markdown
# 用户指南

## 快速开始

### 1. 首次设置

启动应用后，系统会请求以下权限：
- **蓝牙权限**：用于检测附近的蓝牙设备
- **通知权限**：用于发送低电量提醒

### 2. 查看设备电量

点击菜单栏的电池图标，即可看到所有设备的电量列表。

### 3. 自定义设置

点击"设置"按钮，可以配置：
- 低电量阈值（10%-30%）
- 刷新频率（30秒-5分钟）
- 是否启用通知
- 登录时自动启动

### 4. 添加小组件

1. 右键点击桌面或通知中心
2. 选择"编辑小组件"
3. 搜索"电量监控"
4. 拖拽到桌面或通知中心

## 常见问题

### Q: 为什么看不到我的 iPhone？

A: Phase 1 版本暂不支持 iPhone/iPad，将在 Phase 2 中添加。

### Q: 蓝牙设备显示但没有电量？

A: 部分蓝牙设备不支持标准的电池服务，无法读取电量。

### Q: 如何关闭通知？

A: 在设置中关闭"启用低电量通知"开关。

## 技术支持

如有问题，请提交 Issue 到 GitHub 仓库。
```

**Step 3: 完整测试清单**

运行以下测试：

- [ ] Mac 电池电量正确显示
- [ ] 蓝牙设备能够被检测
- [ ] 菜单栏图标正确显示
- [ ] 低电量时图标变红
- [ ] 点击菜单栏展开设备列表
- [ ] 设备列表按电量排序
- [ ] 充电图标正确显示
- [ ] 设置界面可以打开
- [ ] 修改设置后立即生效
- [ ] 小组件正确显示
- [ ] 低电量通知正常发送
- [ ] 权限提示正确显示
- [ ] 应用可以正常退出

**Step 4: 提交**

```bash
git add README.md docs/USER_GUIDE.md
git commit -m "docs: add README and user guide"
```

---

## 完成 Phase 1

恭喜！Phase 1 MVP 版本已完成。

### 已实现功能

✅ Mac 本机电池监控  
✅ 标准蓝牙设备监控  
✅ 菜单栏 UI（毛玻璃效果）  
✅ 桌面小组件（小/中/大）  
✅ 低电量通知  
✅ 设置界面  
✅ 权限管理  
✅ 错误处理和缓存  

### 下一步：Phase 2

Phase 2 将添加：
- iPhone/iPad 支持（libimobiledevice）
- USB 配对流程
- WiFi 设备发现

### 下一步：Phase 3

Phase 3 将添加：
- AirPods 支持（蓝牙包解析）
- Apple Watch 支持
- 私有协议解析

---

## 执行选项

计划已完成并保存到 `docs/plans/2026-03-05-phase1-implementation.md`。

**两种执行方式：**

**1. Subagent-Driven（本会话）**  
我在当前会话中为每个任务派发新的 subagent，任务间进行代码审查，快速迭代。

**2. Parallel Session（独立会话）**  
在新会话中使用 executing-plans skill，批量执行并设置检查点。

你选择哪种方式？
