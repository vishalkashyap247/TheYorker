//
//  ScheduleView.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import SwiftUI

// MARK: - ScheduleView

/// Full match schedule with date-grouped sections.
/// Each group is sorted ascending by ISO date string — works because the API returns
/// dates in "yyyy-MM-dd" format, which sorts lexicographically the same as chronologically.
struct ScheduleView: View {

    // @Observable view model — SwiftUI tracks individual property reads, no `@StateObject` needed.
    @State private var vm = MatchesViewModel()

    /// Groups filtered matches by their `date` key and sorts oldest-first.
    private var grouped: [(key: String, value: [Match])] {
        let dict = Dictionary(grouping: vm.filteredMatches) { $0.date ?? "Unknown" }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.loadingState {
                case .idle, .loading:
                    // Show skeleton cards while data is in-flight
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<5, id: \.self) { _ in SkeletonMatchCard().padding(.horizontal, 16) }
                        }.padding(.top, 16)
                    }
                case .loaded:
                    scheduleList
                case .error(let msg):
                    EmptyStateView(icon: "📡", title: "Can't load schedule", subtitle: msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yorkerBG.ignoresSafeArea())
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.yorkerBG, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $vm.searchText, prompt: "Search matches…")
            // NavigationLink(value:) — push-based navigation; the destination is declared once here
            // rather than inside every row, keeping row views free of navigation coupling.
            .navigationDestination(for: Match.self) { MatchDetailView(match: $0) }
            .task { await vm.load() }
            .refreshable { await vm.refresh() }
        }
    }

    // MARK: - Schedule List

    /// Lazy sectioned list with sticky date headers.
    /// `pinnedViews: [.sectionHeaders]` keeps the day label visible while scrolling within a group.
    private var scheduleList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if grouped.isEmpty {
                    EmptyStateView(icon: "📅", title: "No matches", subtitle: "Check back soon")
                        .padding(.top, 60)
                } else {
                    ForEach(grouped, id: \.key) { group in
                        Section {
                            VStack(spacing: 10) {
                                ForEach(group.value) { match in
                                    NavigationLink(value: match) {
                                        ScheduleRow(match: match)
                                    }
                                    // ButtonStyle suppresses the default push-highlight;
                                    // ScheduleRowButtonStyle provides a custom spring press effect.
                                    .buttonStyle(ScheduleRowButtonStyle())
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 16)
                        } header: {
                            dateHeader(group.key)
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Date Header

    private func dateHeader(_ d: String) -> some View {
        HStack(spacing: 8) {
            Text(d.dayLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.yorkerTextSec)
            // "TODAY" pill only shown for today's date — makes it easy to scan
            if d.isToday {
                Text("TODAY")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.yorkerAccent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.yorkerAccent.opacity(0.14))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        // Match the page background so the header blends as it pins
        .background(Color.yorkerBG)
    }
}

// MARK: - ScheduleRow Button Style

/// Custom `ButtonStyle` that replaces the default opacity flash with a spring scale press,
/// matching the tactile feel of the live match cards on HomeView.
private struct ScheduleRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.978 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - ScheduleRow

/// A single match row in the schedule list — left time column, accent divider line, main content.
struct ScheduleRow: View {
    let match: Match

    var body: some View {
        HStack(spacing: 0) {

            // MARK: Time Column
            VStack(spacing: 6) {
                if match.isLive {
                    // Compact live dot — constrained to fit within the 68pt column width
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.yorkerLive)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(Color.yorkerLive)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.yorkerLive.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.yorkerLive.opacity(0.3), lineWidth: 0.8))
                } else {
                    // Show start time or "TBD" when no time is available
                    Text((match.dateTimeGMT ?? match.date ?? "").timeOnly.isEmpty ? "TBD" : (match.dateTimeGMT ?? match.date ?? "").timeOnly)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.yorkerAccent2)
                }
                MatchTypeBadge(type: match.matchTypeLabel)
            }
            .frame(width: 68)
            .padding(.vertical, 14)

            // MARK: Accent Divider
            // The gradient fades to transparent at the bottom so it doesn't look clipped
            Rectangle()
                .fill(match.isLive
                      ? LinearGradient(colors: [Color.yorkerAccent, Color.yorkerAccent.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Color.yorkerDivider, Color.yorkerDivider], startPoint: .top, endPoint: .bottom))
                .frame(width: 2)
                .padding(.vertical, 14)

            // MARK: Main Content
            VStack(alignment: .leading, spacing: 6) {
                // Teams row
                HStack(spacing: 6) {
                    Text(match.team1.teamFlag).font(.system(size: 18))
                    Text(match.team1.teamShort)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("vs")
                        .font(.system(size: 12))
                        .foregroundColor(.yorkerTextTert)
                    Text(match.team2.teamFlag).font(.system(size: 18))
                    Text(match.team2.teamShort)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Venue — optional, shown when available
                if let venue = match.venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin").font(.system(size: 9))
                        Text(venue).font(.system(size: 11)).lineLimit(1)
                    }
                    .foregroundColor(.yorkerTextTert)
                }

                // Scores (only rendered when at least one team has batted)
                if !match.team1Scores.isEmpty || !match.team2Scores.isEmpty {
                    HStack(spacing: 10) {
                        if let s = match.team1Scores.last {
                            scoreChip(team: match.team1.teamShort, score: s.shortFormatted)
                        }
                        if let s = match.team2Scores.last {
                            scoreChip(team: match.team2.teamShort, score: s.shortFormatted)
                        }
                    }
                }

                // Status line — green when live, muted otherwise
                if let status = match.status {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundColor(match.isLive ? .yorkerAccent : .yorkerTextSec)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Disclosure chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.yorkerTextTert)
                .padding(.trailing, 14)
        }
        .background(
            match.isLive
                ? LinearGradient.yorkerLiveGlow()
                : LinearGradient(colors: [Color.yorkerCard, Color.yorkerCard], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(match.isLive ? Color.yorkerAccent.opacity(0.3) : Color.yorkerDivider.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
    }

    // MARK: Score Chip

    private func scoreChip(team: String, score: String) -> some View {
        HStack(spacing: 4) {
            Text(team)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.yorkerTextSec)
            Text(score)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.yorkerCardAlt)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

#Preview { ScheduleView() }
