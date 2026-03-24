# Battery Monitor - 构建说明

## 系统要求

- macOS 15.6 或更高版本
- Xcode 26.0 或更高版本
- Swift 5.9 或更高版本
- Git

## 快速开始

### 1. 克隆项目

```bash
git clone <repository-url>
cd battery
```

### 2. 打开项目

```bash
open battery.xcodeproj
```

或者在 Xcode 中：
- File → Open
- 选择 `battery.xcodeproj`

### 3. 配置项目

#### 3.1 配置签名

1. 在 Xcode 中选择项目
2. 选择 `battery` target
3. 进入 `Signing & Capabilities` 标签
4. 确保 `Automatically manage signing` 已勾选
5. 如 Xcode 未自动选择 Team，手动选择你的开发团队

> 仓库默认不再提交固定的 `DEVELOPMENT_TEAM`，避免在其他机器上直接绑定到作者账号。首次打开工程时手动选择一次即可。

#### 3.2 配置 App Group

小组件需要 App Group 来共享数据。仓库默认使用以下可移植配置：

```text
APP_GROUP_IDENTIFIER = group.com.lc.battery
```

1. 在 `Signing & Capabilities` 标签中
2. 点击 `+ Capability` 按钮
3. 确认 `App Groups` capability 已启用
4. 默认情况下无需修改源码中的 App Group 字符串
5. 如需自定义，请修改 target build settings 中的 `APP_GROUP_IDENTIFIER`

**重要**: 不要再直接修改源码里的 `UserDefaults(suiteName:)` 字符串。应用和小组件都会从 `Info.plist` 中的 `AppGroupIdentifier` 读取实际值。

#### 3.3 配置 Info.plist

项目当前通过 build settings 生成大部分 Info.plist 字段，关键权限描述如下：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要访问蓝牙以监控蓝牙设备的电池状态</string>

<key>NSLocalNetworkUsageDescription</key>
<string>需要访问本地网络以发现已配对的 iPhone、iPad 并读取其电量信息</string>

<key>LSUIElement</key>
<true/>
```

**注意**:
- `LSUIElement` 设置为 `true` 会隐藏 Dock 图标，使应用仅在菜单栏显示。
- macOS 的通知授权由 `UNUserNotificationCenter` 在运行时请求，不需要额外添加 `NSUserNotificationsUsageDescription`。

### 4. 构建项目

#### 4.1 使用 Xcode

1. 选择 `battery` scheme
2. 选择 `My Mac` 作为目标设备
3. 点击 `Run` 按钮（⌘R）或选择 `Product → Run`

#### 4.2 使用命令行

```bash
# 本地免签名 Debug 构建并运行（推荐）
./scripts/run-local.sh run

# 本地免签名测试
./scripts/run-local.sh test

# 已配置 Team 后执行签名 Release 构建
xcodebuild -scheme battery -configuration Release -allowProvisioningUpdates
```

### 5. 运行测试

#### 5.1 使用 Xcode

1. 选择 `Product → Test`（⌘U）
2. 或点击测试导航器中的播放按钮

#### 5.2 使用命令行

```bash
# 运行所有测试（本地免签名）
./scripts/run-local.sh test

# 已配置 Team 后运行签名测试
xcodebuild test -scheme battery -destination 'platform=macOS' -allowProvisioningUpdates

