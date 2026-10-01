import Foundation

/// Dart's `DateTime.now().toIso8601String()` (local time, no timezone
/// suffix, microsecond precision) is what the legacy Flutter-written
/// UserDefaults blobs contain. Swift's own writes use strict ISO8601
/// (`.iso8601` strategy, UTC 'Z' suffix). This decoder tries the Dart
/// shape first, then falls back to strict ISO8601, so both legacy and
/// native-written data parse correctly.
private let dartLocalDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .iso8601)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
    return f
}()

private let dartLocalDateFormatterNoFraction: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .iso8601)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return f
}()

private let strictISO8601 = ISO8601DateFormatter()

extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = strictISO8601.date(from: str) { return date }
            if let date = dartLocalDateFormatter.date(from: str) { return date }
            if let date = dartLocalDateFormatterNoFraction.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date format: \(str)")
        }
        return d
    }
}
