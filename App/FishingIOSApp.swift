import SwiftUI
import FishingCore
import FishingDatabase
import FishingGameApp

/// Standalone iOS 18+ application entry point for «Рыбалка для друзей» (`com.evados.fishing` v1.81 port).
/// Connects:
/// - `AppBundleDatabaseBootstrapper` (`F0.e.a` persistent `INSTALLATION` UUID + first-launch import of all 13 `GameData/*.json` catalogs into `Application Support/FishingForFriends/fishing2.db`);
/// - Launches directly onto the authentic `MainActivity` (`res/layout/dashboard_ads.xml` `res/Yj.xml`) 4x3 base menu;
/// - Unified `FishingRootView` game loop (`FishingService$a` 2.0s game clock + `GameView$c` 200ms physics + `GameView$a` 30 FPS canvas);
/// - `GameActivity.onResume` sleep-mode clock catch-up & `CHECKMODE` bite notification handling (`handleAppDidBecomeActive` / `handleAppDidEnterBackground`).
@main
struct FishingIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator: FishingAppCoordinator

    init() {
        let bootstrapped = (try? AppBundleDatabaseBootstrapper.bootstrapAppCoordinator())
            ?? (try! FishingAppCoordinator())
        bootstrapped.selectedTab = .baseHub
        _coordinator = StateObject(wrappedValue: bootstrapped)
    }

    var body: some Scene {
        WindowGroup {
            FishingRootView(coordinator: coordinator)
                .onChange(of: scenePhase) { _, newPhase in
                    let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                    switch newPhase {
                    case .active:
                        coordinator.handleAppDidBecomeActive(nowMs: nowMs)
                    case .background, .inactive:
                        coordinator.handleAppDidEnterBackground(nowMs: nowMs)
                    @unknown default:
                        break
                    }
                }
        }
    }
}
