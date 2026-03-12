import Foundation
import Combine

/// 设备管理器协议
/// 定义了设备发现、监控和管理的核心接口
protocol DeviceManager {
    /// 当前发现的所有设备
    var devices: [Device] { get }

    /// 设备列表的发布者，用于响应式更新
    var devicesPublisher: AnyPublisher<[Device], Never> { get }

    /// 开始监控设备
    func startMonitoring()

    /// 停止监控设备
    func stopMonitoring()

    /// 刷新设备列表
    func refreshDevices() async

    /// 获取特定设备的详细信息
    /// - Parameter id: 设备ID
    /// - Returns: 设备信息，如果不存在则返回nil
    func getDevice(by id: UUID) -> Device?
}
