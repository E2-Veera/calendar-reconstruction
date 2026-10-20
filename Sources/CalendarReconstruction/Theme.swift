import AppKit
import SwiftUI

extension Color {
    /// "#RRGGBB" → Color (sRGB). Invalid strings fall back to gray.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = .gray
            return
        }
        self = Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }

    /// Light/dark pair, resolved by the current appearance.
    static func dynamic(light: (Double, Double, Double, Double), dark: (Double, Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }
}

/// Colours whose values were recovered from Calendar.app's Assets.car with
/// `xcrun assetutil --info` (see evidence/rea/named-colors.md). Values only — no assets copied.
enum Theme {
    /// CalendarAccentColor — today marker, current-time line.
    static let accent = Color.dynamic(light: (1, 0.231, 0.188, 1), dark: (1, 0.271, 0.227, 1))
    /// ActiveDateLabelColor — text on the today marker.
    static let activeDateLabel = Color.dynamic(light: (1, 1, 1, 1), dark: (0, 0, 0, 1))
    /// WeekendBackgroundColor.
    static let weekendBackground = Color.dynamic(light: (0.976, 0.976, 0.976, 1), dark: (0.235, 0.235, 0.235, 0.3))
    /// AllDayDividerColor.
    static let allDayDivider = Color.dynamic(light: (0.85, 0.85, 0.85, 1), dark: (0.25, 0.25, 0.25, 1))
    /// MonthViewTopDividerColor.
    static let monthTopDivider = Color.dynamic(light: (0.78, 0.78, 0.8, 1), dark: (0.3, 0.3, 0.3, 1))
    /// CanvasGridline{Weekday,Weekend,Today}{Work,Off}HoursColor.
    static let gridWeekdayWork = Color.dynamic(light: (0.9, 0.9, 0.9, 1), dark: (0.25, 0.25, 0.25, 1))
    static let gridWeekdayOff = Color.dynamic(light: (0.97, 0.97, 0.97, 1), dark: (0.2, 0.2, 0.2, 1))
    static let gridWeekendWork = Color.dynamic(light: (0.88, 0.88, 0.88, 1), dark: (0.25, 0.25, 0.25, 1))
    static let gridWeekendOff = Color.dynamic(light: (0.93, 0.93, 0.93, 1), dark: (0.21, 0.21, 0.21, 1))
    static let gridTodayWork = Color.dynamic(light: (0.91, 0.85, 0.85, 1), dark: (0.13, 0.13, 0.13, 1))
    static let gridTodayOff = Color.dynamic(light: (0.955, 0.895, 0.895, 1), dark: (0.07, 0.07, 0.07, 1))
    /// HeatmapIntensity{1,2,3}_{Background,Text} — year view busy-day shading.
    static let heatmap: [(background: Color, text: Color)] = [
        (.dynamic(light: (1, 0.99, 0.92, 1), dark: (0.22, 0.195, 0.101, 0.7)),
         .dynamic(light: (1, 0.58, 0.12, 1), dark: (0.798, 0.678, 0.474, 1))),
        (.dynamic(light: (1, 0.95, 0.91, 1), dark: (0.231, 0.161, 0.102, 1)),
         .dynamic(light: (1, 0.43, 0.36, 1), dark: (0.811, 0.444, 0.282, 1))),
        (.dynamic(light: (1, 0.91, 0.91, 1), dark: (0.251, 0.118, 0.114, 1)),
         .dynamic(light: (0.87, 0.16, 0.28, 1), dark: (0.846, 0.213, 0.263, 1))),
    ]

    /// Work hours used for gridline shading (Calendar.app default "Day starts 08:00 / ends 18:00";
    /// that default is an assumption, not recovered evidence).
    static let workHours = 8..<18
}
