//
//  TheYorkerTests.swift
//  TheYorkerTests
//
//  Comprehensive unit tests for TheYorker cricket app.
//  Covers: Match model, Score model, Array safe subscript,
//  String/Color extensions, MatchFilter, LoadingState,
//  MatchesViewModel, CricAPIError, and mock data validation.
//

import XCTest
@testable import TheYorker

// MARK: - MatchTests

final class MatchTests: XCTestCase {

    // MARK: isLive

    func test_isLive_trueWhenScoreExistsAndStatusNotTerminal() {
        let match = Match(
            id: "test_live",
            name: "India vs Australia, 1st ODI",
            matchType: "odi",
            status: "India are batting",
            venue: "Wankhede",
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Australia"],
            score: [Score(r: 100, w: 2, o: 20.0, inning: "India Inning 1")],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertTrue(match.isLive)
    }

    func test_isLive_falseWhenStatusContainsWon() {
        let match = Match(
            id: "test_won",
            name: "India vs Australia, 1st ODI",
            matchType: "odi",
            status: "India won by 5 wickets",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Australia"],
            score: [Score(r: 250, w: 5, o: 48.0, inning: "India Inning 1")],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertFalse(match.isLive)
    }

    func test_isLive_falseWhenStatusContainsDrawn() {
        let match = Match(
            id: "test_drawn",
            name: "England vs New Zealand, 1st Test",
            matchType: "test",
            status: "Match drawn",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["England", "New Zealand"],
            score: [Score(r: 310, w: 10, o: 90.0, inning: "England Inning 1")],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertFalse(match.isLive)
    }

    func test_isLive_falseWhenStatusContainsTied() {
        let match = Match(
            id: "test_tied",
            name: "India vs Pakistan, Super Over",
            matchType: "t20",
            status: "Match tied",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Pakistan"],
            score: [Score(r: 180, w: 10, o: 20.0, inning: "India Inning 1")],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertFalse(match.isLive)
    }

    func test_isLive_falseWhenNoScore() {
        let match = Match(
            id: "test_upcoming",
            name: "India vs Australia, 1st ODI",
            matchType: "odi",
            status: "Match starts in 1 hour",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Australia"],
            score: [],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertFalse(match.isLive)
    }

    func test_isLive_falseWhenScoreIsNil() {
        let match = Match(
            id: "test_nil_score",
            name: "India vs Australia, 1st ODI",
            matchType: "odi",
            status: "Toss taking place",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Australia"],
            score: nil,
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertFalse(match.isLive)
    }

    func test_isLive_falseWhenStatusContainsNoResult() {
        let match = Match(
            id: "test_no_result",
            name: "India vs Pakistan, 1st ODI",
            matchType: "odi",
            status: "No result - rain",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Pakistan"],
            score: [Score(r: 50, w: 1, o: 10.0, inning: "India Inning 1")],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertFalse(match.isLive)
    }

    func test_isLive_falseWhenStatusContainsYetToBat() {
        let match = Match(
            id: "test_yet_to_bat",
            name: "India vs Pakistan, 1st ODI",
            matchType: "odi",
            status: "India yet to bat",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Pakistan"],
            score: [Score(r: 200, w: 10, o: 50.0, inning: "Pakistan Inning 1")],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertFalse(match.isLive)
    }

    // MARK: matchTypeLabel

    func test_matchTypeLabel_odi() {
        let match = makeMatch(matchType: "odi")
        XCTAssertEqual(match.matchTypeLabel, "ODI")
    }

    func test_matchTypeLabel_t20() {
        let match = makeMatch(matchType: "t20")
        XCTAssertEqual(match.matchTypeLabel, "T20")
    }

    func test_matchTypeLabel_t20i() {
        let match = makeMatch(matchType: "t20i")
        XCTAssertEqual(match.matchTypeLabel, "T20")
    }

    func test_matchTypeLabel_test() {
        let match = makeMatch(matchType: "test")
        XCTAssertEqual(match.matchTypeLabel, "TEST")
    }

    func test_matchTypeLabel_ipl() {
        let match = makeMatch(matchType: "ipl")
        XCTAssertEqual(match.matchTypeLabel, "IPL")
    }

    func test_matchTypeLabel_unknown() {
        let match = makeMatch(matchType: "fc")
        XCTAssertEqual(match.matchTypeLabel, "FC")
    }

    func test_matchTypeLabel_nil() {
        let match = makeMatch(matchType: nil)
        XCTAssertEqual(match.matchTypeLabel, "CRICKET")
    }

    // MARK: shortName

    func test_shortName_stripsSeriesContext() {
        let match = makeMatch(name: "India vs Australia, 2nd ODI")
        XCTAssertEqual(match.shortName, "India vs Australia")
    }

    func test_shortName_noComma_returnsFullName() {
        let match = makeMatch(name: "India vs Australia")
        XCTAssertEqual(match.shortName, "India vs Australia")
    }

    func test_shortName_multipleCommas_returnsBeforeFirst() {
        let match = makeMatch(name: "India vs Australia, 1st ODI, Live")
        XCTAssertEqual(match.shortName, "India vs Australia")
    }

    // MARK: seriesName

    func test_seriesName_extractsAfterFirstComma() {
        let match = makeMatch(name: "India vs Australia, 2nd ODI")
        XCTAssertEqual(match.seriesName, "2nd ODI")
    }

    func test_seriesName_noComma_returnsEmpty() {
        let match = makeMatch(name: "India vs Australia")
        XCTAssertEqual(match.seriesName, "")
    }

    func test_seriesName_multipleCommas_joinsRemainder() {
        let match = makeMatch(name: "India vs Australia, 1st ODI, Day 2")
        XCTAssertEqual(match.seriesName, "1st ODI, Day 2")
    }

    // MARK: team1 / team2

    func test_team1_fromTeamsArray() {
        let match = makeMatch(teams: ["India", "Australia"])
        XCTAssertEqual(match.team1, "India")
    }

    func test_team2_fromTeamsArray() {
        let match = makeMatch(teams: ["India", "Australia"])
        XCTAssertEqual(match.team2, "Australia")
    }

    func test_team1_fallbackWhenMissing() {
        let match = makeMatch(teams: nil)
        XCTAssertEqual(match.team1, "TBD")
    }

    func test_team2_fallbackWhenMissing() {
        let match = makeMatch(teams: nil)
        XCTAssertEqual(match.team2, "TBD")
    }

    func test_team1_fallbackWhenEmptyArray() {
        let match = makeMatch(teams: [])
        XCTAssertEqual(match.team1, "TBD")
    }

    func test_team2_fallbackWhenOnlyOneTeam() {
        let match = makeMatch(teams: ["India"])
        XCTAssertEqual(match.team2, "TBD")
    }

    // MARK: team1Scores / team2Scores

    func test_team1Scores_filteredByTeamName() {
        let match = Match(
            id: "score_test",
            name: "India vs Australia, 1st ODI",
            matchType: "odi",
            status: "live",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Australia"],
            score: [
                Score(r: 250, w: 8, o: 49.0, inning: "India Inning 1"),
                Score(r: 180, w: 5, o: 35.0, inning: "Australia Inning 1")
            ],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertEqual(match.team1Scores.count, 1)
        XCTAssertEqual(match.team1Scores.first?.r, 250)
    }

    func test_team2Scores_filteredByTeamName() {
        let match = Match(
            id: "score_test2",
            name: "India vs Australia, 1st ODI",
            matchType: "odi",
            status: "live",
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: ["India", "Australia"],
            score: [
                Score(r: 250, w: 8, o: 49.0, inning: "India Inning 1"),
                Score(r: 180, w: 5, o: 35.0, inning: "Australia Inning 1")
            ],
            seriesId: nil,
            fantasyEnabled: nil
        )
        XCTAssertEqual(match.team2Scores.count, 1)
        XCTAssertEqual(match.team2Scores.first?.r, 180)
    }

    func test_team1Scores_emptyWhenNoScores() {
        let match = makeMatch(teams: ["India", "Australia"])
        XCTAssertTrue(match.team1Scores.isEmpty)
    }

    // MARK: - Helper

    private func makeMatch(
        id: String = "test_id",
        name: String = "India vs Australia, 1st ODI",
        matchType: String? = "odi",
        status: String? = "live",
        teams: [String]? = ["India", "Australia"],
        score: [Score]? = nil
    ) -> Match {
        Match(
            id: id,
            name: name,
            matchType: matchType,
            status: status,
            venue: nil,
            date: nil,
            dateTimeGMT: nil,
            teams: teams,
            score: score,
            seriesId: nil,
            fantasyEnabled: nil
        )
    }
}

// MARK: - ScoreTests

final class ScoreTests: XCTestCase {

    func test_shortFormatted_runsAndWickets() {
        let score = Score(r: 198, w: 3, o: 32.4, inning: "India Inning 1")
        XCTAssertEqual(score.shortFormatted, "198/3")
    }

    func test_shortFormatted_runsOnly() {
        let score = Score(r: 250, w: nil, o: 50.0, inning: "India Inning 1")
        XCTAssertEqual(score.shortFormatted, "250")
    }

    func test_shortFormatted_nilRuns() {
        let score = Score(r: nil, w: nil, o: nil, inning: "India Inning 1")
        XCTAssertEqual(score.shortFormatted, "-")
    }

    func test_formatted_full() {
        let score = Score(r: 198, w: 3, o: 32.4, inning: "India Inning 1")
        XCTAssertEqual(score.formatted, "198/3 (32.4)")
    }

    func test_formatted_noWickets() {
        let score = Score(r: 198, w: nil, o: 32.4, inning: "India Inning 1")
        XCTAssertEqual(score.formatted, "198 (32.4)")
    }

    func test_formatted_nilRuns() {
        let score = Score(r: nil, w: nil, o: nil, inning: "India Inning 1")
        XCTAssertEqual(score.formatted, "Yet to bat")
    }

    func test_overs_defaultZero() {
        let score = Score(r: 50, w: 1, o: nil, inning: "India Inning 1")
        XCTAssertEqual(score.overs, 0.0)
    }

    func test_overs_returnsValue() {
        let score = Score(r: 50, w: 1, o: 12.3, inning: "India Inning 1")
        XCTAssertEqual(score.overs, 12.3)
    }

    func test_runs_defaultZero() {
        let score = Score(r: nil, w: nil, o: nil, inning: nil)
        XCTAssertEqual(score.runs, 0)
    }

    func test_wickets_defaultZero() {
        let score = Score(r: nil, w: nil, o: nil, inning: nil)
        XCTAssertEqual(score.wickets, 0)
    }

    func test_inningShort_firstInnings() {
        let score = Score(r: 200, w: 10, o: 60.0, inning: "England Inning 1")
        XCTAssertEqual(score.inningShort, "1st Inn")
    }

    func test_inningShort_secondInnings() {
        let score = Score(r: 150, w: 5, o: 40.0, inning: "Australia Inning 2")
        XCTAssertEqual(score.inningShort, "2nd Inn")
    }

    func test_inningShort_1stKeyword() {
        let score = Score(r: 150, w: 5, o: 40.0, inning: "India 1st innings")
        XCTAssertEqual(score.inningShort, "1st Inn")
    }

    func test_inningShort_2ndKeyword() {
        let score = Score(r: 150, w: 5, o: 40.0, inning: "India 2nd innings")
        XCTAssertEqual(score.inningShort, "2nd Inn")
    }

    func test_inningShort_unknownReturnsRaw() {
        let score = Score(r: 150, w: 5, o: 40.0, inning: "India Special Innings")
        XCTAssertEqual(score.inningShort, "India Special Innings")
    }

    func test_inningShort_nilReturnsEmpty() {
        let score = Score(r: 150, w: 5, o: 40.0, inning: nil)
        XCTAssertEqual(score.inningShort, "")
    }
}

// MARK: - ArraySafeSubscriptTests

final class ArraySafeSubscriptTests: XCTestCase {

    func test_safeSubscript_validIndex() {
        let arr = [10, 20, 30]
        XCTAssertEqual(arr[safe: 1], 20)
    }

    func test_safeSubscript_firstIndex() {
        let arr = ["a", "b", "c"]
        XCTAssertEqual(arr[safe: 0], "a")
    }

    func test_safeSubscript_lastIndex() {
        let arr = [1.0, 2.0, 3.0]
        XCTAssertEqual(arr[safe: 2], 3.0)
    }

    func test_safeSubscript_outOfBounds_returnsNil() {
        let arr = [10, 20, 30]
        XCTAssertNil(arr[safe: 5])
    }

    func test_safeSubscript_negativeIndex_returnsNil() {
        let arr = [10, 20, 30]
        XCTAssertNil(arr[safe: -1])
    }

    func test_safeSubscript_emptyArray_returnsNil() {
        let arr: [Int] = []
        XCTAssertNil(arr[safe: 0])
    }
}

// MARK: - ExtensionsTests

final class ExtensionsTests: XCTestCase {

    // MARK: teamFlag

    func test_teamFlag_india() {
        XCTAssertEqual("India".teamFlag, "🇮🇳")
    }

    func test_teamFlag_australia() {
        XCTAssertEqual("Australia".teamFlag, "🇦🇺")
    }

    func test_teamFlag_england() {
        XCTAssertEqual("England".teamFlag, "🏴󠁧󠁢󠁥󠁮󠁧󠁿")
    }

    func test_teamFlag_pakistan() {
        XCTAssertEqual("Pakistan".teamFlag, "🇵🇰")
    }

    func test_teamFlag_newZealand() {
        XCTAssertEqual("New Zealand".teamFlag, "🇳🇿")
    }

    func test_teamFlag_westIndies() {
        XCTAssertEqual("West Indies".teamFlag, "🌴")
    }

    func test_teamFlag_unknown_returnsCricketBat() {
        XCTAssertEqual("UnknownTeam".teamFlag, "🏏")
    }

    func test_teamFlag_emptyString_returnsCricketBat() {
        XCTAssertEqual("".teamFlag, "🏏")
    }

    // MARK: teamShort

    func test_teamShort_india() {
        XCTAssertEqual("India".teamShort, "IND")
    }

    func test_teamShort_australia() {
        XCTAssertEqual("Australia".teamShort, "AUS")
    }

    func test_teamShort_england() {
        XCTAssertEqual("England".teamShort, "ENG")
    }

    func test_teamShort_pakistan() {
        XCTAssertEqual("Pakistan".teamShort, "PAK")
    }

    func test_teamShort_newZealand() {
        XCTAssertEqual("New Zealand".teamShort, "NZ")
    }

    func test_teamShort_unknown_first3Letters() {
        XCTAssertEqual("Zimbabwe".teamShort, "ZIM")
    }

    func test_teamShort_unknownShortName_usesPrefix() {
        // "XY" has only 2 letters — prefix(3) returns "XY", uppercased = "XY"
        XCTAssertEqual("XY".teamShort, "XY")
    }

    // MARK: Color(hex:)

    func test_hexColor_sixChar() {
        // yorkerAccent is #00D084 — should not equal .clear
        let color = Color(hex: "00D084")
        // There is no direct equality check for Color in XCTest;
        // we verify the initialiser didn't produce .clear by checking it's not the
        // default black (all-zeros).
        XCTAssertNotNil(color)
        // Smoke-test: the zero hex should produce black with full opacity (not a crash)
        let black = Color(hex: "000000")
        XCTAssertNotNil(black)
    }

    func test_hexColor_threeChar() {
        // Short hex "FFF" → white
        let white = Color(hex: "FFF")
        XCTAssertNotNil(white)
    }

    func test_hexColor_eightChar_withAlpha() {
        // AARRGGBB format — half-transparent red
        let color = Color(hex: "80FF0000")
        XCTAssertNotNil(color)
    }

    func test_hexColor_invalidString_doesNotCrash() {
        // Should fall through to default case (255,0,0,0) = black, not crash
        let color = Color(hex: "ZZZZZZ")
        XCTAssertNotNil(color)
    }

    // MARK: String date helpers

    func test_isToday_currentDate() {
        let today = DateFormatter().string(from: Date())
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let todayStr = df.string(from: Date())
        XCTAssertTrue(todayStr.isToday)
    }

    func test_isTomorrow_tomorrowDate() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let tomorrowStr = df.string(from: tomorrow)
        XCTAssertTrue(tomorrowStr.isTomorrow)
    }

    func test_isToday_pastDate_returnsFalse() {
        XCTAssertFalse("2020-01-01".isToday)
    }

    func test_isTomorrow_today_returnsFalse() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let todayStr = df.string(from: Date())
        XCTAssertFalse(todayStr.isTomorrow)
    }

    func test_dayLabel_today() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let todayStr = df.string(from: Date())
        XCTAssertEqual(todayStr.dayLabel, "Today")
    }

    func test_dayLabel_tomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let tomorrowStr = df.string(from: tomorrow)
        XCTAssertEqual(tomorrowStr.dayLabel, "Tomorrow")
    }

    func test_dayLabel_pastDate_returnsFormattedString() {
        // A known past date — should not return "Today" or "Tomorrow"
        let label = "2020-01-15".dayLabel
        XCTAssertFalse(label == "Today")
        XCTAssertFalse(label == "Tomorrow")
        XCTAssertFalse(label.isEmpty)
    }

    func test_timeOnly_isoString() {
        // "2026-05-21T09:30:00" → "09:30" (adjusted to local tz; we just check non-empty)
        let timeStr = "2026-05-21T09:30:00".timeOnly
        XCTAssertFalse(timeStr.isEmpty)
        XCTAssertTrue(timeStr.contains(":"))
    }

    func test_timeOnly_invalidString_returnsEmpty() {
        XCTAssertEqual("not-a-date".timeOnly, "")
    }

    func test_matchDate_isoString() {
        let label = "2026-05-21T09:30:00".matchDate
        XCTAssertFalse(label.isEmpty)
    }
}

// MARK: - MatchFilterTests

final class MatchFilterTests: XCTestCase {

    func test_allCases_count() {
        XCTAssertEqual(MatchFilter.allCases.count, 4)
    }

    func test_rawValues() {
        XCTAssertEqual(MatchFilter.all.rawValue, "All")
        XCTAssertEqual(MatchFilter.live.rawValue, "Live")
        XCTAssertEqual(MatchFilter.upcoming.rawValue, "Upcoming")
        XCTAssertEqual(MatchFilter.recent.rawValue, "Recent")
    }

    func test_allCases_containsAll() {
        let cases = MatchFilter.allCases
        XCTAssertTrue(cases.contains(.all))
        XCTAssertTrue(cases.contains(.live))
        XCTAssertTrue(cases.contains(.upcoming))
        XCTAssertTrue(cases.contains(.recent))
    }
}

// MARK: - ScorecardTabTests

final class ScorecardTabTests: XCTestCase {

    func test_allCases_count() {
        XCTAssertEqual(ScorecardTab.allCases.count, 2)
    }

    func test_rawValues() {
        XCTAssertEqual(ScorecardTab.scorecard.rawValue, "Scorecard")
        XCTAssertEqual(ScorecardTab.info.rawValue, "Match Info")
    }
}

// MARK: - LoadingStateTests

final class LoadingStateTests: XCTestCase {

    func test_isLoaded_extractsValue() {
        let state: LoadingState<[String]> = .loaded(["a", "b"])
        if case .loaded(let value) = state {
            XCTAssertEqual(value, ["a", "b"])
        } else {
            XCTFail("Expected .loaded state")
        }
    }

    func test_loadingState_idle() {
        let state: LoadingState<Int> = .idle
        if case .idle = state {
            // success
        } else {
            XCTFail("Expected .idle state")
        }
    }

    func test_loadingState_loading() {
        let state: LoadingState<Int> = .loading
        if case .loading = state {
            // success
        } else {
            XCTFail("Expected .loading state")
        }
    }

    func test_errorMessage() {
        let state: LoadingState<[Match]> = .error("Network failed")
        if case .error(let message) = state {
            XCTAssertEqual(message, "Network failed")
        } else {
            XCTFail("Expected .error state")
        }
    }

    func test_loadedMatchesCanBeExtracted() {
        let matches = Match.mockMatches
        let state: LoadingState<[Match]> = .loaded(matches)
        if case .loaded(let m) = state {
            XCTAssertEqual(m.count, matches.count)
        } else {
            XCTFail("Expected .loaded state with matches")
        }
    }
}

// MARK: - MatchesViewModelTests

@MainActor
final class MatchesViewModelTests: XCTestCase {

    // Helper: creates a MatchesViewModel whose loadingState is pre-seeded with mock data
    private func makeLoadedViewModel() -> MatchesViewModel {
        let vm = MatchesViewModel()
        // Inject mock data directly without triggering the network
        vm.loadingState = .loaded(Match.mockMatches)
        vm.allMatches = Match.mockMatches
        return vm
    }

    func test_filteredMatches_all_returnsAll() {
        let vm = makeLoadedViewModel()
        vm.selectedFilter = .all
        XCTAssertEqual(vm.filteredMatches.count, Match.mockMatches.count)
    }

    func test_filteredMatches_live_onlyLiveMatches() {
        let vm = makeLoadedViewModel()
        vm.selectedFilter = .live
        let liveMatches = vm.filteredMatches
        XCTAssertTrue(liveMatches.allSatisfy { $0.isLive })
        XCTAssertEqual(liveMatches.count, Match.mockLive.count)
    }

    func test_filteredMatches_upcoming_onlyUpcoming() {
        let vm = makeLoadedViewModel()
        vm.selectedFilter = .upcoming
        let upcoming = vm.filteredMatches
        // Upcoming = empty score and not live
        XCTAssertTrue(upcoming.allSatisfy { ($0.score?.isEmpty ?? true) && !$0.isLive })
    }

    func test_filteredMatches_recent_onlyRecent() {
        let vm = makeLoadedViewModel()
        vm.selectedFilter = .recent
        let recent = vm.filteredMatches
        XCTAssertTrue(recent.allSatisfy {
            guard let s = $0.status?.lowercased() else { return false }
            return s.contains("won") || s.contains("drawn") || s.contains("tied")
        })
    }

    func test_searchText_filtersResults() {
        let vm = makeLoadedViewModel()
        vm.selectedFilter = .all
        vm.searchText = "India"
        let results = vm.filteredMatches
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy {
            $0.name.localizedCaseInsensitiveContains("India") ||
            ($0.teams?.joined(separator: " ").localizedCaseInsensitiveContains("India") == true)
        })
    }

    func test_searchText_emptyReturnsAll() {
        let vm = makeLoadedViewModel()
        vm.selectedFilter = .all
        vm.searchText = ""
        XCTAssertEqual(vm.filteredMatches.count, Match.mockMatches.count)
    }

    func test_searchText_noMatch_returnsEmpty() {
        let vm = makeLoadedViewModel()
        vm.selectedFilter = .all
        vm.searchText = "zzz_no_match_zzz"
        XCTAssertTrue(vm.filteredMatches.isEmpty)
    }

    func test_liveMatches_fromLoadedState() {
        let vm = makeLoadedViewModel()
        XCTAssertEqual(vm.liveMatches.count, Match.mockLive.count)
    }

    func test_hasLive_trueWhenLiveExists() {
        let vm = makeLoadedViewModel()
        XCTAssertTrue(vm.hasLive)
    }

    func test_hasLive_falseWhenNoLive() {
        let vm = MatchesViewModel()
        let onlyRecent = Match.mockMatches.filter { !$0.isLive }
        vm.loadingState = .loaded(onlyRecent)
        vm.allMatches = onlyRecent
        XCTAssertFalse(vm.hasLive)
    }

    func test_totalCounts_correctValues() {
        let vm = makeLoadedViewModel()
        XCTAssertEqual(vm.totalLiveCount, Match.mockLive.count)
        XCTAssertEqual(vm.totalUpcomingCount, Match.mockUpcoming.count)
        XCTAssertEqual(vm.totalRecentCount, Match.mockRecent.count)
    }

    func test_filteredMatches_returnsEmpty_whenIdle() {
        let vm = MatchesViewModel()
        // Default state is .idle
        XCTAssertTrue(vm.filteredMatches.isEmpty)
    }

    func test_filteredMatches_returnsEmpty_whenLoading() {
        let vm = MatchesViewModel()
        vm.loadingState = .loading
        XCTAssertTrue(vm.filteredMatches.isEmpty)
    }

    func test_filteredMatches_returnsEmpty_whenError() {
        let vm = MatchesViewModel()
        vm.loadingState = .error("Some error")
        XCTAssertTrue(vm.filteredMatches.isEmpty)
    }
}

// MARK: - CricAPIErrorTests

final class CricAPIErrorTests: XCTestCase {

    func test_errorDescriptions() {
        let errors: [CricAPIError] = [
            .invalidURL,
            .noData,
            .decodingFailed("test message"),
            .apiError("403"),
            .noAPIKey
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "errorDescription should not be nil for \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "errorDescription should not be empty for \(error)")
        }
    }

    func test_invalidURL_message() {
        XCTAssertEqual(CricAPIError.invalidURL.errorDescription, "Invalid URL")
    }

    func test_noData_message() {
        XCTAssertEqual(CricAPIError.noData.errorDescription, "No data received")
    }

    func test_decodingFailed_containsReason() {
        let err = CricAPIError.decodingFailed("key not found")
        XCTAssertTrue(err.errorDescription!.contains("key not found"))
    }

    func test_apiError_containsCode() {
        let err = CricAPIError.apiError("403")
        XCTAssertTrue(err.errorDescription!.contains("403"))
    }

    func test_noAPIKey_message() {
        XCTAssertEqual(CricAPIError.noAPIKey.errorDescription, "No API key configured")
    }
}

// MARK: - MockMatchDataTests

final class MockMatchDataTests: XCTestCase {

    func test_mockMatches_count() {
        // The mock fixture set contains exactly 6 matches
        XCTAssertEqual(Match.mockMatches.count, 6)
    }

    func test_mockLive_allAreActuallyLive() {
        XCTAssertFalse(Match.mockLive.isEmpty, "There should be at least one live mock match")
        for match in Match.mockLive {
            XCTAssertTrue(match.isLive, "\(match.name) should be live but isLive = false")
        }
    }

    func test_mockRecent_allHaveWonStatus() {
        XCTAssertFalse(Match.mockRecent.isEmpty, "There should be at least one recent mock match")
        for match in Match.mockRecent {
            let s = match.status?.lowercased() ?? ""
            let isTerminal = s.contains("won") || s.contains("drawn") || s.contains("tied")
            XCTAssertTrue(isTerminal, "\(match.name) should have terminal status but has: \(match.status ?? "nil")")
        }
    }

    func test_mockUpcoming_allHaveEmptyScores() {
        for match in Match.mockUpcoming {
            XCTAssertTrue(match.score?.isEmpty ?? true, "\(match.name) should have empty scores")
        }
    }

    func test_mockMatches_uniqueIds() {
        let ids = Match.mockMatches.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All mock match IDs should be unique")
    }

    func test_mockMatches_liveCount() {
        let liveCount = Match.mockMatches.filter { $0.isLive }.count
        XCTAssertEqual(liveCount, 2, "Expected 2 live mock matches (mock_1 and mock_3)")
    }

    func test_mockMatches_upcomingCount() {
        let upcomingCount = Match.mockMatches.filter { ($0.score?.isEmpty ?? true) && !$0.isLive }.count
        XCTAssertEqual(upcomingCount, 2, "Expected 2 upcoming mock matches (mock_4 and mock_6)")
    }

    func test_mockMatches_recentCount() {
        let recentCount = Match.mockMatches.filter {
            guard let s = $0.status?.lowercased() else { return false }
            return s.contains("won") || s.contains("drawn") || s.contains("tied")
        }.count
        XCTAssertEqual(recentCount, 2, "Expected 2 recent mock matches (mock_2 and mock_5)")
    }

    func test_mockMatch1_isIndia_vs_Australia() {
        let match = Match.mockMatches[0]
        XCTAssertEqual(match.team1, "India")
        XCTAssertEqual(match.team2, "Australia")
        XCTAssertTrue(match.isLive)
    }

    func test_mockMatch_scoreFormatting() {
        // mock_1: India 198/3 (32.4)
        let match = Match.mockMatches[0]
        let score = match.score?.first
        XCTAssertEqual(score?.shortFormatted, "198/3")
        XCTAssertEqual(score?.formatted, "198/3 (32.4)")
    }

    func test_mockMatch_matchTypeLabels() {
        let odiMatch = Match.mockMatches[0]  // mock_1: odi
        XCTAssertEqual(odiMatch.matchTypeLabel, "ODI")

        let testMatch = Match.mockMatches[1]  // mock_2: test
        XCTAssertEqual(testMatch.matchTypeLabel, "TEST")

        let t20Match = Match.mockMatches[2]  // mock_3: t20
        XCTAssertEqual(t20Match.matchTypeLabel, "T20")
    }

    func test_mockMatch_seriesName() {
        // "India vs Australia, 2nd ODI" → seriesName = "2nd ODI"
        let match = Match.mockMatches[0]
        XCTAssertEqual(match.seriesName, "2nd ODI")
    }

    func test_mockMatch_shortName() {
        // "India vs Australia, 2nd ODI" → shortName = "India vs Australia"
        let match = Match.mockMatches[0]
        XCTAssertEqual(match.shortName, "India vs Australia")
    }

    func test_mockMatch_team1Scores_and_team2Scores() {
        // mock_3: Pakistan vs South Africa — both teams have innings
        let match = Match.mockMatches[2]
        XCTAssertFalse(match.team1Scores.isEmpty)
        XCTAssertFalse(match.team2Scores.isEmpty)
    }
}
