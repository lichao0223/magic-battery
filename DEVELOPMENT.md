# Battery Monitor - 开发指南

## 目录

1. [环境搭建](#环境搭建)
2. [项目配置](#项目配置)
3. [开发流程](#开发流程)
4. [代码规范](#代码规范)
5. [调试技巧](#调试技巧)
6. [常见问题](#常见问题)

## 环境搭建

### 必需工具

- macOS 15.6 或更高版本
- Xcode 26.0 或更高版本
- Git

### 安装步骤

1. 克隆项目
```bash
git clone <repository-url>
cd battery
```

2. 打开项目
```bash
open battery.xcodeproj
```

3. 配置签名
   - 在 Xcode 中选择项目
   - 进入 Signing & Capabilities
   - 确保 Automatically manage signing 已启用
   - 如 Xcode 未自动选择 Team，手动选择你的开发团队

## 项目配置

### App Group 配置

小组件需要 App Group 来共享数据。项目默认使用可移植的 build setting：

```text
APP_GROUP_IDENTIFIER = group.com.lc.battery
```

1. 在 Xcode 中选择项目
2. 选择 battery target
3. 进入 Signing & Capabilities
4. 点击 + Capability
5. 确认 App Groups capability 已启用
6. 默认情况下无需修改源码中的 App Group 字符串

### Info.plist 配置

确保以下权限描述已添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要访问蓝牙以监控蓝牙设备的电池状态</string>

<key>NSUserNotificationsUsageDescription</key>
<string>需要发送通知以提醒您设备电量过低</string>

<key>LSUIElement</key>
<true/>
```

注意：`LSUIElement` 设置为 true 可以隐藏 Dock 图标。

### 构建配置

#### Debug 配置
- 启用调试符号
- 禁用优化
- 启用测试覆盖率

#### Release 配置
- 启用优化
- 移除调试符号
- 代码签名

## 开发流程

### 分支策略

- `main`: 主分支，稳定版本
- `develop`: 开发分支
- `feature/*`: 功能分支
- `bugfix/*`: 修复分支

### 提交规范

使用 Conventional Commits 规范：

```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式调整
refactor: 重构
test: 测试相关
chore: 构建/工具相关
```

示例：
```bash
git commit -m "feat: add battery history chart"
git commit -m "fix: resolve memory leak in BluetoothService"
git commit -m "docs: update README with new features"
```

### 开发工作流

1. 创建功能分支
```bash
git checkout -b feature/new-feature
```

2. 开发和测试
```bash
# 编写代码
# 运行测试
xcodebuild test -scheme battery
```

3. 提交代码
```bash
git add .
git commit -m "feat: implement new feature"
```

4. 合并到主分支
```bash
git checkout main
git merge feature/new-feature
```

## 代码规范

### Swift 代码风格

#### 命名规范

- **类型名**: PascalCase
  ```swift
  class DeviceManager { }
  struct Device { }
  enum DeviceType { }
  ```

- **变量/函数名**: camelCase
  ```swift
  var batteryLevel: Int
  func refreshDevices() { }
  ```

- **常量**: camelCase
  ```swift
  let maxDeviceCount = 50
  private let updateInterval: TimeInterval = 60.0
  ```

#### 代码组织

使用 MARK 注释组织代码：

```swift
// MARK: - Properties
private var devices: [Device] = []

// MARK: - Initialization
init() { }

// MARK: - Public Methods
func startMonitoring() { }

// MARK: - Private Methods
private func updateDevices() { }
```

#### 注释规范

```swift
/// 设备管理器协议
/// 定义了设备发现、监控和管理的核心接口
protocol DeviceManager {
    /// 当前发现的所有设备
    var devices: [Device] { get }

    /// 开始监控设备
    func startMonitoring()
}
```

### SwiftUI 视图规范

```swift
struct DeviceRowView: View {
    let device: Device

    var body: some View {
        HStack {
            // 视图内容
        }
    }

    // MARK: - Subviews

    private var iconView: some View {
        Image(systemName: device.icon.symbolName)
    }
}
```

## 调试技巧

### 日志输出

使用统一的日志格式：

```swift
print("✅ 成功: \(message)")
print("⚠️ 警告: \(message)")
print("❌ 错误: \(message)")
print("📊 信息: \(message)")
```

### 性能监控

使用 PerformanceMonitor 追踪性能：

```swift
await PerformanceMonitor.shared.measure("操作名称") {
    // 需要测量的代码
}
```

### 内存监控

检查内存使用：

```swift
let usage = MemoryMonitor.shared.getCurrentMemoryUsage()
print("内存使用: \(usage.usedMB) MB")
```

### Xcode 调试工具

1. **Instruments**
   - Time Profiler: 性能分析
   - Allocations: 内存分析
   - Leaks: 内存泄漏检测

2. **View Hierarchy**
   - Debug View Hierarchy: 查看视图层级

3. **Network Link Conditioner**
   - 模拟不同网络条件

## 常见问题

### Q1: 无法获取蓝牙设备列表

**问题**: `IOBluetoothDevice.pairedDevices()` 返回 nil

**解决方案**:
1. 检查蓝牙权限是否已授予
2. 确保 Info.plist 包含蓝牙使用说明
3. 重启蓝牙服务

### Q2: 小组件不更新

**问题**: 小组件显示旧数据

**解决方案**:
1. 检查 App Group 配置是否正确
2. 确认数据已保存到共享容器
3. 手动刷新小组件：
```swift
WidgetCenter.shared.reloadAllTimelines()
```
4. 如系统未重新注册小组件，执行 `./scripts/refresh-widget-cache.sh` 后重新运行主 App

### Q3: 通知不显示

**问题**: 低电量通知未显示

**解决方案**:
1. 检查通知权限状态
2. 确认通知未被系统禁用
3. 检查通知中心设置

### Q4: 菜单栏图标不显示

**问题**: 状态栏没有应用图标

**解决方案**:
1. 检查 `NSStatusBar.system.statusItem` 是否创建成功
2. 确认图标资源存在
3. 检查应用激活策略设置

### Q5: 电池电量不准确

**问题**: 显示的电量与系统不一致

**解决方案**:
1. 检查 IOKit 调用是否正确
2. 验证电量计算公式
3. 确认使用正确的电源信息键

## 测试指南

### 单元测试

运行所有测试：
```bash
xcodebuild test -scheme battery -destination 'platform=macOS'
```

运行特定测试：
```bash
xcodebuild test -scheme battery -only-testing:batteryTests/DeviceTests
```

### 手动测试清单

- [ ] Mac 电池监控
  - [ ] 电量显示正确
  - [ ] 充电状态正确
  - [ ] 定时更新工作

- [ ] 蓝牙设备监控
  - [ ] 设备列表显示
  - [ ] 设备类型识别
  - [ ] 连接状态检测

- [ ] 通知功能
  - [ ] 低电量通知
  - [ ] 通知去重
  - [ ] 前台显示

- [ ] 菜单栏界面
  - [ ] 图标显示
  - [ ] 弹出窗口
  - [ ] 设备列表

- [ ] 设置功能
  - [ ] 通知设置
  - [ ] 更新间隔
  - [ ] 应用设置

- [ ] 小组件
  - [ ] 小尺寸显示
  - [ ] 中尺寸显示
  - [ ] 大尺寸显示
  - [ ] 数据更新

## 发布流程

### 1. 版本号更新

在 Xcode 中更新版本号：
- Version: 1.0.0
- Build: 1

### 2. 构建 Release 版本

```bash
xcodebuild -scheme battery -configuration Release
```

### 3. 代码签名

确保使用有效的开发者证书签名。

### 4. 创建 DMG

使用工具创建安装包：
```bash
# 使用 create-dmg 或其他工具
```

### 5. 公证

提交到 Apple 进行公证：
```bash
xcrun notarytool submit battery.dmg --keychain-profile "AC_PASSWORD"
```

### 6. 发布

- 上传到 GitHub Releases
- 更新 README 和文档
- 发布更新日志

## 资源链接

- [Swift 官方文档](https://swift.org/documentation/)
- [SwiftUI 教程](https://developer.apple.com/tutorials/swiftui)
- [IOKit 文档](https://developer.apple.com/documentation/iokit)
- [WidgetKit 文档](https://developer.apple.com/documentation/widgetkit)
- [Combine 框架](https://developer.apple.com/documentation/combine)

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支
3. 提交代码
4. 创建 Pull Request
5. 等待代码审查

## 联系方式

如有问题，请通过以下方式联系：

- GitHub Issues
- Email: [your-email]

---

最后更新: 2026-03-05
