//
//  Extensions.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import SwiftUI

// MARK: - Hex Color

extension Color {
    /// Initialises a SwiftUI `Color` from a CSS-style hex string (3, 6, or 8 characters).
    /// The 8-character form encodes alpha in the leading two hex digits (AARRGGBB).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)   // shorthand
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)            // opaque
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF) // with alpha
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB,
                  red:   Double(r)/255,
                  green: Double(g)/255,
                  blue:  Double(b)/255,
                  opacity: Double(a)/255)
    }
}

// MARK: - Design Tokens

extension Color {
    // Backgrounds — layered depth (darkest to lightest)
    static let yorkerBG        = Color(hex: "070C18")  // deepest canvas
    static let yorkerCard      = Color(hex: "0D1526")  // card surface
    static let yorkerCardAlt   = Color(hex: "132038")  // elevated card / chip bg
    static let yorkerDivider   = Color(hex: "1C2E4A")  // subtle separator line

    // Accents
    static let yorkerAccent    = Color(hex: "00D084")  // cricket green (primary CTA)
    static let yorkerAccent2   = Color(hex: "3B82F6")  // electric blue (upcoming / ODI)
    static let yorkerLive      = Color(hex: "FF3B5C")  // live red (pulsing badge)
    static let yorkerGold      = Color(hex: "F5C842")  // winner / trophy gold
    static let yorkerOrange    = Color(hex: "F59E0B")  // test match orange

    // Text hierarchy
    static let yorkerTextPrim  = Color.white
    static let yorkerTextSec   = Color(hex: "6B7A99")
    static let yorkerTextTert  = Color(hex: "374869")
}

// MARK: - Date Helpers

extension String {
    /// Converts an ISO-8601 or `yyyy-MM-dd` date string to a short "MMM d, HH:mm" label.
    /// Falls back to just the date portion when no time component is present.
    var matchDate: String {
        if let d = parseDate() {
            let f = DateFormatter()
            f.dateFormat = "MMM d, HH:mm"
            f.timeZone = .current
            return f.string(from: d)
        }
        // Try date-only as a fallback (e.g. "2026-05-22" → "May 22")
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: String(prefix(10))) {
            let out = DateFormatter(); out.dateFormat = "MMM d"
            return out.string(from: d)
        }
        return self
    }

    /// Returns `true` when the date portion of this string falls on today in the device locale.
    var isToday: Bool {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: String(prefix(10))) else { return false }
        return Calendar.current.isDateInToday(d)
    }

    /// Returns `true` when the date portion of this string falls on tomorrow in the device locale.
    var isTomorrow: Bool {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: String(prefix(10))) else { return false }
        return Calendar.current.isDateInTomorrow(d)
    }

    /// Returns a human-friendly label: "Today", "Tomorrow", or "Monday, May 22".
    var dayLabel: String {
        if isToday    { return "Today" }
        if isTomorrow { return "Tomorrow" }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: String(prefix(10))) else { return self }
        let out = DateFormatter(); out.dateFormat = "EEEE, MMM d"
        return out.string(from: d)
    }

    /// Extracts only the time component ("HH:mm") from an ISO-8601 date-time string.
    var timeOnly: String {
        guard let d = parseDate() else { return "" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current
        return f.string(from: d)
    }

    /// Tries multiple common date formats before falling back to `ISO8601DateFormatter`.
    /// Having multiple formats handles the variety of string shapes CricAPI returns.
    private func parseDate() -> Date? {
        let fmts = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss"
        ]
        for fmt in fmts {
            let df = DateFormatter(); df.dateFormat = fmt
            if let d = df.date(from: self) { return d }
        }
        // Last resort — handles fractional seconds used by some API responses
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: self)
    }
}

// MARK: - Team Helpers

extension String {
    /// Returns the emoji flag for a recognised nation name, or 🏏 as a fallback.
    var teamFlag: String {
        [
            "India":"🇮🇳","Australia":"🇦🇺","England":"🏴󠁧󠁢󠁥󠁮󠁧󠁿",
            "Pakistan":"🇵🇰","New Zealand":"🇳🇿","South Africa":"🇿🇦",
            "West Indies":"🌴","Sri Lanka":"🇱🇰","Bangladesh":"🇧🇩",
            "Zimbabwe":"🇿🇼","Afghanistan":"🇦🇫","Ireland":"🇮🇪",
            "Netherlands":"🇳🇱","Scotland":"🏴󠁧󠁢󠁳󠁣󠁴󠁿","UAE":"🇦🇪","Namibia":"🇳🇦"
        ][self] ?? "🏏"
    }

    /// Returns the standard ICC three-letter abbreviation, or the first 3 letters uppercased.
    var teamShort: String {
        [
            "India":"IND","Australia":"AUS","England":"ENG","Pakistan":"PAK",
            "New Zealand":"NZ","South Africa":"SA","West Indies":"WI",
            "Sri Lanka":"SL","Bangladesh":"BAN","Zimbabwe":"ZIM",
            "Afghanistan":"AFG","Ireland":"IRE"
        ][self] ?? String(prefix(3)).uppercased()
    }
}

// MARK: - Gradient Helpers

extension LinearGradient {
    /// Subtle card gradient used on live-match surfaces to imply activity without being distracting.
    static func yorkerLiveGlow() -> LinearGradient {
        LinearGradient(
            colors: [Color.yorkerCard, Color.yorkerAccent.opacity(0.08)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
