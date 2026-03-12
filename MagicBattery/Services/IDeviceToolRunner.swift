import Foundation

enum IDeviceTool: String, CaseIterable {
    case ideviceID = "idevice_id"
    case ideviceInfo = "ideviceinfo"
    case ideviceDiagnostics = "idevicediagnostics"
    case wifiConnection = "wificonnection"
    case companionTest = "comptest"
    case watchRegistryProbe = "watchregistryprobe"

    var executableName: String { rawValue }
}

struct ToolExecutionResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: TimeInterval
}

enum IDeviceToolError: LocalizedError {
    case toolNotFound(IDeviceTool, [String])
    case executionFailed(IDeviceTool, Int32, String)
    case timedOut(IDeviceTool, TimeInterval)
    case processLaunchFailed(IDeviceTool, String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool, let candidates):
            return String(format: String(localized: "error.tool_not_found"), tool.executableName, candidates.joined(separator: ", "))
        case .executionFailed(let tool, let code, let stderr):
            if stderr.isEmpty {
                return String(format: String(localized: "error.execution_failed"), tool.executableName, code)
            }
            return String(format: String(localized: "error.execution_failed_detail"), tool.executableName, code, stderr)
        case .timedOut(let tool, let timeout):
            return String(format: String(localized: "error.timed_out"), tool.executableName, Int(timeout))
        case .processLaunchFailed(let tool, let message):
            return String(format: String(localized: "error.launch_failed"), tool.executableName, message)
        }
    }
}

protocol IDeviceToolRunning {
    func isAvailable(_ tool: IDeviceTool) -> Bool
    func resolvedPath(for tool: IDeviceTool) -> String?
    func candidatePaths(for tool: IDeviceTool) -> [String]
    func run(_ tool: IDeviceTool, arguments: [String], timeout: TimeInterval) async -> Result<ToolExecutionResult, Error>
}

final class IDeviceToolRunner: IDeviceToolRunning {
    private let fileManager = FileManager.default

    func isAvailable(_ tool: IDeviceTool) -> Bool {
        resolvePath(for: tool) != nil
    }

    func resolvedPath(for tool: IDeviceTool) -> String? {
        resolvePath(for: tool)
    }

    func candidatePaths(for tool: IDeviceTool) -> [String] {
        bundleCandidates(for: tool) + pathCandidates(for: tool)
    }

    func run(_ tool: IDeviceTool, arguments: [String], timeout: TimeInterval = 10) async -> Result<ToolExecutionResult, Error> {
        do {
            return .success(try await execute(tool, arguments: arguments, timeout: timeout))
        } catch {
            return .failure(error)
        }
    }

    private func execute(_ tool: IDeviceTool, arguments: [String], timeout: TimeInterval) async throws -> ToolExecutionResult {
        guard let executablePath = resolvePath(for: tool) else {
            throw IDeviceToolError.toolNotFound(tool, candidatePaths(for: tool))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutCapture = PipeCapture(fileHandle: stdoutPipe.fileHandleForReading)
        let stderrCapture = PipeCapture(fileHandle: stderrPipe.fileHandleForReading)

        let startedAt = Date()
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        log("run \(tool.executableName) path=\(executablePath) args=\(arguments.joined(separator: " ")) timeout=\(Int(timeout))s")

        do {
            try process.run()
        } catch {
            stdoutCapture.stopReading()
            stderrCapture.stopReading()
            log("launch failed \(tool.executableName): \(error.localizedDescription)")
            throw IDeviceToolError.processLaunchFailed(tool, error.localizedDescription)
        }

        let didExit = await waitForTermination(of: semaphore, timeout: timeout)
        if !didExit {
            process.terminate()
            _ = await waitForTermination(of: semaphore, timeout: 1.5)
            stdoutCapture.stopReading()
            stderrCapture.stopReading()
            log("timeout \(tool.executableName) after \(Int(timeout))s")
            throw IDeviceToolError.timedOut(tool, timeout)
        }

        let stdoutData = stdoutCapture.finish()
        let stderrData = stderrCapture.finish()
        let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = Date().timeIntervalSince(startedAt)

        let result = ToolExecutionResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: duration
        )

        if result.exitCode != 0 {
            log("exit \(tool.executableName) code=\(result.exitCode) duration=\(formatDuration(result.duration)) stderr=\(truncate(result.stderr)) stdout=\(truncate(result.stdout))")
            throw IDeviceToolError.executionFailed(tool, result.exitCode, result.stderr)
        }

        log("exit \(tool.executableName) code=0 duration=\(formatDuration(result.duration)) stdout=\(truncate(result.stdout))")
        return result
    }

    private func resolvePath(for tool: IDeviceTool) -> String? {
        let candidates = bundleCandidates(for: tool) + pathCandidates(for: tool)
        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            // 验证路径是否在白名单内
            if isPathAllowed(candidate) {
                return candidate
            } else {
                log("⚠️ 跳过不在白名单内的路径: \(candidate)")
            }
        }
        return nil
    }

    /// 验证路径是否在允许的目录白名单内
    private func isPathAllowed(_ path: String) -> Bool {
        // Bundle 内的路径总是允许的
        if let resourcePath = Bundle.main.resourcePath,
           path.hasPrefix(resourcePath) {
            return true
        }

        // 允许的系统目录白名单
        let allowedPrefixes = [
            "/opt/homebrew/",
            "/usr/local/",
            "/usr/bin/"
        ]

        return allowedPrefixes.contains { path.hasPrefix($0) }
    }

    private func bundleCandidates(for tool: IDeviceTool) -> [String] {
        guard let resourcePath = Bundle.main.resourcePath else { return [] }
        return [
            "\(resourcePath)/libimobiledevice/bin/\(tool.executableName)",
            "\(resourcePath)/\(tool.executableName)"
        ]
    }

    private func pathCandidates(for tool: IDeviceTool) -> [String] {
        let pathValue = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let pathDirectories = pathValue
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        let commonDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin"
        ]

        // 保持 PATH 顺序，使用有序去重
        var seen = Set<String>()
        var orderedDirectories: [String] = []

        for dir in pathDirectories + commonDirectories {
            if !seen.contains(dir) {
                seen.insert(dir)
                orderedDirectories.append(dir)
            }
        }

        return orderedDirectories.map { "\($0)/\(tool.executableName)" }
    }

    private func log(_ message: String) {
        AppLogger.debug(message, category: AppLogger.ios)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2fs", duration)
    }

    private func truncate(_ text: String, limit: Int = 180) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "..."
    }

    private func waitForTermination(of semaphore: DispatchSemaphore, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = semaphore.wait(timeout: .now() + timeout)
                continuation.resume(returning: result == .success)
            }
        }
    }
}

private final class PipeCapture {
    private let fileHandle: FileHandle
    private let lock = NSLock()
    private var data = Data()

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        startReading()
    }

    func finish() -> Data {
        stopReading()
        append(fileHandle.readDataToEndOfFile())
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    func stopReading() {
        fileHandle.readabilityHandler = nil
    }

    private func startReading() {
        fileHandle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self?.append(chunk)
        }
    }

    private func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }
}
