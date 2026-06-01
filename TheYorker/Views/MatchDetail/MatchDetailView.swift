//
//  MatchDetailView.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import SwiftUI

// MARK: - MatchDetailView

/// Full-screen detail view for a single match.
/// Uses two entrance animation flags (`heroOn`, `contentOn`) that are triggered in `onAppear`
/// so each section slides in with a staggered spring delay for a polished feel.
struct MatchDetailView: View {

    let match: Match
    @State private var vm: MatchDetailViewModel

    /// Shared namespace for the matched-geometry tab-underline animation.
    /// `@Namespace` creates a stable identity space so the green bar slides between tabs.
    @Namespace  private var ns

    @State private var heroOn    = false  // controls hero section entrance
    @State private var contentOn = false  // controls tab content entrance

    init(match: Match) {
        self.match = match
        _vm = State(initialValue: MatchDetailViewModel(match: match))
    }

    var body: some View {
        ZStack {
            Color.yorkerBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    tabBar
                    tabContent
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        // Slide up + fade in after the hero settles
                        .offset(y: contentOn ? 0 : 16)
                        .opacity(contentOn ? 1 : 0)
                }
            }
            .refreshable { await vm.refresh() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.yorkerBG, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Inline title shows team abbreviations + format badge without taking too much space
                VStack(spacing: 2) {
                    Text("\(match.team1.teamShort)  vs  \(match.team2.teamShort)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    MatchTypeBadge(type: match.matchTypeLabel)
                }
            }
        }
        .onAppear {
            // Stagger the content entrance slightly after the hero to create a cascade feel
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8))             { heroOn    = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.2)) { contentOn = true }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background: starts darker at top (blends with nav bar), fades to page BG color
            // so the bottom edge is invisible — no hard card cut.
            LinearGradient(
                colors: [Color(hex: "0A1828"), Color(hex: "091422"), Color.yorkerBG],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            // Green radial glow — live matches only
            if match.isLive {
                RadialGradient(
                    colors: [Color.yorkerAccent.opacity(0.13), .clear],
                    center: .top, startRadius: 0, endRadius: 300
                )
                .ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 0) {
                // Badges row — format type, live indicator, date
                HStack(spacing: 8) {
                    MatchTypeBadge(type: match.matchTypeLabel)
                    if match.isLive { LiveBadge() }
                    Spacer()
                    if let d = match.date { Text(d.matchDate).font(.system(size: 11)).foregroundColor(.yorkerTextSec) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .offset(y: heroOn ? 0 : -12).opacity(heroOn ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: heroOn)

                // ── Scoreboard ──────────────────────────────────────────────
                // .top alignment so both flags sit at the same height regardless of score content
                HStack(alignment: .top, spacing: 0) {
                    heroTeam(
                        team: match.team1, scores: match.team1Scores,
                        isWinner: match.status?.lowercased().contains(match.team1.lowercased()) == true,
                        align: .leading
                    )

                    // VS label — centred vertically in the flag area (~54pt flag + 6pt gap + ~22pt name)
                    Text("VS")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.yorkerTextTert)
                        .frame(width: 48)
                        .padding(.top, 20) // nudge so VS sits roughly mid-flag

                    heroTeam(
                        team: match.team2, scores: match.team2Scores,
                        isWinner: match.status?.lowercased().contains(match.team2.lowercased()) == true,
                        align: .trailing
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .offset(y: heroOn ? 0 : 20).opacity(heroOn ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1), value: heroOn)

                // ── Status Banner ─────────────────────────────────────────────
                if let status = match.status {
                    statusBanner(status)
                        .padding(.horizontal, 20)
                        .offset(y: heroOn ? 0 : 12).opacity(heroOn ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.2), value: heroOn)
                }

                // ── Venue ──────────────────────────────────────────────────────
                if let venue = match.venue {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundColor(.yorkerTextTert)
                        Text(venue)
                            .font(.system(size: 12))
                            .foregroundColor(.yorkerTextTert)
                            .lineLimit(1)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                    .offset(y: heroOn ? 0 : 8).opacity(heroOn ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.25), value: heroOn)
                } else {
                    Spacer().frame(height: 28)
                }
            }
        }
        // No clipShape, no shadow — gradient fades into yorkerBG so the edge is invisible
    }

    // MARK: Hero Team Panel

    /// Renders a single team column (flag, short name, scores).
    /// `align` flips horizontal alignment so team 1 is left-anchored and team 2 is right-anchored.
    private func heroTeam(team: String, scores: [Score], isWinner: Bool, align: HorizontalAlignment) -> some View {
        let left = align == .leading
        return VStack(alignment: align, spacing: 6) {
            // Large flag emoji as the visual anchor of each team column
            Text(team.teamFlag)
                .font(.system(size: 54))
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 6)

            // Short name + optional trophy icon (placed on the outside edge)
            HStack(spacing: 4) {
                if !left && isWinner {
                    Image(systemName: "trophy.fill").font(.system(size: 11)).foregroundColor(.yorkerGold)
                }
                Text(team.teamShort)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(isWinner ? .yorkerAccent : .white)
                if left && isWinner {
                    Image(systemName: "trophy.fill").font(.system(size: 11)).foregroundColor(.yorkerGold)
                }
            }

            // Full country name in tertiary text
            Text(team)
                .font(.system(size: 10))
                .foregroundColor(.yorkerTextTert)
                .lineLimit(1)

            Spacer().frame(height: 4)

            // Scores — or "Yet to bat" placeholder
            if scores.isEmpty {
                Text("Yet to bat")
                    .font(.system(size: 13)).italic()
                    .foregroundColor(.yorkerTextSec)
            } else {
                ForEach(scores.indices, id: \.self) { i in
                    VStack(alignment: align, spacing: 2) {
                        // Innings label only shown in multi-innings matches (Test / 2nd ODI innings)
                        if scores.count > 1 {
                            Text(i == 0 ? "1st Inn" : "2nd Inn")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.yorkerTextTert)
                        }
                        // Latest innings score is largest; earlier innings are muted
                        Text(scores[i].shortFormatted)
                            .font(.system(
                                size: i == scores.count - 1 ? 30 : 18,
                                weight: .black, design: .rounded
                            ))
                            .foregroundColor(i == scores.count - 1 ? .white : .yorkerTextSec)
                            // Numeric content transition animates digit changes during live updates
                            .contentTransition(.numericText())
                        if let o = scores[i].o, i == scores.count - 1 {
                            Text("\(String(format: "%.1f", o)) overs")
                                .font(.system(size: 11))
                                .foregroundColor(.yorkerTextSec)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: left ? .leading : .trailing)
    }

    // MARK: Status Banner

    private func statusBanner(_ status: String) -> some View {
        let color: Color = match.isLive ? .yorkerAccent : .yorkerGold
        let icon = match.isLive ? "dot.radiowaves.left.and.right" : "checkmark.seal.fill"
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        // Floating pill — not a full-width stripe — so it doesn't create a "box" edge
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(color.opacity(0.13))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.8))
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Tab Bar

    /// Custom segmented control using `matchedGeometryEffect` so the accent underline
    /// animates smoothly between tabs rather than cross-fading.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ScorecardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        vm.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: vm.selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(vm.selectedTab == tab ? .yorkerAccent : .yorkerTextSec)
                            .padding(.vertical, 14)

                        // Green underline slides via matchedGeometryEffect — id must be unique per tab
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(vm.selectedTab == tab ? Color.yorkerAccent : Color.clear)
                            .frame(height: 3)
                            .matchedGeometryEffect(id: "tabLine_\(tab.rawValue)", in: ns)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }
        }
        .background(Color.yorkerBG)
        .overlay(Rectangle().fill(Color.yorkerDivider.opacity(0.5)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Tab Content

    /// Sliding transitions — insertion from the side the tab visually "comes from",
    /// removal to the opposite side. This gives a carousel feel without a page view.
    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .scorecard:
            scorecardView
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal:   .move(edge: .trailing).combined(with: .opacity)
                ))
        case .info:
            infoView
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    // MARK: Scorecard Tab

    private var scorecardView: some View {
        VStack(spacing: 16) {
            if let scores = match.score, !scores.isEmpty {
                // Render an InningsCard for each team that has batted
                if !match.team1Scores.isEmpty {
                    InningsCard(teamName: match.team1, teamFlag: match.team1.teamFlag, scores: match.team1Scores)
                }
                if !match.team2Scores.isEmpty {
                    InningsCard(teamName: match.team2, teamFlag: match.team2.teamFlag, scores: match.team2Scores)
                }
            } else {
                EmptyStateView(icon: "📋", title: "No scorecard yet", subtitle: "Match hasn't started or data unavailable")
            }
            Spacer(minLength: 40)
        }
    }

    // MARK: Info Tab

    private var infoView: some View {
        VStack(spacing: 10) {
            InfoRow(icon: "sportscourt.fill",      label: "Format",  value: match.matchTypeLabel)
            if let v = match.venue    { InfoRow(icon: "mappin.and.ellipse", label: "Venue",   value: v) }
            if let d = match.dateTimeGMT ?? match.date { InfoRow(icon: "calendar",   label: "Date",    value: d.matchDate) }
            InfoRow(icon: "flag.2.crossed.fill",   label: "Teams",   value: "\(match.team1) vs \(match.team2)")
            if let s = match.status   { InfoRow(icon: "info.circle.fill",  label: "Status",  value: s) }
            Spacer(minLength: 40)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - InningsCard

/// Displays a team's innings breakdown — score hero, run-rate pill, wickets progress bar.
/// The animated bar uses a `@State var barOn` flag triggered via `onAppear` for a
/// spring-loaded entrance that draws attention to the current over count.
struct InningsCard: View {
    let teamName: String
    let teamFlag: String
    let scores: [Score]
    @State private var barOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Team header
            HStack(spacing: 10) {
                Text(teamFlag).font(.system(size: 24))
                Text(teamName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                MatchTypeBadge(type: scores.count > 1 ? "2 Inn" : "1 Inn")
            }

            ForEach(scores.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 12) {
                    // Innings label only for multi-innings matches
                    if scores.count > 1 {
                        Text(scores[i].inning ?? "Innings \(i+1)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.yorkerTextSec)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.yorkerCardAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    // Score hero — large numerals are the visual centrepiece
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(scores[i].shortFormatted)
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        if let o = scores[i].o {
                            Text("(\(String(format: "%.1f", o)) ov)")
                                .font(.system(size: 14))
                                .foregroundColor(.yorkerTextSec)
                                .padding(.bottom, 6)
                        }
                        Spacer()
                    }

                    // Stat pills — Run Rate, Wickets, Overs — only when overs data is present
                    if let o = scores[i].o, o > 0, let r = scores[i].r {
                        HStack(spacing: 8) {
                            statPill("Run Rate", String(format: "%.2f", Double(r)/o), accent: true)
                            statPill("Wickets",  "\(scores[i].w ?? 0)")
                            statPill("Overs",    String(format: "%.1f", o))
                        }
                    }

                    // Wickets progress bar — colour shifts green→blue→orange→red as wickets fall
                    if let w = scores[i].w {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Wickets")
                                    .font(.system(size: 11))
                                    .foregroundColor(.yorkerTextSec)
                                Spacer()
                                Text("\(w)/10")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(barColor(w).first ?? .white)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.yorkerCardAlt).frame(height: 6)
                                    Capsule()
                                        .fill(LinearGradient(colors: barColor(w), startPoint: .leading, endPoint: .trailing))
                                        // Animate width from 0 → actual proportion on appear
                                        .frame(width: barOn ? geo.size.width * min(CGFloat(w)/10, 1) : 0, height: 6)
                                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3 + Double(i) * 0.1), value: barOn)
                                }
                            }.frame(height: 6)
                        }
                        .onAppear { barOn = true }
                    }
                }

                if i < scores.count - 1 {
                    Divider().background(Color.yorkerDivider).padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .background(Color.yorkerCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    /// Returns a two-stop gradient that shifts colour based on wickets fallen —
    /// green (0–3) → blue (4–6) → orange (7–9) → red (10, all out).
    private func barColor(_ w: Int) -> [Color] {
        switch w {
        case 0...3:  return [Color.yorkerAccent,   Color.yorkerAccent.opacity(0.5)]
        case 4...6:  return [Color.yorkerAccent2,  Color.yorkerAccent2.opacity(0.5)]
        case 7...9:  return [Color.yorkerOrange,   Color.yorkerOrange.opacity(0.5)]
        default:     return [Color.yorkerLive,     Color.yorkerLive.opacity(0.5)]
        }
    }

    private func statPill(_ label: String, _ value: String, accent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(accent ? .yorkerAccent : .white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.yorkerTextSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(Color.yorkerCardAlt)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - InfoRow

/// A single labelled info row with a tinted icon — used in the Match Info tab.
struct InfoRow: View {
    let icon: String; let label: String; let value: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon square with muted accent background
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.yorkerAccent.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.yorkerAccent)
            }
            // Fixed-width label column keeps all values left-aligned
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.yorkerTextSec)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.yorkerCard)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}


#Preview {
    NavigationStack {
        MatchDetailView(match: Match.mockMatches[0])
    }
}
