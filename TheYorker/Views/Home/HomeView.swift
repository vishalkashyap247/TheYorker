//
//  HomeView.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import SwiftUI

// MARK: - HomeView

/// Main landing screen — stats strip, filter chips, live-now horizontal scroll, and match cards.
struct HomeView: View {
    // @Observable view model — SwiftUI tracks individual property reads automatically.
    @State private var vm = MatchesViewModel()
    @State private var cardsOn = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.yorkerBG.ignoresSafeArea()

                // Ambient radial glow at the top — gives depth to the flat navy bg
                RadialGradient(
                    colors: [Color.yorkerAccent.opacity(0.1), .clear],
                    center: .init(x: 0.5, y: 0.0),
                    startRadius: 0, endRadius: 320
                )
                .frame(height: 280).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        statsStrip
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 14)

                        filterBar
                            .padding(.bottom, 14)

                        contentBody
                            .padding(.horizontal, 16)
                    }
                }
                .refreshable { await vm.refresh() }
                .searchable(text: $vm.searchText, prompt: "Search matches…")
            }
            .navigationTitle("The Yorker")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.yorkerBG.opacity(0.94), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            // NavigationLink(value:) — type-safe navigation; destination registered once here.
            .navigationDestination(for: Match.self) { match in
                MatchDetailView(match: match)
            }
            .task { await vm.load() }
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        Button { Task { await vm.refresh() } } label: {
            ZStack {
                Circle()
                    .fill(Color.yorkerCardAlt)
                    .frame(width: 32, height: 32)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.yorkerAccent)
                    // Spin while refreshing using a continuous linear rotation
                    .rotationEffect(.degrees(vm.isRefreshing ? 360 : 0))
                    .animation(
                        vm.isRefreshing
                            ? .linear(duration: 0.7).repeatForever(autoreverses: false)
                            : .default,
                        value: vm.isRefreshing
                    )
            }
        }
    }

    // MARK: - Stats Strip

    /// Always counts from ALL matches, never from the currently filtered subset.
    /// This gives users a full picture of what's happening regardless of their active filter.
    @ViewBuilder
    private var statsStrip: some View {
        if case .loaded = vm.loadingState {
            HStack(spacing: 10) {
                if vm.totalLiveCount > 0 {
                    statChip("\(vm.totalLiveCount) Live", color: .yorkerLive, icon: "circle.fill")
                }
                statChip("\(vm.totalUpcomingCount) Upcoming", color: .yorkerAccent2, icon: "calendar")
                statChip("\(vm.totalRecentCount) Finished",   color: .yorkerTextSec,  icon: "checkmark.circle")
                Spacer()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func statChip(_ label: String, color: Color, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MatchFilter.allCases, id: \.self) { f in
                    FilterChip(
                        title: filterLabel(f),
                        icon: filterIcon(f),
                        iconColor: filterIconColor(f),
                        isSelected: vm.selectedFilter == f
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                            vm.selectedFilter = f
                            // Brief hide-then-show so new cards animate in fresh
                            cardsOn = false
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 40_000_000)
                            withAnimation { cardsOn = true }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterLabel(_ f: MatchFilter) -> String {
        switch f {
        case .all:      return "All"
        case .live:     return "Live"
        case .upcoming: return "Upcoming"
        case .recent:   return "Recent"
        }
    }

    private func filterIcon(_ f: MatchFilter) -> String? {
        switch f {
        case .all:      return nil
        case .live:     return "circle.fill"
        case .upcoming: return "calendar"
        case .recent:   return "checkmark.circle.fill"
        }
    }

    private func filterIconColor(_ f: MatchFilter) -> Color {
        switch f {
        case .all:      return .yorkerTextSec
        case .live:     return .yorkerLive
        case .upcoming: return .yorkerAccent2
        case .recent:   return .yorkerAccent
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentBody: some View {
        switch vm.loadingState {
        case .idle, .loading:
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in SkeletonMatchCard() }
            }
            .transition(.opacity)
        case .loaded:
            loadedBody
                .transition(.opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.45)) { cardsOn = true }
                }
        case .error(let msg):
            VStack(spacing: 16) {
                EmptyStateView(icon: "📡", title: "Can't load matches", subtitle: msg)
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.yorkerBG)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.yorkerAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 60)
        }
    }

    @ViewBuilder
    private var loadedBody: some View {
        VStack(spacing: 28) {
            // Live Now horizontal strip — only visible when "All" filter is selected and there are live matches
            if vm.selectedFilter == .all && vm.hasLive {
                liveNowSection
            }

            // Main vertical match list
            if vm.filteredMatches.isEmpty {
                EmptyStateView(icon: "🏏", title: "No matches", subtitle: "Try a different filter")
                    .padding(.top, 32)
            } else {
                matchListSection
            }
        }
    }

    // MARK: - Live Now Section

    private var liveNowSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                LiveBadge()
                Text("Live Now")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(vm.liveMatches.count) match\(vm.liveMatches.count == 1 ? "" : "es")")
                    .font(.system(size: 12))
                    .foregroundColor(.yorkerTextSec)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(vm.liveMatches.enumerated()), id: \.element.id) { idx, m in
                        NavigationLink(value: m) {
                            LiveMatchCard(match: m)
                                .opacity(cardsOn ? 1 : 0)
                                // Stagger cards from left to right for a cascade entrance
                                .animation(
                                    .easeIn(duration: 0.25)
                                        .delay(Double(idx) * 0.07),
                                    value: cardsOn
                                )
                        }
                        .buttonStyle(LiveCardButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded { haptic.impactOccurred() })
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 2)
            }
            // Allow cards to render outside the scroll view's clip bounds (shows shadow)
            .scrollClipDisabled()
        }
    }

    // MARK: - Match List

    private var matchListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                vm.selectedFilter == .all ? "All Matches" : vm.selectedFilter.rawValue,
                subtitle: "\(vm.filteredMatches.count) matches"
            )

            ForEach(Array(vm.filteredMatches.enumerated()), id: \.element.id) { idx, m in
                NavigationLink(value: m) {
                    MatchCard(match: m)
                        .opacity(cardsOn ? 1 : 0)
                        // Slightly tighter stagger than live cards — list is longer
                        .animation(
                            .easeIn(duration: 0.25)
                                .delay(Double(idx) * 0.055),
                            value: cardsOn
                        )
                }
                .buttonStyle(MatchCardButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { haptic.impactOccurred() })
            }

            Spacer(minLength: 24)
        }
    }
}

