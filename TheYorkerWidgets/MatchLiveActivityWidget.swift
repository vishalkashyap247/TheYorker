//
//  MatchLiveActivityWidget.swift
//  TheYorkerWidgets
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

// These duplicate Extensions.swift because widget extensions are separate compilation units.
// MARK: - Widget-local design tokens

private extension Color {
    /// Cricket green — #00D084
    static let wAccent   = Color(red: 0/255,   green: 208/255, blue: 132/255)
    /// Live red — #FF3B5C
    static let wLive     = Color(red: 255/255,  green: 59/255,  blue: 92/255)
    /// Deep navy — #070C18
    static let wBG       = Color(red: 7/255,    green: 12/255,  blue: 24/255)
    /// Card navy — #0D1526
    static let wCard     = Color(red: 13/255,   green: 21/255,  blue: 38/255)
    /// Elevated card — #132038
    static let wCardAlt  = Color(red: 19/255,   green: 32/255,  blue: 56/255)
    /// Secondary text — #6B7A99
    static let wTextSec  = Color(red: 107/255,  green: 122/255, blue: 153/255)
    /// Tertiary text — #374869
    static let wTextTert = Color(red: 55/255,   green: 72/255,  blue: 105/255)
}

// MARK: - Widget Declaration

/// Registers the Live Activity lock-screen and Dynamic Island UI with the system.
///
/// `ActivityConfiguration` maps to `MatchActivityAttributes` — the same type the main app
/// uses when calling `Activity.request(...)`. Any mismatch will cause the system to ignore updates.
struct MatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            // Lock-screen (expanded notification banner) presentation
            MatchLockScreenView(attrs: context.attributes, state: context.state)
                // `.activityBackgroundTint(.clear)` lets our gradient show through
                // instead of the system-provided blurred material background.
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded Dynamic Island ──────────────────────────────
                DynamicIslandExpandedRegion(.leading)  { expandedLeading(context)  }
                DynamicIslandExpandedRegion(.trailing) { expandedTrailing(context) }
                DynamicIslandExpandedRegion(.bottom)   { expandedBottom(context)   }
            } compactLeading: {
                compactLeading(context)
            } compactTrailing: {
                compactTrailing(context)
            } minimal: {
                minimal(context)
            }
            .keylineTint(Color.wAccent)  // accent outline around the island when expanded
        }
    }
}

// MARK: - Lock Screen View

/// Compact lock-screen banner (~130pt tall) that fits within the system-allocated space.
///
/// Design constraints for Live Activity lock-screen views:
/// - The system clips content taller than ~150pt — keep everything within 3 rows.
/// - Do NOT add an internal clipShape — the system applies its own rounded corners.
/// - Use `.activityBackgroundTint()` for the background instead of a background View,
///   which lets the system blend the colour into the lock-screen material correctly.
/// - No animations — the system freezes views on the lock screen.
///
/// Layout (3 rows, ~130pt total):
///   Row 1 — format badge + LIVE badge                     (~24pt)
///   Row 2 — flag/short/score  ·  VS  ·  score/short/flag  (~60pt)
///   Row 3 — overs · RR · status text                      (~20pt)
struct MatchLockScreenView: View {
    let attrs: MatchActivityAttributes
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {

            // ── Row 1: Header badges ───────────────────────────────────────
            HStack(spacing: 8) {
                Text(attrs.matchType)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Color.wAccent)
                    .kerning(0.5)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Color.wAccent.opacity(0.13))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.wAccent.opacity(0.28), lineWidth: 0.8))

                Spacer()

                HStack(spacing: 4) {
                    Circle().fill(Color.wLive).frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(Color.wLive)
                }
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Color.wLive.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.wLive.opacity(0.28), lineWidth: 0.8))
            }

            // ── Row 2: Scores (horizontal — flag + name + score per team) ─
            HStack(alignment: .center, spacing: 0) {
                // Team 1 — left side
                HStack(spacing: 8) {
                    Text(MatchActivityAttributes.flag(for: attrs.team1))
                        .font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(attrs.team1Short)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.wTextSec)
                        Text(state.team1Score)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // VS divider
                Text("VS")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(Color.wTextTert)
                    .frame(width: 28)

                // Team 2 — right side (mirrored)
                HStack(spacing: 8) {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(attrs.team2Short)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.wTextSec)
                        Text(state.team2Score)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(MatchActivityAttributes.flag(for: attrs.team2))
                        .font(.system(size: 26))
                }
                .frame(maxWidth: .infinity)
            }

            // ── Row 3: Stats + status on one line ─────────────────────────
            HStack(spacing: 0) {
                // Overs
                statPill(state.overs, "Overs")
                Rectangle().fill(Color.wTextTert.opacity(0.4)).frame(width: 1, height: 18).padding(.horizontal, 10)
                // Run rate
                statPill(state.runRate, "RR")

                Spacer()

                // Status — right-aligned, green, truncated if long
                HStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 9))
                        .foregroundColor(Color.wAccent)
                    Text(state.status)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.wAccent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        // activityBackgroundTint sets the system material tint — no internal background needed.
        .activityBackgroundTint(Color(red: 10/255, green: 16/255, blue: 30/255))
    }

    // MARK: Stat Pill

    private func statPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.wTextSec)
        }
    }
}

