import SwiftUI

/// 设备图标枚举，映射到 SF Symbols
enum DeviceIcon: String, Codable {
    case mac = "laptopcomputer"
    case iPhone = "iphone"
    case iPad = "ipad"
    case appleWatch = "applewatch"
    case airPods = "airpodspro"
    case bluetooth = "dot.radiowaves.left.and.right"
    case keyboard = "keyboard"
    case mouse = "computermouse"
    case headphone = "headphones"

    /// 获取对应的 SF Symbol 名称
    var symbolName: String {
        return self.rawValue
    }
}
