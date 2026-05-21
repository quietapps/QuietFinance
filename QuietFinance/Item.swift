//
//  Item.swift
//  QuietFinance
//
//  Created by Parth Thummar on 4/21/26.
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