// MARK: - Dynamic Island: Expanded

private func expandedLeading(_ context: ActivityViewContext<MatchActivityAttributes>) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(MatchActivityAttributes.flag(for: context.attributes.team1))
            .font(.system(size: 24))
        Text(context.attributes.team1Short)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.55))
        Text(context.state.team1Score)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
    .padding(.leading, 4)
}

private func expandedTrailing(_ context: ActivityViewContext<MatchActivityAttributes>) -> some View {
    VStack(alignment: .trailing, spacing: 2) {
        Text(MatchActivityAttributes.flag(for: context.attributes.team2))
            .font(.system(size: 24))
        Text(context.attributes.team2Short)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.55))
        Text(context.state.team2Score)
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
    .padding(.trailing, 4)
}

private func expandedBottom(_ context: ActivityViewContext<MatchActivityAttributes>) -> some View {
    HStack(spacing: 8) {
        // Live dot — static here since Dynamic Island has its own ambient pulse
        Circle()
            .fill(Color.wLive)
            .frame(width: 5, height: 5)
        // Status line — current batting situation
        Text(context.state.status)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.wAccent)
            .lineLimit(1)
        Spacer()
        // Overs + run rate in muted text to the right
        HStack(spacing: 6) {
            Text("\(context.state.overs) ov")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Text("•")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.25))
            Text("\(context.state.runRate) RR")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 6)
}

// MARK: - Dynamic Island: Compact

/// Compact leading slot — shows team 1 flag + score, visible when another app is active.
private func compactLeading(_ context: ActivityViewContext<MatchActivityAttributes>) -> some View {
    HStack(spacing: 4) {
        Text(MatchActivityAttributes.flag(for: context.attributes.team1))
            .font(.system(size: 12))
        Text(context.state.team1Score)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
    }
}

/// Compact trailing slot — shows team 2 score + flag (or "—" if yet to bat).
private func compactTrailing(_ context: ActivityViewContext<MatchActivityAttributes>) -> some View {
    HStack(spacing: 4) {
        Text(context.state.team2Score == "Yet to bat" ? "—" : context.state.team2Score)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
        Text(MatchActivityAttributes.flag(for: context.attributes.team2))
            .font(.system(size: 12))
    }
}

// MARK: - Dynamic Island: Minimal

/// Minimal slot — when two activities compete for space, only the batting team's score is shown.
private func minimal(_ context: ActivityViewContext<MatchActivityAttributes>) -> some View {
    Text(context.state.team1Score)
        .font(.system(size: 10, weight: .black, design: .rounded))
        .foregroundColor(Color.wAccent)
        .lineLimit(1)
}
