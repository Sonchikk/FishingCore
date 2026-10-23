import Foundation
import FishingCore
import FishingDatabase

// MARK: - 1. 5-Language Localization Manager (`F0.g` / `LocaleHelper` & `data/localization.json`)

/// Supported game languages reconstructed from `res/values-*` (`ru`, `en`, `de`, `es`, `pt`) and `F0.g.b(Context)`.
public enum FishingLanguage: String, CaseIterable, Sendable, Identifiable {
    case ru = "ru"
    case en = "en"
    case de = "de"
    case es = "es"
    case pt = "pt"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .pt: return "Português"
        }
    }

    /// Reconstructs the language gate in `F0.o.b(Context, DatabaseHelper, ...)` (`MECHANICS.md` Section 6.3):
    /// Quests (`quests`) and contracts (`user_task`) are evaluated ONLY when language is `"ru"` or `"en"`.
    public var supportsQuestsAndTasks: Bool {
        self == .ru || self == .en
    }
}

/// Provides localized strings across all 5 languages (`ru`, `en`, `de`, `es`, `pt`) and pond title resolution.
/// Tackle components checked before cast (`GameView$c.i()`, `MECHANICS.md` Section 2.1).
public enum MissingTackleComponent: String, CaseIterable, Sendable {
    case rod
    case coil
    case line
    case hook
    case bait
}

public struct FishingLocaleManager: Sendable, Equatable {
    public var currentLanguage: FishingLanguage
    public var tasksEnabled: Bool

    public init(currentLanguage: FishingLanguage = .ru, tasksEnabled: Bool = true) {
        self.currentLanguage = currentLanguage
        self.tasksEnabled = tasksEnabled
    }

    /// Exact condition from `F0.o.b` (`MECHANICS.md` Section 6.3):
    /// `TASKS == true && (lang == "ru" || lang == "en")`.
    public var areQuestsAndTasksActive: Bool {
        tasksEnabled && currentLanguage.supportsQuestsAndTasks
    }

    public func pondName(for pond: PondCatalogItem) -> String {
        switch currentLanguage {
        case .ru: return pond.nameRu
        case .en: return pond.nameEn
        case .de: return pond.nameDe
        case .es: return pond.nameEs
        case .pt: return pond.namePt
        }
    }

    public func tabTitle(for tab: AppNavigationTab) -> String {
        switch (currentLanguage, tab) {
        case (.ru, _):
            return tab.titleRu
        case (.en, .fishingPond): return "Pond"
        case (.en, .baseHub): return "Base"
        case (.en, .shop): return "Shop"
        case (.en, .inventory): return "Tackle"
        case (.en, .fishnet): return "Fishnet"
        case (.en, .progress): return "Progress"
        case (.en, .online): return "Online"
        case (.de, .fishingPond): return "Gewässer"
        case (.de, .baseHub): return "Basis"
        case (.de, .shop): return "Laden"
        case (.de, .inventory): return "Rucksack"
        case (.de, .fishnet): return "Setzkescher"
        case (.de, .progress): return "Erfolge"
        case (.de, .online): return "Online"
        case (.es, .fishingPond): return "Lago"
        case (.es, .baseHub): return "Base"
        case (.es, .shop): return "Tienda"
        case (.es, .inventory): return "Mochila"
        case (.es, .fishnet): return "Red"
        case (.es, .progress): return "Progreso"
        case (.es, .online): return "En línea"
        case (.pt, .fishingPond): return "Lago"
        case (.pt, .baseHub): return "Base"
        case (.pt, .shop): return "Loja"
        case (.pt, .inventory): return "Mochila"
        case (.pt, .fishnet): return "Rede"
        case (.pt, .progress): return "Progresso"
        case (.pt, .online): return "Online"
        }
    }

    public func missingTackleComponentName(_ component: MissingTackleComponent) -> String {
        switch (currentLanguage, component) {
        case (.ru, .rod): return "удилище"
        case (.ru, .coil): return "катушка"
        case (.ru, .line): return "леска"
        case (.ru, .hook): return "крючок"
        case (.ru, .bait): return "наживка"
        case (.en, .rod): return "fishing rod"
        case (.en, .coil): return "reel"
        case (.en, .line): return "fishing line"
        case (.en, .hook): return "hook"
        case (.en, .bait): return "bait"
        case (.de, .rod): return "Angelrute"
        case (.de, .coil): return "Rolle"
        case (.de, .line): return "Angelschnur"
        case (.de, .hook): return "Haken"
        case (.de, .bait): return "Köder"
        case (.es, .rod): return "caña"
        case (.es, .coil): return "carrete"
        case (.es, .line): return "sedal"
        case (.es, .hook): return "anzuelo"
        case (.es, .bait): return "cebo"
        case (.pt, .rod): return "vara"
        case (.pt, .coil): return "molinete"
        case (.pt, .line): return "linha"
        case (.pt, .hook): return "anzol"
        case (.pt, .bait): return "isca"
        }
    }
}

// MARK: - 2. Audio, SFX (`F0.p`), Ambient Pond Music (`pondsm.txt`) & Bite Haptics (`FishingService`)

/// Sound effect indices matching `F0.p.c().f(int)` in `classes.dex` (`MECHANICS.md` Section 1.1 & 2.2).
public enum FishingSoundEffect: Int, CaseIterable, Sendable {
    case castBobber = 0      // sfx/bobber.ogg
    case rodBreak = 1        // sfx/rodbreak.ogg
    case coilBreak = 2       // sfx/coilbreak.ogg
    case lineBreak = 3       // sfx/linebreak.ogg
    case fishSplash = 4      // sfx/fishsplash.ogg

