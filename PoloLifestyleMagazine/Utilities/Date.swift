//
//  Date.swift
//  PoloLifestyleMagazine
//
//  Created by MacbookM3 on 12/02/25.
//

import Foundation

///// Determines if a quarterly fetch is required based on the last fetched date
//public func shouldFetchQuarterly(lastFetchedAt: Date) -> Bool {
//    var calendar = Calendar.current
//    calendar.timeZone = TimeZone(secondsFromGMT: 0)! // Force UTC
//
//    let currentDate = Date()
//    let year = calendar.component(.year, from: currentDate)
//
//    // Define quarterly fetch dates in UTC
//    let quarterlyFetchDates: [Date] = [
//        calendar.date(from: DateComponents(year: year, month: 1, day: 2))!,
//        calendar.date(from: DateComponents(year: year, month: 4, day: 2))!,
//        calendar.date(from: DateComponents(year: year, month: 7, day: 2))!,
//        calendar.date(from: DateComponents(year: year, month: 10, day: 2))!
//    ]
//
//    // Find the most recent past quarterly fetch date
//    let pastDueDates = quarterlyFetchDates.filter { $0 <= currentDate }
//    
//    // ✅ If there is a past due date that hasn't been fetched, return true
//    if let lastMissedFetch = pastDueDates.last, lastMissedFetch > lastFetchedAt {
//        return true
//    }
//
//    return false
//}

/// Determines if a quarterly fetch is required based on the last fetched date

public func shouldFetchQuarterly(lastFetchedAt: Date) -> Bool {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(secondsFromGMT: 0)! // Force UTC

    let currentDate = Date()
    let currentYear = calendar.component(.year, from: currentDate)
    let previousYear = currentYear - 1  // ✅ chekcing for last year sync also

    // ✅ Current aur Previous Year ke Quarterly Dates
    let quarterlyFetchDates: [Date] = [
        calendar.date(from: DateComponents(year: previousYear, month: 1, day: 2))!,
        calendar.date(from: DateComponents(year: previousYear, month: 4, day: 2))!,
        calendar.date(from: DateComponents(year: previousYear, month: 7, day: 2))!,
        calendar.date(from: DateComponents(year: previousYear, month: 10, day: 2))!,
        calendar.date(from: DateComponents(year: currentYear, month: 1, day: 2))!,
        calendar.date(from: DateComponents(year: currentYear, month: 4, day: 2))!,
        calendar.date(from: DateComponents(year: currentYear, month: 7, day: 2))!,
        calendar.date(from: DateComponents(year: currentYear, month: 10, day: 2))!
    ]

    // ✅ Find last missed quarterly sync
    let pastDueDates = quarterlyFetchDates.filter { $0 <= currentDate }

    if let lastMissedFetch = pastDueDates.last, lastMissedFetch > lastFetchedAt {
        return true
    }

    return false
}

