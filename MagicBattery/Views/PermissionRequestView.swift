import SwiftUI

/// 权限请求视图
/// 在应用首次启动时显示，引导用户授予必要权限
struct PermissionRequestView: View {
    @State private var permissions: [PermissionType: PermissionStatus] = [:]
    @State private var isChecking = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            headerView

            // 权限列表
            if isChecking {
                ProgressView(String(localized: "permission.checking"))
                    .padding()
            } else {
                permissionListView
            }

            Spacer()

            // 底部按钮
            footerView
        }
        .padding(32)
        .frame(width: 480, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await checkPermissions()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("permission.welcome.title")
                .font(.system(size: 24, weight: .bold))

            Text("permission.welcome.subtitle")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Permission List View

    private var permissionListView: some View {
        VStack(spacing: 16) {
            ForEach(PermissionType.allCases, id: \.self) { type in
                PermissionRowView(
                    type: type,
                    status: permissions[type] ?? .notDetermined,
                    onRequest: {
                        await requestPermission(type)
                    },
                    onOpenSettings: {
                        PermissionManager.shared.openSystemSettings(for: type)
                    }
                )
            }
        }
        .padding(.vertical)
    }

    // MARK: - Footer View

    private var footerView: some View {
        VStack(spacing: 12) {
            if allRequiredPermissionsGranted {
                Button(action: {
                    dismiss()
                }) {
                    Text("permission.start")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(action: {
                    Task {
                        await requestAllPermissions()
                    }
                }) {
                    Text("permission.grant_all")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: {
                    dismiss()
                }) {
                    Text("permission.later")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }

            Text("permission.modify_hint")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Computed Properties

    private var allRequiredPermissionsGranted: Bool {
        PermissionType.allCases
            .filter { $0.isRequired }
            .allSatisfy { permissions[$0]?.isGranted ?? false }
    }

    // MARK: - Private Methods

    private func checkPermissions() async {
        isChecking = true
        permissions = await PermissionManager.shared.checkAllPermissions()
        isChecking = false
    }

    private func requestPermission(_ type: PermissionType) async {
        switch type {
        case .notification:
            let status = await PermissionManager.shared.requestNotificationPermission()
            permissions[type] = status
        case .bluetooth:
            // 蓝牙权限会在首次使用时自动请求
            break
        case .accessibility:
            PermissionManager.shared.requestAccessibilityPermission()
            // 延迟检查状态
            try? await Task.sleep(nanoseconds: 500_000_000)
            permissions[type] = PermissionManager.shared.checkAccessibilityPermission()
        }
    }

    private func requestAllPermissions() async {
        await PermissionManager.shared.requestAllPermissions()
        await checkPermissions()
    }
}

/// 权限行视图
struct PermissionRowView: View {
    let type: PermissionType
    let status: PermissionStatus
    let onRequest: () async -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .medium))

                    if type.isRequired {
                        Text("permission.required")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }

                Text(type.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 状态和操作
            statusView
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Status View

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .granted:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(status.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }

        case .denied:
            Button(action: onOpenSettings) {
                Text("permission.open_settings")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .notDetermined:
            Button(action: {
                Task {
                    await onRequest()
                }
            }) {
                Text("permission.authorize")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch type {
        case .notification:
            return "bell.fill"
        case .bluetooth:
            return "antenna.radiowaves.left.and.right"
        case .accessibility:
            return "hand.raised.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        }
    }
}

#Preview {
    PermissionRequestView()
}