    public var assetPath: String {
        switch self {
        case .castBobber: return "sfx/bobber.ogg"
        case .rodBreak: return "sfx/rodbreak.ogg"
        case .coilBreak: return "sfx/coilbreak.ogg"
        case .lineBreak: return "sfx/linebreak.ogg"
        case .fishSplash: return "sfx/fishsplash.ogg"
        }
    }
}

/// Ambient pond audio track descriptor (`sounds/fon/pondsm.txt`, `GameActivity.a0()` & `GameActivity.i0(hour)`).
public struct AmbientPondTrack: Sendable, Equatable {
    public let pondIndex: Int
    public let isDaylightTrack: Bool
    public let trackIndex: Int // 0 = day (05:00..21:59), 1 = night (22:00..04:59)
    public let resourceName: String

    public init(pondIndex: Int, isDaylightTrack: Bool) {
        self.pondIndex = pondIndex
        self.isDaylightTrack = isDaylightTrack
        self.trackIndex = isDaylightTrack ? 0 : 1
        self.resourceName = "sounds/fon/pond\(pondIndex)_\(isDaylightTrack ? "day" : "night").ogg"
    }
}

/// Reconstructs `F0.p` (`SoundPool`), `GameActivity.a0()` (ambient pond music), and `FishingService$e`
/// (`what = 0` bite alarm sound/vibration and `what = 1` catch anti-cheat timing).
public struct FishingAudioAndHapticsController: Sendable, Equatable {
    public static let defaultBiteSoundUri = "fff klev"
    public static let defaultVibrationDurationMs: Int = 500

    public var soundEnabled: Bool
    public var vibrationEnabled: Bool
    public var vibrationDurationMs: Int
    public var biteSoundUri: String

    public private(set) var activeAmbientTrack: AmbientPondTrack?
    public private(set) var isReelLoopPlaying: Bool = false
    public private(set) var playedSoundEffects: [FishingSoundEffect] = []
    public private(set) var biteAlarmTriggerCount: Int = 0
    public private(set) var vibrationTriggerCount: Int = 0

    /// SharedPreferences timestamps recorded by `GameView.q` and `FishingService$e` (`MECHANICS.md` Section 2.2 & 7).
    public private(set) var lastBeginTimeMs: Int64 = 0
    public private(set) var lastBiteTimeMs: Int64 = 0
    public private(set) var lastCatchTimeMs: Int64 = 0

    /// Anti-cheat intervals `FishingService.i` (`[-10000, 60000]` ms) and `FishingService.j` (`[-50, 500]` s).
    public private(set) var lastAntiCheatCatchDeltaMs: Int64 = 0
    public private(set) var lastAntiCheatBiteDelaySeconds: Int64 = 0

    public init(
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = true,
        vibrationDurationMs: Int = Self.defaultVibrationDurationMs,
        biteSoundUri: String = Self.defaultBiteSoundUri
    ) {
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
        self.vibrationDurationMs = vibrationDurationMs
        self.biteSoundUri = biteSoundUri
    }

    /// Updates ambient pond audio track when entering a pond or when `GameActivity.i0(hour)` flips `dayLight`.
    public mutating func syncAmbientTrack(pondIndex: Int, hour: Int) {
        let isDay = (hour >= 5 && hour < 22)
        let desired = AmbientPondTrack(pondIndex: pondIndex, isDaylightTrack: isDay)
        if activeAmbientTrack != desired {
            activeAmbientTrack = desired
        }
    }

    public mutating func playSoundEffect(_ sfx: FishingSoundEffect) {
        guard soundEnabled else { return }
        playedSoundEffects.append(sfx)
    }

    public mutating func setReelLooping(_ looping: Bool) {
        isReelLoopPlaying = soundEnabled ? looping : false
    }

    public mutating func recordCastScheduledBite(beginTimeMs: Int64) {
        lastBeginTimeMs = beginTimeMs
        playSoundEffect(.castBobber)
    }

    /// Reconstructs `FishingService$e.handleMessage(what = 0)` (`MECHANICS.md` Section 7.2):
    /// Plays bite alarm (`res/raw/klev.ogg`), triggers vibration for `VIBRATION_TIME` ms, and records `BITETIME`.
    public mutating func handleBiteSignalWhat0(nowMs: Int64) {
        lastBiteTimeMs = nowMs
        if soundEnabled {
            biteAlarmTriggerCount += 1
        }
        if vibrationEnabled && vibrationDurationMs > 0 {
            vibrationTriggerCount += 1
        }
    }

    /// Reconstructs `FishingService$e.handleMessage(what = 1)` (`MECHANICS.md` Section 7.3):
    /// Stops reel sound, records `CATCHTIME`, and computes `FishingService.i` and `FishingService.j`.
    public mutating func handleCatchSignalWhat1(nowMs: Int64) {
        isReelLoopPlaying = false
        lastCatchTimeMs = nowMs
        lastAntiCheatCatchDeltaMs = GameClockTimer.antiCheatCatchDeltaMs(
            beginTimeMs: lastBeginTimeMs,
            catchTimeMs: nowMs
        )
        lastAntiCheatBiteDelaySeconds = GameClockTimer.antiCheatBiteDelaySeconds(
            beginTimeMs: lastBeginTimeMs,
            biteTimeMs: lastBiteTimeMs > 0 ? lastBiteTimeMs : nowMs
        )
    }
}