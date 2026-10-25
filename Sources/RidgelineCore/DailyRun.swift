import Foundation

/// Seeded daily ascent. The seed is an FNV-1a hash of a civil date so it is
/// stable across devices without depending on `Date`'s hash value.
public enum DailyRun {
    public static func seed(year: Int, month: Int, day: Int) -> UInt64 {
        fnv64("ridgeline-ascent-daily-\(year)-\(month)-\(day)")
    }

    public static func seed(for date: Date, calendar: Calendar = utcCalendar) -> UInt64 {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return seed(year: year, month: month, day: day)
    }

    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}

func fnv64(_ text: String) -> UInt64 {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }
    return hash
}
