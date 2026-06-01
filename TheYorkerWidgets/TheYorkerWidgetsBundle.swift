//
//  TheYorkerWidgetsBundle.swift
//  TheYorkerWidgets
//
//  Created by Vishal Kashyap on 22/05/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

/// Entry point for the TheYorkerWidgets extension.
///
/// `@main` designates this as the extension's launch point — only one struct in the
/// extension target may carry this attribute. The `body` property registers both widgets
/// with WidgetKit so the system knows which configurations this extension provides.
@main
struct TheYorkerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MatchHomeWidget()          // home-screen widget (small + medium)
        MatchLiveActivityWidget()  // lock-screen Live Activity + Dynamic Island
    }
}
