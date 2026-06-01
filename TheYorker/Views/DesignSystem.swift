//
//  DesignSystem.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import SwiftUI

// MARK: - View Modifiers

extension View {
    /// Applies the standard card surface background and continuous-corner clip.
    func yorkerCard(radius: CGFloat = 18) -> some View {
        self
            .background(Color.yorkerCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Applies the live-match surface: subtle green glow gradient + accent border stroke.
    func liveCard() -> some View {
        self
            .background(LinearGradient.yorkerLiveGlow())
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.yorkerAccent.opacity(0.55), Color.yorkerAccent.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
    }
}

// MARK: - Live Badge

/// Animated pulsing live badge used on cards and the match detail hero.
///
/// Two concurrent animations run independently via separate `@State` flags:
/// - `pulse`: the solid dot breathes in/out (scale effect, repeating)
/// - `ring`: a larger ring expands and fades outward (like a ripple)
struct LiveBadge: View {
    @State private var pulse = false
    @State private var ring  = false

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                // Expanding ring — grows from 7pt to 16pt and fades
                Circle()
                    .strokeBorder(Color.yorkerLive.opacity(0.35), lineWidth: 1.5)
                    .frame(width: ring ? 16 : 7, height: ring ? 16 : 7)
                    .opacity(ring ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: ring)
                // Solid pulsing core dot
                Circle()
                    .fill(Color.yorkerLive)
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulse ? 1.2 : 0.9)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            }
            .frame(width: 18, height: 18)
            .onAppear { pulse = true; ring = true }

            Text("LIVE")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color.yorkerLive)
                .kerning(0.8)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.yorkerLive.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.yorkerLive.opacity(0.3), lineWidth: 0.8))
    }
}

// MARK: - Match Type Badge

/// Colour-coded format badge (TEST / ODI / T20 / IPL) rendered as a small pill.
/// Each format has a distinct accent colour so users can scan match types at a glance.
struct MatchTypeBadge: View {
    let type: String

    /// Returns the accent colour associated with this format string.
    var color: Color {
        switch type {
        case "TEST": return Color.yorkerOrange
        case "ODI":  return Color.yorkerAccent2
        case "T20","T20I": return Color.yorkerAccent
        case "IPL":  return Color(hex: "A855F7") // purple for IPL
        default:     return Color.yorkerTextSec
        }
    }

    var body: some View {
        Text(type)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(color)
            .kerning(0.6)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.8))
    }
}

// MARK: - Filter Chip

/// Tappable filter pill used in the HomeView horizontal scroll bar.
///
/// When selected, the background fills with `yorkerAccent` and the text/icon inverts to dark —
/// providing clear affordance without needing a checkbox or radio button.
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = .yorkerTextSec
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        // Icon turns dark when selected (against the accent green background)
                        .foregroundColor(isSelected ? Color.yorkerBG : iconColor)
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? Color.yorkerBG : .yorkerTextSec)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.yorkerAccent : Color.yorkerCard)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.yorkerDivider, lineWidth: isSelected ? 0 : 1))
            // Drop shadow glows green when selected for extra visual pop
            .shadow(color: isSelected ? Color.yorkerAccent.opacity(0.3) : .clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Section Header

/// Bold section title with an optional muted subtitle on the same baseline.
/// Used to open each grouped list section (e.g. "All Matches · 6 matches").
struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title; self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.yorkerTextPrim)
            if let s = subtitle {
                Text(s)
                    .font(.system(size: 12))
                    .foregroundColor(.yorkerTextTert)
                    .padding(.bottom, 2)
            }
            Spacer()
        }
    }
}

// MARK: - Empty State View

/// Full-width empty state with a large emoji icon, title, and subtitle.
/// The content springs in on appear so the view doesn't feel abrupt when the data resolves empty.
struct EmptyStateView: View {
    let icon: String; let title: String; let subtitle: String
    @State private var on = false

    var body: some View {
        VStack(spacing: 14) {
            Text(icon).font(.system(size: 54))
                .scaleEffect(on ? 1 : 0.4).opacity(on ? 1 : 0)
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.yorkerTextPrim)
                .offset(y: on ? 0 : 12).opacity(on ? 1 : 0)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.yorkerTextSec)
                .multilineTextAlignment(.center)
                .offset(y: on ? 0 : 12).opacity(on ? 1 : 0)
        }
        .padding(32).frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) { on = true }
        }
    }
}

// MARK: - Skeleton Match Card

/// Placeholder card shown while data is loading.
///
/// Uses a horizontal shimmer gradient that translates from left to right via `phase`,
/// mimicking the skeleton loaders common in native iOS apps and giving the user a
/// sense of expected content shape before data arrives.
struct SkeletonMatchCard: View {
    @State private var phase: CGFloat = -180

    var body: some View {
        VStack(spacing: 0) {
            // Header row: two badge-shaped pills + date pill (right)
            HStack {
                pill(w: 40, h: 18)
                pill(w: 50, h: 18)
                Spacer()
                pill(w: 60, h: 12)
            }
            .padding(.horizontal, 16).padding(.top, 14)

            line.padding(.horizontal, 16).padding(.vertical, 12)

            HStack {
                teamSkeletonRow(nameW: 70)
                Spacer()
                pill(w: 80, h: 22)
            }.padding(.horizontal, 16)

            Spacer().frame(height: 10)

            HStack {
                teamSkeletonRow(nameW: 90)
                Spacer()
                pill(w: 60, h: 22)
            }.padding(.horizontal, 16)

            line.padding(.horizontal, 16).padding(.vertical, 12)

            pill(w: 200, h: 11).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 14)
        }
        .foregroundColor(Color.yorkerCardAlt)
        .background(Color.yorkerCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(shimmerOverlay)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 400
            }
        }
    }

    /// The shimmer is a narrow translucent gradient window that slides across the card.
    /// It is clipped to the card shape so it doesn't bleed outside the rounded corners.
    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.06), Color.white.opacity(0.11), Color.white.opacity(0.06), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: 140)
            .offset(x: phase)
            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: phase)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pill(w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: h / 2, style: .continuous).frame(width: w, height: h)
    }
    private var line: some View {
        Rectangle().frame(height: 1)
    }
    private func teamSkeletonRow(nameW: CGFloat) -> some View {
        HStack(spacing: 8) {
            Circle().frame(width: 30, height: 30)
            pill(w: nameW, h: 13)
        }
    }
}
