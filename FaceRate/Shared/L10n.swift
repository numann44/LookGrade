import Foundation

/// Resolves complete sentences before inserting values. Positional placeholders
/// let translations move names, counts and App Store prices without losing them.
enum L10n {
    static let supportedLanguages = ["en", "tr", "es", "pt-BR", "fr", "de", "ru", "ar", "hi", "zh-Hans", "ja"]

    static var locale: Locale {
        var components = Locale.Components(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        components.region = Locale.current.region
        return Locale(components: components)
    }

    static var isRightToLeft: Bool {
        (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("ar")
    }

    static func lookup(_ key: String, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func text(_ message: Message, bundle: Bundle = .main) -> String {
        let translated = lookup(message.key, bundle: bundle)
        guard !message.arguments.isEmpty else { return translated }
        return String(format: translated, locale: locale, arguments: message.arguments)
    }

    struct Message: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
        let key: String
        let arguments: [CVarArg]
        init(stringLiteral value: String) { key = value; arguments = [] }
        init(stringInterpolation: StringInterpolation) {
            key = stringInterpolation.key
            arguments = stringInterpolation.arguments
        }
        struct StringInterpolation: StringInterpolationProtocol {
            var key = ""
            var arguments: [CVarArg] = []
            init(literalCapacity: Int, interpolationCount: Int) {
                key.reserveCapacity(literalCapacity)
                arguments.reserveCapacity(interpolationCount)
            }
            mutating func appendLiteral(_ literal: String) {
                key += literal.replacingOccurrences(of: "%", with: "%%")
            }
            mutating func appendInterpolation<T>(_ value: T) {
                key += "%\(arguments.count + 1)$@"
                if let number = value as? Int { arguments.append(number.formatted(.number.grouping(.never).locale(L10n.locale))) }
                else { arguments.append(String(describing: value)) }
            }
        }
    }

    static func duration(_ count: Int, unit: NSCalendar.Unit) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = unit
        formatter.maximumUnitCount = 1
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        var components = DateComponents()
        switch unit {
        case .year: components.year = count
        case .month: components.month = count
        case .weekOfMonth: components.weekOfMonth = count
        case .hour: components.hour = count
        case .minute: components.minute = count
        default: components.day = count
        }
        return formatter.string(from: components) ?? count.formatted()
    }

    static func readingDelay(for message: String) -> Double {
        // Leave enough time for longer translations and scripts without spaces.
        max(5.5, min(14, Double(message.count) * 0.075 + 2))
    }
}
