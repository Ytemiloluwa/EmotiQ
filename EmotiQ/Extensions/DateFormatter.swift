//
//  DateFormatter.swift
//  EmotiQ
//
//  Created by Temiloluwa on 08-08-2025.
//

import Foundation

extension DateFormatter {
    static let subscriptionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
