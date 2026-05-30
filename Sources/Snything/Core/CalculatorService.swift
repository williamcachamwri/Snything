import Foundation

struct CalculatorResult {
    let query: String
    let result: String
    let type: CalculatorResultType
}

enum CalculatorResultType {
    case math
    case unitConversion
    case currencyConversion
}

enum CalculatorService {
    static func evaluate(_ query: String) -> CalculatorResult? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // 1. Unit conversion: "50 kg to lbs", "100 miles to km"
        if let unit = parseUnitConversion(trimmed) {
            return unit
        }

        // 2. Currency conversion: "100 USD to VND", "50 usd in eur"
        if let currency = parseCurrencyConversion(trimmed) {
            return currency
        }

        // 3. Math expression
        if let math = parseMathExpression(trimmed) {
            return math
        }

        return nil
    }

    // MARK: - Math

    private static func parseMathExpression(_ text: String) -> CalculatorResult? {
        // Must contain at least one operator or function
        let mathChars = CharacterSet(charactersIn: "+-*/%^()")
        let functions = ["sqrt", "sin", "cos", "tan", "log", "ln", "abs", "floor", "ceil", "round", "pow", "exp"]
        let hasOperator = text.unicodeScalars.contains { mathChars.contains($0) }
        let hasFunction = functions.contains { text.lowercased().contains($0) }

        guard hasOperator || hasFunction else { return nil }

        // Don't treat things like "a+b" or file paths as math
        let forbiddenChars = CharacterSet.letters.subtracting(CharacterSet(charactersIn: "e"))
        let lettersOnly = text.filter { forbiddenChars.contains($0.unicodeScalars.first!) }
        if lettersOnly.count > 2 && !hasFunction {
            return nil
        }

        // Sanitize and evaluate
        let sanitized = text
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "pi", with: "3.14159265359")
            .replacingOccurrences(of: "PI", with: "3.14159265359")

        let expr = NSExpression(format: sanitized)
        guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else {
            return nil
        }

        let doubleVal = result.doubleValue
        let formatted: String
        if doubleVal == floor(doubleVal) && doubleVal < 1e15 {
            formatted = String(format: "%.0f", doubleVal)
        } else {
            formatted = String(format: "%.6g", doubleVal)
        }

        return CalculatorResult(query: text, result: formatted, type: .math)
    }

    // MARK: - Unit Conversion

    private static let unitConversions: [(pattern: String, from: Double, to: Double, label: String)] = [
        // Length
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:km|kilometers?)\\s+(?:to|in)\\s+(?:mi|miles?)$", 1.0, 0.621371, "miles"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:mi|miles?)\\s+(?:to|in)\\s+(?:km|kilometers?)$", 1.0, 1.60934, "km"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:m|meters?)\\s+(?:to|in)\\s+(?:ft|feet)$", 1.0, 3.28084, "ft"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:ft|feet)\\s+(?:to|in)\\s+(?:m|meters?)$", 1.0, 0.3048, "m"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:cm|centimeters?)\\s+(?:to|in)\\s+(?:in|inch(?:es)?)$", 1.0, 0.393701, "in"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:in|inch(?:es)?)\\s+(?:to|in)\\s+(?:cm|centimeters?)$", 1.0, 2.54, "cm"),
        // Weight
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:kg|kilograms?)\\s+(?:to|in)\\s+(?:lb|lbs|pounds?)$", 1.0, 2.20462, "lbs"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:lb|lbs|pounds?)\\s+(?:to|in)\\s+(?:kg|kilograms?)$", 1.0, 0.453592, "kg"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:g|grams?)\\s+(?:to|in)\\s+(?:oz|ounces?)$", 1.0, 0.035274, "oz"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:oz|ounces?)\\s+(?:to|in)\\s+(?:g|grams?)$", 1.0, 28.3495, "g"),
        // Temperature (special handling)
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:c|celsius|°c)\\s+(?:to|in)\\s+(?:f|fahrenheit|°f)$", 1.0, 1.0, "°F"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:f|fahrenheit|°f)\\s+(?:to|in)\\s+(?:c|celsius|°c)$", 1.0, 1.0, "°C"),
        // Volume
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:l|liters?|litres?)\\s+(?:to|in)\\s+(?:gal|gallons?)$", 1.0, 0.264172, "gal"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:gal|gallons?)\\s+(?:to|in)\\s+(?:l|liters?|litres?)$", 1.0, 3.78541, "L"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:ml|milliliters?)\\s+(?:to|in)\\s+(?:fl\\s*oz|fluid\\s*ounces?)$", 1.0, 0.033814, "fl oz"),
        // Data
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:gb|gigabytes?)\\s+(?:to|in)\\s+(?:mb|megabytes?)$", 1.0, 1024.0, "MB"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:mb|megabytes?)\\s+(?:to|in)\\s+(?:kb|kilobytes?)$", 1.0, 1024.0, "KB"),
        ("^(\\d+(?:\\.\\d+)?)\\s*(?:tb|terabytes?)\\s+(?:to|in)\\s+(?:gb|gigabytes?)$", 1.0, 1024.0, "GB"),
    ]

    private static func parseUnitConversion(_ text: String) -> CalculatorResult? {
        let lower = text.lowercased()
        for conv in unitConversions {
            guard let regex = try? NSRegularExpression(pattern: conv.pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                  let numStr = Range(match.range(at: 1), in: lower),
                  let value = Double(String(lower[numStr]))
            else { continue }

            let result: Double
            if conv.label == "°F" {
                result = value * 9/5 + 32
            } else if conv.label == "°C" {
                result = (value - 32) * 5/9
            } else {
                result = value * conv.to / conv.from
            }

            let formatted: String
            if result == floor(result) && result < 1e12 {
                formatted = String(format: "%.0f %@", result, conv.label)
            } else {
                formatted = String(format: "%.3g %@", result, conv.label)
            }
            return CalculatorResult(query: text, result: formatted, type: .unitConversion)
        }
        return nil
    }

    // MARK: - Currency Conversion

    // Approximate rates (USD base) - updated periodically would be ideal
    private static let currencyRates: [String: Double] = [
        "usd": 1.0,
        "eur": 0.92,
        "gbp": 0.79,
        "jpy": 150.5,
        "vnd": 24500.0,
        "krw": 1330.0,
        "cny": 7.19,
        "cad": 1.35,
        "aud": 1.52,
        "chf": 0.88,
        "sgd": 1.34,
        "hkd": 7.82,
        "inr": 83.0,
        "thb": 35.5,
        "php": 56.2,
        "myr": 4.72,
        "idr": 15600.0,
    ]

    private static func parseCurrencyConversion(_ text: String) -> CalculatorResult? {
        let lower = text.lowercased()
        let pattern = "^(\\d+(?:\\.\\d+)?)\\s*(\\w{3})\\s+(?:to|in)\\s+(\\w{3})$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let amountRange = Range(match.range(at: 1), in: lower),
              let fromRange = Range(match.range(at: 2), in: lower),
              let toRange = Range(match.range(at: 3), in: lower),
              let amount = Double(String(lower[amountRange]))
        else { return nil }

        let fromCode = String(lower[fromRange])
        let toCode = String(lower[toRange])

        guard let fromRate = currencyRates[fromCode], let toRate = currencyRates[toCode] else {
            return nil
        }

        let result = amount * toRate / fromRate
        let formatted: String
        if result >= 100 {
            formatted = String(format: "%.2f %@", result, toCode.uppercased())
        } else {
            formatted = String(format: "%.4f %@", result, toCode.uppercased())
        }
        return CalculatorResult(query: text, result: formatted, type: .currencyConversion)
    }
}
