//
//  ContentView.swift
//  TheYorker
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import SwiftUI

// MARK: - ContentView

/// Root container that owns the tab bar and applies app-wide UIKit appearance customisations.
struct ContentView: View {
    @State private var tab: Tab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home",     systemImage: tab == .home     ? "house.fill"      : "house") }
                .tag(Tab.home)

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: tab == .schedule ? "calendar.circle.fill" : "calendar") }
                .tag(Tab.schedule)

            SettingsView()
                .tabItem { Label("Settings", systemImage: tab == .settings ? "gearshape.fill"  : "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Color.yorkerAccent)
        .onAppear { styleTabBar() }
        // Re-apply search bar style on every tab switch because SwiftUI may recreate
        // the UISearchBar instance when a tab's NavigationStack is first rendered.
        .onChange(of: tab) { styleSearchBar() }
    }

    // MARK: - Tab Bar Styling

    private func styleTabBar() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Color(hex: "0A1020"))

        let item = UITabBarItemAppearance()
        item.normal.iconColor   = UIColor(Color.yorkerTextTert)
        item.selected.iconColor = UIColor(Color.yorkerAccent)
        item.normal.titleTextAttributes   = [.foregroundColor: UIColor(Color.yorkerTextTert)]
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.yorkerAccent)]

        a.stackedLayoutAppearance       = item
        a.inlineLayoutAppearance        = item
        a.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance   = a
        UITabBar.appearance().scrollEdgeAppearance = a

        styleSearchBar()
    }

    // MARK: - Search Bar Styling

    /// Styles the system `UISearchBar` to match the dark navy theme.
    ///
    /// Two passes are needed because `UIAppearance` only applies to **new** instances
    /// created after the proxy is set. Bars that were already rendered (e.g. on the
    /// currently visible tab) will not pick up the appearance-proxy change, so we
    /// walk the live view hierarchy and update them directly on the next run loop tick.
    private func styleSearchBar() {
        // Pass 1 — UIAppearance proxy: catches future instances
        let fieldBG = UIColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 1)
        let hint    = UIColor(white: 1, alpha: 0.28)
        let accent  = UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1)
        UISearchBar.appearance().backgroundImage = UIImage()
        UISearchBar.appearance().backgroundColor = UIColor(Color(hex: "0A1020"))
        UISearchBar.appearance().tintColor       = accent
        UISearchTextField.appearance().backgroundColor        = fieldBG
        UISearchTextField.appearance().textColor              = .white
        UISearchTextField.appearance().tintColor              = accent
        UISearchTextField.appearance().attributedPlaceholder  = NSAttributedString(
            string: "Search matches…", attributes: [.foregroundColor: hint])

        // Pass 2 — view hierarchy walk: fixes already-rendered instances
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else { return }
            Self.applySearchStyle(in: window)
        }
    }

    private static func applySearchStyle(in view: UIView) {
        let fieldBG = UIColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 1) // navy card
        let hint    = UIColor(white: 1, alpha: 0.28)
        let accent  = UIColor(red: 0, green: 0.902, blue: 0.463, alpha: 1)  // #00E676

        if let tf = view as? UISearchTextField {
            tf.backgroundColor = fieldBG
            tf.textColor       = .white
            tf.tintColor       = accent
            tf.attributedPlaceholder = NSAttributedString(
                string: "Search matches…",
                attributes: [.foregroundColor: hint]
            )
            // Tint the magnifying-glass icon to match the muted placeholder colour
            if let glassView = tf.leftView as? UIImageView {
                glassView.image = glassView.image?.withRenderingMode(.alwaysTemplate)
                glassView.tintColor = hint
            }
            return
        }

        if let sb = view as? UISearchBar {
            sb.backgroundImage = UIImage()           // removes the default grey bar background
            sb.backgroundColor = UIColor(red: 0.039, green: 0.063, blue: 0.125, alpha: 1)
            sb.tintColor       = accent
        }

        // Recurse into all subviews
        for sub in view.subviews { applySearchStyle(in: sub) }
    }
}

// MARK: - Tab Enum

enum Tab { case home, schedule, settings }

// MARK: - Settings

/// Settings screen — favourite team picker, API toggle, Live Activity preview, about.
struct SettingsView: View {

    @AppStorage("favouriteTeam") private var fav: String = "India"
    @AppStorage("useMockData")   private var mock: Bool  = true
    /// Surfaced when the Settings "Preview Live Activity" button fails to start an activity.
    @State private var laError: String?

