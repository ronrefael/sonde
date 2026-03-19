import SwiftUI
import WidgetKit

@main
struct SondeWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsageRingWidget()
        PacingDashboardWidget()
    }
}
