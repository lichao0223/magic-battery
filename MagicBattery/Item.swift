//
//  Item.swift
//  battery
//
//  Created by 李超 on 2026/3/5.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
