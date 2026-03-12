import Foundation

struct DeviceDetailItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String?

    init(id: String, title: String, value: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
    }
}

struct DeviceDetailSection: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let items: [DeviceDetailItem]

    init(id: String, title: String, items: [DeviceDetailItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

struct DeviceDetailSnapshot: Codable, Equatable {
    let subtitle: String?
    let sections: [DeviceDetailSection]
    let footnote: String?

    init(subtitle: String? = nil, sections: [DeviceDetailSection], footnote: String? = nil) {
        self.subtitle = subtitle
        self.sections = sections
        self.footnote = footnote
    }
}

extension Device {
    var supportsBatteryDetails: Bool {
        switch type {
        case .mac, .iPhone, .iPad, .appleWatch:
            return true
        default:
            return false
        }
    }
}