    private let teams = [
        "India","Australia","England","Pakistan",
        "New Zealand","South Africa","West Indies","Sri Lanka",
        "Bangladesh","Afghanistan","Ireland","Zimbabwe"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.yorkerBG.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        favouriteTeamSection
                        apiSection
                        liveActivitySection
                        aboutSection
                        Spacer(minLength: 32)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.yorkerBG, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            // Show error from async start() when it throws
            .alert("Live Activity Error", isPresented: .init(
                get: { laError != nil },
                set: { if !$0 { laError = nil } }
            )) {
                Button("OK", role: .cancel) { laError = nil }
            } message: {
                Text(laError ?? "")
            }
        }
    }

    // MARK: Favourite Team Section

    private var favouriteTeamSection: some View {
        block(title: "Favourite Team", icon: "star.fill") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(teams, id: \.self) { team in
                    teamTile(team)
                }
            }
            .padding(14)
        }
    }

    private func teamTile(_ team: String) -> some View {
        let selected = fav == team
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { fav = team }
        } label: {
            VStack(spacing: 5) {
                Text(team.teamFlag).font(.system(size: 26))
                Text(team.teamShort)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? Color.yorkerBG : .yorkerTextSec)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.yorkerAccent : Color.yorkerCardAlt)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? Color.clear : Color.yorkerDivider, lineWidth: 1))
            .shadow(color: selected ? Color.yorkerAccent.opacity(0.35) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(selected ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: selected)
    }

    // MARK: API Section

    private var apiSection: some View {
        block(title: "API", icon: "network") {
            VStack(spacing: 0) {
                Toggle(isOn: $mock) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Mock Data Mode")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("No API key needed — uses built-in demo data")
                            .font(.system(size: 12))
                            .foregroundColor(.yorkerTextSec)
                    }
                }
                .tint(Color.yorkerAccent)
                .padding(16)

                Rectangle().fill(Color.yorkerDivider).frame(height: 1).padding(.horizontal, 16)

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.yorkerAccent2.opacity(0.12)).frame(width: 32, height: 32)
                        Image(systemName: "key.fill").font(.system(size: 13)).foregroundColor(.yorkerAccent2)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Get Free API Key")
                            .font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                        Text("cricapi.com  ·  100 requests/day")
                            .font(.system(size: 12)).foregroundColor(.yorkerTextSec)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundColor(.yorkerAccent2.opacity(0.6))
                }
                .padding(16)
            }
        }
    }

    // MARK: Live Activity Section

    private var liveActivitySection: some View {
        block(title: "Live Activity & Widgets", icon: "sportscourt.fill") {
            VStack(spacing: 0) {
                // Mock toggle — also syncs to App Group so the widget reads the same value
                Toggle(isOn: $mock) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Mock Data Mode")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Use demo scores — no API key needed")
                            .font(.system(size: 12))
                            .foregroundColor(.yorkerTextSec)
                    }
                }
                .tint(Color.yorkerAccent)
                .padding(16)
                .onChange(of: mock) { _, newValue in
                    // Propagate toggle to the App Group so MatchHomeWidget picks it up next refresh
                    UserDefaults(suiteName: "group.com.vishal.TheYorker")?.set(newValue, forKey: "useMockData")
                }

                Rectangle().fill(Color.yorkerDivider).frame(height: 1).padding(.horizontal, 16)

                // Preview button — starts or stops the mock Live Activity
                Button {
                    let lam = LiveActivityManager.shared
                    if mock {
                        if lam.isTracking("mock_ind_aus_001") {
                            lam.endMock()
                        } else {
                            // start() is async throws — wrap in Task so the button closure stays sync
                            Task {
                                do {
                                    try await lam.start(match: .mockMatch, useMock: true)
                                } catch {
                                    laError = error.localizedDescription
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.yorkerAccent.opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yorkerLive)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mock ? "Preview Live Activity" : "Enable Mock Mode first")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            Text("Tap any Live match on Home to track it")
                                .font(.system(size: 12))
                                .foregroundColor(.yorkerTextSec)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.yorkerAccent.opacity(0.6))
                            .font(.system(size: 12))
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                .disabled(!mock)
                .opacity(mock ? 1 : 0.5)
            }
        }
    }

    // MARK: About Section

    private var aboutSection: some View {
        block(title: "About", icon: "info.circle.fill") {
            VStack(spacing: 0) {
                aboutRow("🏏", "The Yorker",  "Cricket companion app")
                divRow
                aboutRow("⚡️", "Built with", "SwiftUI · CricAPI · iOS 17")
                divRow
                aboutRow("👨‍💻", "Developer",  "Vishal Kashyap")
            }
        }
    }

    // MARK: Helper Views

    /// Generic card container with a section label above it.
    @ViewBuilder
    private func block<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.yorkerTextSec)
                .padding(.leading, 4)

            content()
                .background(Color.yorkerCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func aboutRow(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 12) {
            Text(icon).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Text(sub).font(.system(size: 12)).foregroundColor(.yorkerTextSec)
            }
            Spacer()
        }
        .padding(14)
    }

    private var divRow: some View {
        Rectangle().fill(Color.yorkerDivider).frame(height: 1).padding(.horizontal, 14)
    }
}

#Preview { ContentView() }