// MARK: - Match Card Button Style

/// Spring scale-down on press — subtle enough not to distract but confirms the tap.
private struct MatchCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - MatchCard

/// Standard match card used in the main vertical list.
/// Layout: header (format + live + date + venue) → teams side-by-side → footer (status).
struct MatchCard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            cardTeams
            cardFooter
        }
        .background(match.isLive ? LinearGradient.yorkerLiveGlow() : LinearGradient(colors: [Color.yorkerCard, Color.yorkerCard], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    match.isLive
                        ? LinearGradient(colors: [Color.yorkerAccent.opacity(0.5), Color.yorkerAccent.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.yorkerDivider.opacity(0.5), Color.yorkerDivider.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(
            color: match.isLive ? Color.yorkerAccent.opacity(0.12) : Color.black.opacity(0.25),
            radius: 12, x: 0, y: 6
        )
    }

    // MARK: Card Header

    /// Format badge + live indicator + date + venue on two rows.
    private var cardHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                MatchTypeBadge(type: match.matchTypeLabel)
                if match.isLive { LiveBadge() }
                Spacer()
                if let d = match.date {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 10))
                        Text(d.matchDate).font(.system(size: 11))
                    }
                    .foregroundColor(.yorkerTextSec)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            if let venue = match.venue {
                HStack(spacing: 4) {
                    Image(systemName: "mappin").font(.system(size: 10))
                    Text(venue).font(.system(size: 11)).lineLimit(1)
                    Spacer()
                }
                .foregroundColor(.yorkerTextTert)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: Card Teams

    /// Both teams rendered side-by-side with a VS bubble between them.
    private var cardTeams: some View {
        HStack(alignment: .top, spacing: 0) {
            // Team 1 — left aligned
            teamPanel(
                team: match.team1,
                scores: match.team1Scores,
                align: .leading,
                isWinner: match.status?.lowercased().contains(match.team1.lowercased()) == true
            )

            // VS bubble
            VStack {
                Text("VS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.yorkerTextTert)
                    .frame(width: 28, height: 28)
                    .background(Color.yorkerCardAlt)
                    .clipShape(Circle())
            }
            .padding(.top, 10)

            // Team 2 — right aligned
            teamPanel(
                team: match.team2,
                scores: match.team2Scores,
                align: .trailing,
                isWinner: match.status?.lowercased().contains(match.team2.lowercased()) == true
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func teamPanel(team: String, scores: [Score], align: HorizontalAlignment, isWinner: Bool) -> some View {
        let isLeft = align == .leading
        return VStack(alignment: align, spacing: 5) {
            // Flag + short name block
            HStack(spacing: 6) {
                if !isLeft { Spacer() }
                if isLeft {
                    Text(team.teamFlag).font(.system(size: 30))
                }
                VStack(alignment: align, spacing: 1) {
                    HStack(spacing: 4) {
                        if !isLeft && isWinner {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yorkerGold)
                        }
                        Text(team.teamShort)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(isWinner ? .yorkerAccent : .white)
                        if isLeft && isWinner {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yorkerGold)
                        }
                    }
                    Text(team)
                        .font(.system(size: 10))
                        .foregroundColor(.yorkerTextTert)
                        .lineLimit(1)
                }
                if !isLeft {
                    Text(team.teamFlag).font(.system(size: 30))
                }
                if isLeft { Spacer() }
            }

            // Score rows — or "Yet to bat" when no innings have started
            if scores.isEmpty {
                Text("Yet to bat")
                    .font(.system(size: 12)).italic()
                    .foregroundColor(.yorkerTextSec)
            } else {
                ForEach(scores.indices, id: \.self) { i in
                    VStack(alignment: align, spacing: 1) {
                        // Innings label only for multi-innings matches
                        if scores.count > 1 {
                            Text(i == 0 ? "1st" : "2nd")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.yorkerTextTert)
                        }
                        // Latest innings score is largest; earlier innings are muted
                        Text(scores[i].shortFormatted)
                            .font(.system(
                                size: i == scores.count - 1 ? 24 : 16,
                                weight: .black, design: .rounded
                            ))
                            .foregroundColor(i == scores.count - 1 ? .white : .yorkerTextSec)
                            .contentTransition(.numericText())
                        if let o = scores[i].o, i == scores.count - 1 {
                            Text("\(String(format: "%.1f", o)) ov")
                                .font(.system(size: 11))
                                .foregroundColor(.yorkerTextSec)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isLeft ? .leading : .trailing)
        .padding(.vertical, 8)
    }

    // MARK: Card Footer

    /// Status line with contextual icon and chevron.
    private var cardFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.yorkerDivider)
                .frame(height: 1)
                .padding(.horizontal, 16)

            HStack(spacing: 6) {
                Image(systemName: match.isLive ? "dot.radiowaves.left.and.right" : "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(statusColor)
                Text(match.status ?? "–")
                    .font(.system(size: 12, weight: match.isLive ? .medium : .regular))
                    .foregroundColor(statusColor)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.yorkerTextTert)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
    }

    /// Green for live, gold for won, muted secondary for all other states.
    private var statusColor: Color {
        guard let s = match.status?.lowercased() else { return .yorkerTextSec }
        if match.isLive { return .yorkerAccent }
        if s.contains("won") { return .yorkerGold }
        return .yorkerTextSec
    }
}

// MARK: - Live Card Button Style

/// Slightly more aggressive scale-down than `MatchCardButtonStyle` to make tapping
/// the fixed-width live card feel more tactile.
private struct LiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - LiveMatchCard

/// Horizontally-scrolling card used in the "Live Now" strip.
/// Includes a "Track / Stop" button to start or end a Live Activity for this match.
struct LiveMatchCard: View {
    let match: Match
    @AppStorage("useMockData") private var useMock = true

    /// Error message surfaced when `LiveActivityManager.start()` throws.
    /// Shown in an alert so the user understands why the Live Activity didn't start.
    @State private var laError: String?
    /// Prevents double-tapping the Track button while the async start is in flight.
    @State private var isStarting = false

    /// Derives tracking state from the `@Observable` singleton so the button label stays
    /// accurate even after the card is scrolled off-screen and back into view.
    ///
    /// We read from `LiveActivityManager.shared` rather than local `@State` because the
    /// manager is the authoritative source of truth across all cards. If we used `@State`,
    /// scrolling the card off-screen would reset it and the button would show the wrong label.
    private var isTracking: Bool {
        LiveActivityManager.shared.isTracking(match.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header: format badge + live badge
            HStack {
                MatchTypeBadge(type: match.matchTypeLabel)
                Spacer()
                LiveBadge()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

            // Teams — stacked vertically, score right-aligned
            VStack(spacing: 10) {
                liveTeamRow(match.team1, scores: match.team1Scores)
                liveTeamRow(match.team2, scores: match.team2Scores)
            }
            .padding(.horizontal, 16)

            Rectangle().fill(Color.yorkerDivider).frame(height: 1)
                .padding(.horizontal, 16).padding(.top, 14)

            // Status text + Track button on the same row
            HStack(spacing: 5) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 10))
                    .foregroundColor(.yorkerAccent)
                Text(match.status ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.yorkerAccent)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Track / Stop Live Activity button
                // Green = not tracking (tap to start), Red = actively tracking (tap to stop)
                Button {
                    let lam = LiveActivityManager.shared
                    if isTracking {
                        lam.end(match: match)
                    } else {
                        guard !isStarting else { return }
                        isStarting = true
                        Task {
                            do {
                                try await lam.start(match: match, useMock: useMock)
                            } catch {
                                laError = error.localizedDescription
                            }
                            isStarting = false
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        if isStarting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else if isTracking {
                            // Solid white circle indicates "live" — same language as the LIVE badge
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                        } else {
                            Image(systemName: "dot.radiowaves.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(isTracking ? "Stop" : (isStarting ? "Starting…" : "Track"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    // Always white text — works on both the green (track) and red (stop) backgrounds
                    .foregroundColor(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(
                        isTracking
                            ? Color.yorkerLive           // red = active, tap to stop
                            : Color.yorkerAccent         // green = idle, tap to track
                    )
                    .clipShape(Capsule())
                    // Subtle glow reinforces the active/inactive colour
                    .shadow(
                        color: (isTracking ? Color.yorkerLive : Color.yorkerAccent).opacity(0.35),
                        radius: 6, x: 0, y: 2
                    )
                }
                .buttonStyle(.plain)
                .disabled(isStarting)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTracking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        // Alert shown when start() throws — tells the user exactly what went wrong
        .alert("Live Activity Error", isPresented: .init(
            get: { laError != nil },
            set: { if !$0 { laError = nil } }
        )) {
            Button("OK", role: .cancel) { laError = nil }
        } message: {
            Text(laError ?? "")
        }
        .frame(width: 280)
        .background(
            ZStack {
                Color(hex: "0B1828")
                // Diagonal accent glow from top-right — reinforces the live card visual language
                LinearGradient(
                    colors: [Color.yorkerAccent.opacity(0.12), .clear],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.yorkerAccent.opacity(0.55), Color.yorkerAccent.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.yorkerAccent.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    private func liveTeamRow(_ team: String, scores: [Score]) -> some View {
        HStack(spacing: 10) {
            Text(team.teamFlag).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 1) {
                Text(team.teamShort)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(team)
                    .font(.system(size: 10))
                    .foregroundColor(.yorkerTextTert)
                    .lineLimit(1)
            }
            Spacer()
            // Score — shown only when available, "—" dash otherwise
            if let s = scores.last {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(s.shortFormatted)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    if let o = s.o {
                        Text("\(String(format: "%.1f", o)) ov")
                            .font(.system(size: 10))
                            .foregroundColor(.yorkerTextSec)
                    }
                }
            } else {
                Text("—").font(.system(size: 18, weight: .bold)).foregroundColor(.yorkerTextTert)
            }
        }
    }
}

#Preview { HomeView() }
