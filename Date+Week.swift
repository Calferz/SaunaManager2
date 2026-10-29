//
//  Date+Week.swift
//  SaunaManager
//
//  Created on 2026/05/04.
//

import Foundation

extension Date {
    var startOfWeek: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2  // 月曜始まり
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: self
        )
        return calendar.date(from: components) ?? self
    }
}

