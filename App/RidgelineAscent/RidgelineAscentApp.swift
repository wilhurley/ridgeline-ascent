import SwiftUI

@main
struct RidgelineAscentApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            RidgePalette.night.ignoresSafeArea()
            switch app.route {
            case .title:
                TitleView()
            case .playing:
                RunView()
            case .results:
                ResultsView()
            }
            if let placement = app.rewardPrompt {
                RewardPlaceholder(placement: placement)
            }
        }
        .sheet(isPresented: $app.showSummitPack) {
            SummitPackSheet()
                .environmentObject(app)
        }
    }
}