# 运行特定测试
xcodebuild test -scheme battery -only-testing:batteryTests/DeviceTests -destination 'platform=macOS' -allowProvisioningUpdates
```

## 构建配置

### Debug 配置

- 启用调试符号
- 禁用优化
- 启用测试覆盖率
- 包含调试日志

### Release 配置

- 启用优化（-O）
- 移除调试符号
- 代码签名
- 最小化二进制大小

## 常见构建问题

### 问题 1: 签名失败

**错误**: `Code signing failed`

**解决方案**:
1. 确保已选择有效的开发团队
2. 检查证书是否过期
3. 尝试清理构建文件夹（⌘⇧K）
4. 重启 Xcode

### 问题 2: App Group 配置失败

**错误**: `App Group entitlement not found`

**解决方案**:
1. 确保已添加 App Groups capability
2. 检查 App Group ID 是否正确
3. 确保开发者账号支持 App Groups
4. 重新生成 provisioning profile

### 问题 3: 小组件未出现在系统组件列表中

**错误**: 构建成功，但系统中看不到 `MagicBattery` 小组件

**解决方案**:
1. 确认主 App target 和 `BatteryWidgetExtensionExtension` target 都能成功构建
2. 删除桌面或通知中心里旧的 `MagicBattery` 小组件实例
3. 执行 `./scripts/refresh-widget-cache.sh`
4. 在 Xcode 中重新运行主 App
5. 如 Xcode 未自动选择 Team，先修复签名，再重新添加小组件

### 问题 4: 依赖项缺失

**错误**: `Module not found`

**解决方案**:
1. 清理构建文件夹（⌘⇧K）
2. 删除 DerivedData 文件夹
3. 重新构建项目

### 问题 5: 权限描述缺失

**错误**: `This app has crashed because it attempted to access privacy-sensitive data`

**解决方案**:
1. 检查 Info.plist 是否包含所需的权限描述
2. 确保权限描述文本不为空
3. 重新构建并运行

## 构建产物

### Debug 构建

构建产物位置：
```
~/Library/Developer/Xcode/DerivedData/battery-*/Build/Products/Debug/MagicBattery.app
```

### Release 构建

构建产物位置：
```
~/Library/Developer/Xcode/DerivedData/battery-*/Build/Products/Release/MagicBattery.app
```

## 打包发布

### 1. 创建 Archive

```bash
xcodebuild archive \
  -scheme battery \
  -configuration Release \
  -archivePath ./build/battery.xcarchive
```

或在 Xcode 中：
1. 选择 `Product → Archive`
2. 等待构建完成
3. 在 Organizer 中查看 Archive

### 2. 导出应用

```bash
xcodebuild -exportArchive \
  -archivePath ./build/battery.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

### 3. 创建 DMG

使用 `create-dmg` 工具：

```bash
# 安装 create-dmg
brew install create-dmg

# 创建 DMG
create-dmg \
  --volname "Battery Monitor" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MagicBattery.app" 200 190 \
  --hide-extension "MagicBattery.app" \
  --app-drop-link 600 185 \
  "battery-0.0.1.dmg" \
  "./build/MagicBattery.app"
```

### 4. 代码签名和公证

#### 签名

```bash
codesign --force --deep --sign "Developer ID Application: Your Name" MagicBattery.app
```

#### 公证

```bash
# 创建 ZIP
ditto -c -k --keepParent MagicBattery.app MagicBattery.zip

# 提交公证
xcrun notarytool submit MagicBattery.zip \
  --keychain-profile "AC_PASSWORD" \
  --wait

# 装订公证票据
xcrun stapler staple MagicBattery.app
```

## 开发环境设置

### 推荐的 Xcode 设置

1. **编辑器**
   - 启用行号显示
   - 启用代码折叠
   - 使用 4 空格缩进

2. **构建**
   - 启用并行构建
   - 启用增量构建

3. **调试**
   - 启用 Address Sanitizer（开发时）
   - 启用 Thread Sanitizer（开发时）

### 推荐的插件

- SwiftLint: 代码风格检查
- SwiftFormat: 代码格式化

## 性能优化

### 构建时间优化

1. 使用增量构建
2. 启用并行编译
3. 使用预编译头文件
4. 减少不必要的依赖

### 运行时性能

1. 使用 Instruments 进行性能分析
2. 优化资源加载
3. 减少内存占用
4. 优化 UI 渲染

## 故障排除

### 清理构建

```bash
# 清理构建文件夹
xcodebuild clean -scheme battery

# 删除 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/battery-*
```

### 重置 Xcode

```bash
# 重置 Xcode 缓存
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# 重置模拟器
xcrun simctl erase all
```

## 持续集成

### GitHub Actions 示例

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Build
      run: xcodebuild -scheme battery -configuration Release
    
    - name: Test
      run: ./scripts/run-local.sh test
```

## 资源链接

- [Xcode 文档](https://developer.apple.com/documentation/xcode)
- [Swift 构建系统](https://swift.org/package-manager/)
- [代码签名指南](https://developer.apple.com/support/code-signing/)
- [公证指南](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

## 支持

如遇到构建问题，请：

1. 查看本文档的常见问题部分
2. 检查 Xcode 控制台的错误信息
3. 在 GitHub Issues 中搜索类似问题
4. 创建新的 Issue 并提供详细信息

---

最后更新: 2026-03-05
