import SwiftUI
import Combine
import FishingCore
import FishingDatabase
import FishingGameApp

/// Standalone iOS 18+ application entry point for «Рыбалка для друзей» (`com.evados.fishing` v1.81 port).
/// Connects:
/// - `AppBundleDatabaseBootstrapper` (`F0.e.a` persistent `INSTALLATION` UUID + first-launch import of all 13 `GameData/*.json` catalogs into `Application Support/FishingForFriends/fishing2.db`);
/// - Launches directly onto the authentic `MainActivity` (`res/layout/dashboard_ads.xml` `res/Yj.xml`) 4x3 base menu;
/// - `FishingService$a` background game clock timer (`1` game minute every `2.0` real seconds across non-pond screens, while `FishingPondView` drives its own `2.0`s timer);
/// - `GameActivity.onResume` sleep-mode clock catch-up (`handleResumeAfterSleep`) on `scenePhase == .active`.
@main
struct FishingIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator: FishingAppCoordinator

    /// `FishingService$a.run()`: ticks every `2.0` seconds (`2 000` ms) to advance 1 game minute.
    private let backgroundClockTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    init() {
        let bootstrapped = (try? AppBundleDatabaseBootstrapper.bootstrapAppCoordinator())
            ?? (try! FishingAppCoordinator())
        bootstrapped.selectedTab = .baseHub
        _coordinator = StateObject(wrappedValue: bootstrapped)
    }

    var body: some Scene {
        WindowGroup {
            FishingRootView(coordinator: coordinator)
                .onReceive(backgroundClockTimer) { _ in
                    guard scenePhase == .active, coordinator.selectedTab != .fishingPond else { return }
                    coordinator.stepGameClockMinute()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, let meta = coordinator.stateMachine.lastCastMetadata {
                        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                        _ = coordinator.handleResumeAfterSleep(
                            beginTimeMs: meta.beginTimeMs,
                            beginHour: meta.beginHour,
                            beginMinute: meta.beginMinute,
                            nowMs: nowMs
                        )
                    }
                }
        }
    }
}
