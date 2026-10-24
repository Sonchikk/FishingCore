import Foundation
import FishingCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
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

/// Tackle components checked before cast (`GameView$c.i()`, `MECHANICS.md` Section 2.1).
public enum MissingTackleComponent: String, CaseIterable, Sendable {
    case rod
    case coil
    case line
    case hook
    case bait
}

/// Provides localized strings across all 5 languages (`ru`, `en`, `de`, `es`, `pt`) and pond/achievement/quest title resolution.
public struct FishingLocaleManager: Sendable, Equatable {
    /// Original 14 achievement titles from `resources.arsc` (`0x7f030000 array/achievements`, RU).
    public static let achievementTitlesRu: [String] = [
        "Завсегдатай", "Большой улов", "Хулиган", "Любитель заданий",
        "Временщик", "Инди-рыбак", "Люблю 25", "Красавчик",
        "Максималист", "Богач", "Транжира", "Редкий улов",
        "Купонщик", "Путешественник"
    ]

    /// Original 14 achievement titles from `resources.arsc` (`0x7f030000 array/achievements`, EN).
    public static let achievementTitlesEn: [String] = [
        "Fishing everyday", "Big catch", "Hooligan", "Task lover",
        "Fish on time", "Individual fisherman", "I love 25", "Handsome",
        "Maximalist", "Rich", "Big spender", "Rare catch",
        "I like coupons", "Traveler"
    ]

    /// Original 14 achievement descriptions from `resources.arsc` (`0x7f030001 array/achievs_desc`, RU).
    public static let achievementDescriptionsRu: [String] = [
        "заходи порыбачить каждый день",
        "поймай много рыб",
        "ломает много уд",
        "выполняй задания",
        "участвуй в турнирах с регистрацией",
        "создавай индивидуальные турниры",
        "лови рыб со знаком 25",
        "одинаковые цифры - красивый вес",
        "поймай крупную рыбу",
        "заработай кучу денег",
        "выбрасывай снасти",
        "поймай крокодила или клад",
        "купи много купонов",
        "открой все водоемы"
    ]

    /// Original 14 achievement descriptions from `resources.arsc` (`0x7f030001 array/achievs_desc`, EN).
    public static let achievementDescriptionsEn: [String] = [
        "come to fish every day",
        "catch a lot of fish",
        "breaks many fishing rods",
        "perform tasks",
        "participate in tournaments with registration",
        "create individual tournaments",
        "catch fish with the sign 25",
        "same numbers - beautiful weight",
        "catch a big fish",
        "earn a lot of money",
        "throw out the tackles",
        "catch crocodile or treasure",
        "buy a lot of coupons",
        "open all the ponds"
    ]

    /// Original 44 quest titles from `resources.arsc` (`0x7f030011 array/quests`, RU).
    public static let questTitlesRu: [String] = [
        "Ведро рыбы", "Вкусная уха", "Карасики", "Мелочь, а приятно",
        "Заказ для рынка", "Рыбалка на мотыля", "Большое и маленькое", "Рыба моей мечты: Язь!",
        "Щукарь", "Испытание червем", "Мини-сафари", "Пройди Квест",
        "Карповник", "Пивной набор", "Буффало", "Ловля на живца",
        "Королевский лосось", "Заказ ресторана", "Форелевая запеканка", "Сомы",
        "Окушки", "Осторожно! Наживка мясо.", "Африканские сомы", "Черное и белое",
        "Ночная охота", "Вот это лосось!!!", "Рыба для аквариума", "Зубастая рыба",
        "Речные гиганты", "Карпы гиганты", "Рыб не ловить!", "Охота на белугу",
        "Морской деликатес", "Морские звери", "Рыбалка на креветку", "Заказ консервного завода",
        "Марлины", "Пиратский клад", "Рыбка на ужин", "Поймай парусник",
        "Достань луну", "Тунцы", "Акулий зуб", "Кашалоты"
    ]

    /// Original 44 quest titles from `resources.arsc` (`0x7f030011 array/quests`, EN).
    public static let questTitlesEn: [String] = [
        "Bucket of fishes", "Tasty fish soup", "Prussian/Crucian carps", "Trifle, but nice",
        "Order for market", "Fishing on bloodworms", "Big and small", "Fish of my dreams: Ide!",
        "Pikes", "Trial by worm", "Mini safari", "Russian Quest",
        "Carps", "Beer set", "Buffalo", "Live bait fishing",
        "King salmon", "Restaurant order", "Trout casserole", "Catfish",
        "Perches", "Carefully! Bait - meat", "African catfish", "Black and white",
        "Night hunting", "That's salmon!!!", "Fishes for aquarium", "Toothed fish",
        "River giants", "Giant carps", "Don't catch fish!", "Beluga hunting",
        "Sea delicacy", "Sea beasts", "Shrimp fishing", "Ordering a cannery",
        "Marlins", "Pirate Treasure", "Fish for dinner", "Catch sailfish",
        "Get the sun", "Tuna", "Shark Tooth", "Sperm whales"
    ]

    /// Original 44 quest descriptions from `resources.arsc` (`0x7f030012 array/quests_desc`, RU).
    public static let questDescriptionsRu: [String] = [
        "Поймать 20 кг любой рыбы.",
        "Налови на уху по 5 шт. следующих рыб: плотва (500-1000 г), окунь (500-1000 г), красноперка (500-1000 г).",
        "Поймай по 5 шт.: карась 500-1000 г и 1800-2200 г, карась золотой 1100-1600 г и 2400-3000 г.",
        "Нужно наловить по 1 кг каждой из рыб: елец, вьюн, ерш, пескарь, ротан, ерш носарь.",
        "Наловить крупной рыбы: щука (от 12кг), карп (от 10 кг), карп голый (от 10 кг), жерех (от 8 кг). Каждой по 3 шт.",
        "Используй наживку мотыль и поймай по 5 шт. рыб: голавль, белоглазка, густера, рыбец, подлещик.",
        "Поймать 1 кг уклейки и 100 кг усача.",
        "Ну-ка, поймай 5 язей, чтобы каждый весил 6-7 кг.",
        "Выловить по 5 шт. щук в пределах веса: 6-10 кг, 11-15 кг, 16-20 кг.",
        "Поймать кумжа (от 12 кг, 1 шт.), сиг (от 4 кг, 2 шт.) на наживку червь.",
        "Поймать по 3 шт. следующих рыб: щиповка, корюшка, ряпушка, синец и подуст.",
        "Поймай карась, вобла, ерш, судак, толстолобик. Каждой по 5 шт.",
        "Поймай по 3 шт. все видов карпов на водохранилище: карп (от 18 кг), карп голый (от 20 кг), карп зеркальный (от 20 кг).",
        "Налови по 10 шт.: рак, лещ, тарань, подлещик.",
        "Используй наживку ручейник и поймай буффало черный - 100 кг, буффало малоротый - 150 кг, буффало большеротый - 150 кг.",
        "Поймай всех нижеуказаных рыб на живца. Каждой по 3 шт.",
        "Налови по 5 шт. чавычи в пределах веса: 15-20 кг, 25-30 кг, 35-40 кг.",
        "Нужно поймать голец (от 7 кг), налим (от 12 кг), сазан (от 20 кг). Каждой по 7 шт.",
        "Поймать радужная форель (от 6 кг), севанская форель (от 10 кг). Каждой по 10 шт.",
        "Налови по 3 шт. сомов в пределах веса: 10-40 кг, 50-80 кг, 120-150 кг.",
        "Поймать разных речных окуней: окунь - 10 кг, окунь малоротый - 10 кг, окунь солнечный - 3 кг, окунь нильский - 400 кг.",
        "Поймай всех нижеуказаных рыб и рептилию(!) на мясо. Каждой по 2 шт.",
        "Поймай по 5 шт. следующих рыб: сом вунду (от 30 кг), электрический сом (от 12 кг), сом жирафовый (от 2 кг).",
        "Налови по 5 шт.: черный амур (15-18 кг), белый амур (15-18 кг).",
        "Используй указанную наживку и поймай три вида ночных рыб: подлещик, таймень и угорь. Каждой по 5 шт.",
        "Налови по 10 шт. лосося в пределах веса: 1-5 кг, 10-14 кг и 23-27 кг.",
        "Поймай следующих рыб: арована (4-6 кг), рыба-нож (7-10 кг), сом краснохвостый (23-27кг). Каждой по 4 шт.",
        "Нужно поймать: тигровая рыба большая (от 30 кг), паку (от 26 кг), змееголов (от 12 кг). Каждой по 7 шт.",
        "Вылови по 5 шт.: скат пресноводный, сом шильбовый, акула-бык.",
        "Налови по 3 шт. гигантских карпов в пределах веса: 70-100 кг, 170-200 кг, 270-300 кг.",
        "Поймай по 4 шт.: черепаха (от 12 кг) и краб (от 600 г).",
        "Вылови 5 шт. белуг, чтобы каждая весила 1200-1500 кг.",
        "Нужно наловить 100 кг омаров, используя указаные наживки.",
        "Налови по 7 шт.: морская лисица (от 12 кг), морской черт (от 40 кг), морской петух (от 4 кг).",
        "Используй наживку креветка и поймай по 5 шт. указанных рыб.",
        "Поймай следующих рыб: сайда (8-10 кг), скумбрия (2.5-3 кг), камбала (3-4 кг). Каждой по 5 шт.",
        "Налови по 3 шт. марлинов в пределах веса: 30-50 кг, 70-100 кг, 140-170 кг.",
        "Поймай всех нижеуказаных рыб по 3 шт. и найди 3 пиратских клада.",
        "Налови по 10 шт.: пагр розовый, каранкс золотой, каранкс черный.",
        "Поймай самую быструю рыбу в мире - парусник. По 3 шт. в пределах веса: 20-35 кг, 40-55 кг, 60-75 кг.",
        "Поймай всех нижеуказаных рыб на водоеме тропические воды на наживку крабовое мясо и достань 2 рыбы-луны.",
        "Налови по 4 шт.: тунец (от 400 кг), тунец желтоперый (от 120 кг), тунец южный голубой (от 160 кг).",
        "Поймай пять разных акул: акула-мако, тигровая акула, акула полярная, кошачья акула, акула-бык. Каждой по 3 шт.",
        "Налови по 1 шт. кашалотов в пределах веса: 250-500 кг, 750-1000 кг, 1250-1500 кг, 1750-2000 кг."
    ]

    /// Original 44 quest descriptions from `resources.arsc` (`0x7f030012 array/quests_desc`, EN).
    public static let questDescriptionsEn: [String] = [
        "Catch 20 kg any fishes.",
        "Catch 5 pcs. of each fishes for fish soup: roach (500-1000 g), perch (500-1000 g), rudd (500-1000 g).",
        "Catch 5 pcs. of each fishes: prussian carp 500-1000 g and 1800-2200 g, crucian carp 1100-1600 g and 2400-3000 g.",
        "You need to catch 1 kg of each of the fish: common dace, misgurnus, ruffe, gudgeon, chinese sleeper, donets ruffe.",
        "Catch large fish: northern pike (from 12 kg), carp (from 10 kg), leather carp (from 10 kg), asp (from 8 kg). 3 pcs. each.",
        "Use bloodworm bait and catch 5 pcs. of each fishes: european chub, white-eye bream, white bream, vimba bream, young bream.",
        "Catch 1 kg of common bleak and 100 kg of common barbel.",
        "Well, catch 5 ides so that each weighs 6-7 kg.",
        "Catch 5 pcs. of northern pikes each within the weight ranges: 6-10 kg, 11-15 kg, 16-20 kg.",
        "Catch brown trout (from 12 kg, 1 pc.), lavaret (from 4 kg, 2 pcs.) with a worm bait.",
        "Catch 3 pcs. of each fishes: spined loach, smelt, vendace, zope and common nase.",
        "Catch prussian carp, caspian roach, ruffe, zander, bighead carp. Each of 5 pcs.",
        "Catch 3 pcs. of all types of carp each: carp (from 18 kg), leather carp (from 20 kg), mirror carp (from 20 kg).",
        "Catch 10 pcs. of each fishes: crayfish, common bream, taran, young bream.",
        "Use caddisfly bait and catch black buffalo - 100 kg, smallmouth buffalo - 150 kg, bigmouth buffalo - 150 kg.",
        "Catch all of fishes below with live bait. 3 pcs. each.",
        "Catch 5 pcs. of chinook salmon each within the weight ranges: 15-20 kg, 25-30 kg, 35-40 kg.",
        "You need to catch arctic char (from 7 kg), burbot (from 12 kg), common carp (from 20 kg). 7 pcs. each.",
        "Catch rainbow trout (from 6 kg), sevan trout (from 10 kg). 10 pcs. each.",
        "Catch 3 pcs. of catfish each within the weight ranges: 10-40 kg, 50-80 kg, 120-150 kg.",
        "Catch different river perches: perch - 10 kg, smallmouth bass - 10 kg, pumpkinseed - 3 kg, nile perch - 400 kg.",
        "Catch all of fishes and a reptile(!) below with meat. 2 pcs. each.",
        "Catch 5 pcs. of each fishes: vundu (from 30 kg), electric catfish (from 12 kg), giraffe catfish (from 2 kg).",
        "Catch 5 pcs. of each fishes: black carp (15-18 kg), grass carp (15-18 kg).",
        "Use the indicated baits and catch three types of night fish: young bream, taimen and eel. 5 pcs. each.",
        "Catch 10 pcs. of salmon each within the weight ranges: 1-5 kg, 10-14 kg and 23-27 kg.",
        "Catch 4 pcs. of each fishes: asian arowana (4-6 kg), royal featherback (7-10 kg), redtail catfish (23-27 kg).",
        "You need to catch: hydrocynus goliath (from 30 kg), tambaqui (from 26 kg), giant snakehead (from 12 kg). 7 pcs. each.",
        "Catch 5 pcs. of each fishes: giant freshwater stingray, mekong giant catfish, bull shark.",
        "Catch 3 pcs. of giant carps each within the weight ranges: 70-100 kg, 170-200 kg, 270-300 kg.",
        "Catch 4 pcs. each: turtle (from 12 kg) and crab (from 600 g).",
        "Catch 5 beluga so that each weights 1200-1500 kg.",
        "Catch 100 kg of lobster using the baits shown.",
        "Catch 7 pcs. each: thornback ray (from 12 kg), angler (from 40 kg), sea robin (from 4 kg).",
        "Use a shrimp as bait and catch 5 pcs. of each specified fishs.",
        "You need to catch pollock (8-10 kg), atlantic mackerel (2.5-3 kg), european plaice (3-4 kg). 5 pcs. each",
        "Catch 3 pcs. of marlins each within the weight ranges: 30-50 kg, 70-100 kg, 140-170 kg.",
        "Catch all of the fishes below and find 3 pirate treasures.",
        "Catch 10 pcs. of each fishes: silver seabream, golden trevally, black trevally.",
        "Catch the fastest fish in the world - sailfish. Catch 3 pcs. of one each within the weight ranges: 20-35 kg, 40-55 kg, 60-75 kg.",
        "Catch all of the fishes below in tropical water with crab meat as bait and retrieve 2 ocean sunfish.",
        "Catch 4 pcs. each: tuna (from 400 kg), yellowfin tuna (from 120 kg), southern bluefin tuna (from 160 kg).",
        "Catch 3 pcs. of each sharks: shortfin mako shark, tiger shark, greenland shark, small-spotted catshark, bull shark.",
        "Catch 1 pcs. of sperm whales each within the weight ranges: 250-500 kg, 750-1000 kg, 1250-1500 kg, 1750-2000 kg."
    ]

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

    public func achievementTitle(id1Based: Int) -> String {
        let idx = id1Based - 1
        let table = currentLanguage == .ru ? Self.achievementTitlesRu : Self.achievementTitlesEn
        guard idx >= 0 && idx < table.count else {
            return currentLanguage == .ru ? "Достижение #\(id1Based)" : "Achievement #\(id1Based)"
        }
        return table[idx]
    }

    public func achievementDescription(id1Based: Int) -> String {
        let idx = id1Based - 1
        let table = currentLanguage == .ru ? Self.achievementDescriptionsRu : Self.achievementDescriptionsEn
        guard idx >= 0 && idx < table.count else {
            return ""
        }
        return table[idx]
    }

    public func questTitle(id1Based: Int) -> String {
        let idx = id1Based - 1
        let table = currentLanguage == .ru ? Self.questTitlesRu : Self.questTitlesEn
        guard idx >= 0 && idx < table.count else {
            return currentLanguage == .ru ? "Квест #\(id1Based)" : "Quest #\(id1Based)"
        }
        return table[idx]
    }

    public func questDescription(id1Based: Int) -> String {
        let idx = id1Based - 1
        let table = currentLanguage == .ru ? Self.questDescriptionsRu : Self.questDescriptionsEn
        guard idx >= 0 && idx < table.count else {
            return ""
        }
        return table[idx]
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

/// Bite haptic intensity tier scaled by the hooked fish weight (`activeFishWeightGrams`).
public enum BiteHapticIntensityProfile: String, Sendable, Equatable {
    case lightNibbler = "light"      // < 500 g: gentle single light tap
    case mediumStrike = "medium"     // 500 ..< 3000 g: medium single pulse
    case heavyPull = "heavy"         // 3000 ..< 15000 g: double heavy impact pulse
    case trophyGiant = "trophy"      // >= 15000 g: triple heavy rumble burst

    public static func from(fishWeightGrams: Int) -> BiteHapticIntensityProfile {
        if fishWeightGrams >= 15_000 {
            return .trophyGiant
        } else if fishWeightGrams >= 3_000 {
            return .heavyPull
        } else if fishWeightGrams >= 500 {
            return .mediumStrike
        } else {
            return .lightNibbler
        }
    }

    public var pulseCount: Int {
        switch self {
        case .lightNibbler: return 1
        case .mediumStrike: return 1
        case .heavyPull: return 2
        case .trophyGiant: return 3
        }
    }
}

/// Reconstructs `F0.p` (`SoundPool`), `GameActivity.a0()` (ambient pond music), and `FishingService$e`
/// (`what = 0` bite alarm sound/vibration and `what = 1` catch anti-cheat timing).
public struct FishingAudioAndHapticsController: Sendable, Equatable {
    public static let defaultBiteSoundUri = "fff klev"
    public static let defaultVibrationDurationMs: Int = 500

    public var soundEnabled: Bool {
        didSet {
            if !soundEnabled {
                isReelLoopPlaying = false
                LiveAudioPlaybackEngine.shared.stopAllAudioImmediately()
            } else if isOnPondScreen, let track = activeAmbientTrack {
                LiveAudioPlaybackEngine.shared.syncAmbientTrack(track, soundEnabled: true)
            }
        }
    }
    public var vibrationEnabled: Bool
    public var vibrationDurationMs: Int
    public var biteSoundUri: String
    /// Matches `GameActivity.onResume` / `GameActivity.onPause`: ambient pond sounds only play on the pond screen (`GameActivity`), never in `MainActivity`.
    public var isOnPondScreen: Bool = true {
        didSet {
            if !isOnPondScreen {
                if isReelLoopPlaying {
                    isReelLoopPlaying = false
                }
                LiveAudioPlaybackEngine.shared.setReelLoopPlaying(false)
                LiveAudioPlaybackEngine.shared.stopAmbientTrack()
            } else if soundEnabled, let track = activeAmbientTrack {
                LiveAudioPlaybackEngine.shared.syncAmbientTrack(track, soundEnabled: true)
            }
        }
    }

    public private(set) var activeAmbientTrack: AmbientPondTrack?
    public private(set) var isReelLoopPlaying: Bool = false
    public private(set) var playedSoundEffects: [FishingSoundEffect] = []
    public private(set) var biteAlarmTriggerCount: Int = 0
    public private(set) var vibrationTriggerCount: Int = 0
    public private(set) var lastBiteHapticProfile: BiteHapticIntensityProfile = .mediumStrike

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
    /// Only plays audio hardware when `soundEnabled && isOnPondScreen` (`GameActivity.onResume`).
    public mutating func syncAmbientTrack(pondIndex: Int, hour: Int, isPondScreenVisible: Bool? = nil) {
        if let isPondScreenVisible {
            self.isOnPondScreen = isPondScreenVisible
        }
        let isDay = (hour >= 5 && hour < 22)
        let desired = AmbientPondTrack(pondIndex: pondIndex, isDaylightTrack: isDay)
        let shouldPlayNow = soundEnabled && isOnPondScreen
        if activeAmbientTrack != desired {
            activeAmbientTrack = desired
            if shouldPlayNow {
                LiveAudioPlaybackEngine.shared.syncAmbientTrack(desired, soundEnabled: true)
            } else {
                LiveAudioPlaybackEngine.shared.stopAmbientTrack()
            }
        } else if !shouldPlayNow {
            LiveAudioPlaybackEngine.shared.stopAmbientTrack()
        } else {
            LiveAudioPlaybackEngine.shared.ensureAmbientTrackPlaying(desired, soundEnabled: true)
        }
    }

    public mutating func stopAmbientAndReelAudio() {
        if isReelLoopPlaying {
            isReelLoopPlaying = false
        }
        LiveAudioPlaybackEngine.shared.stopAllAudioImmediately()
    }

    public mutating func playSoundEffect(_ sfx: FishingSoundEffect) {
        if soundEnabled {
            playedSoundEffects.append(sfx)
            LiveAudioPlaybackEngine.shared.playSoundEffect(sfx)
        }
        if vibrationEnabled {
            Self.triggerPlatformHapticForSoundEffect(sfx)
        }
    }

    public mutating func setReelLooping(_ looping: Bool) {
        let shouldLoop = (soundEnabled && isOnPondScreen) ? looping : false
        if isReelLoopPlaying != shouldLoop {
            isReelLoopPlaying = shouldLoop
            LiveAudioPlaybackEngine.shared.setReelLoopPlaying(shouldLoop)
        }
    }

    public mutating func recordCastScheduledBite(beginTimeMs: Int64) {
        lastBeginTimeMs = beginTimeMs
        playSoundEffect(.castBobber)
    }

    /// Reconstructs `FishingService$e.handleMessage(what = 0)` (`MECHANICS.md` Section 7.2):
    /// Plays bite alarm (`res/raw/klev.ogg`), triggers vibration scaled by `fishWeightGrams`, and records `BITETIME`.
    public mutating func handleBiteSignalWhat0(nowMs: Int64, fishWeightGrams: Int = 1_000) {
        lastBiteTimeMs = nowMs
        let profile = BiteHapticIntensityProfile.from(fishWeightGrams: fishWeightGrams)
        lastBiteHapticProfile = profile
        if soundEnabled {
            biteAlarmTriggerCount += 1
            LiveAudioPlaybackEngine.shared.playBiteAlarm(soundUri: biteSoundUri)
        }
        if vibrationEnabled && vibrationDurationMs > 0 {
            vibrationTriggerCount += 1
            Self.triggerPlatformBiteAlarmHaptic(profile: profile)
        }
    }

    private static func triggerPlatformBiteAlarmHaptic(profile: BiteHapticIntensityProfile) {
        #if canImport(UIKit) && !os(watchOS)
        Task { @MainActor in
            switch profile {
            case .lightNibbler:
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.prepare()
                gen.impactOccurred(intensity: 0.55)
            case .mediumStrike:
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.prepare()
                gen.impactOccurred(intensity: 0.85)
            case .heavyPull:
                let gen = UIImpactFeedbackGenerator(style: .heavy)
                gen.prepare()
                gen.impactOccurred(intensity: 1.0)
                try? await Task.sleep(nanoseconds: 130_000_000)
                gen.impactOccurred(intensity: 0.90)
            case .trophyGiant:
                let notif = UINotificationFeedbackGenerator()
                notif.prepare()
                notif.notificationOccurred(.warning)
                let heavy = UIImpactFeedbackGenerator(style: .heavy)
                heavy.prepare()
                try? await Task.sleep(nanoseconds: 120_000_000)
                heavy.impactOccurred(intensity: 1.0)
                try? await Task.sleep(nanoseconds: 140_000_000)
                heavy.impactOccurred(intensity: 1.0)
            }
        }
        #endif
    }

    private static func triggerPlatformHapticForSoundEffect(_ sfx: FishingSoundEffect) {
        #if canImport(UIKit) && !os(watchOS)
        Task { @MainActor in
            switch sfx {
            case .castBobber:
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            case .fishSplash:
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            case .rodBreak, .coilBreak, .lineBreak:
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.error)
            }
        }
        #endif
    }

    /// Reconstructs `FishingService$e.handleMessage(what = 1)` (`MECHANICS.md` Section 7.3):
    /// Stops reel sound, records `CATCHTIME`, and computes `FishingService.i` and `FishingService.j`.
    public mutating func handleCatchSignalWhat1(nowMs: Int64) {
        if isReelLoopPlaying {
            isReelLoopPlaying = false
            LiveAudioPlaybackEngine.shared.setReelLoopPlaying(false)
        }
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

// MARK: - 3. Phase 17 — Native iOS Audio Playback Engine (`AVAudioPlayer`, `F0.p` & `res/raw/klev.ogg`, `res/raw/tw.ogg`)

/// Native iOS/macOS audio engine driving `AVAudioPlayer` instances for:
/// 1. Original APK bite & tournament sounds (`res/ac.ogg` -> `klev.m4a`, `res/JG.ogg` -> `tw.m4a`) embedded directly in Base64;
/// 2. Bundled `.m4a`/`.wav`/`.mp3` files in `GameAssets/Sounds` (if present in the `.app` bundle);
/// 3. Authentic 16-bit PCM WAV procedural synthesis for the 5 `F0.p` sound effects (`bobber`, `rodbreak`, `coilbreak`, `linebreak`, `fishsplash`),
///    continuous reel loop (`F0.p.c().h()`), and day/night ambient pond soundscapes (`pondsm.txt`).
public final class LiveAudioPlaybackEngine: @unchecked Sendable {
    public static let shared = LiveAudioPlaybackEngine()

    /// Original `res/raw/klev.ogg` (`0x7f110007`, `res/ac.ogg`) from `fishing181.apk`, transcoded to AAC `.m4a`.
    public static let originalKlevM4ABase64: String = "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"

    /// Original `res/raw/tw.ogg` (`0x7f11000c`, `res/JG.ogg`) from `fishing181.apk`, transcoded to AAC `.m4a`.
    public static let originalTwM4ABase64: String = "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"

    /// Detects whether the current process is an `xctest` runner so audio hardware isn't initialized in CI tests.
    public static var isRunningUnderXCTest: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        let procName = ProcessInfo.processInfo.processName.lowercased()
        if procName.contains("xctest") {
            return true
        }
        return NSClassFromString("XCTestCase") != nil
    }

    private let lock = NSLock()
    private var cachedAudioData: [String: Data] = [:]

    #if canImport(AVFoundation)
    private var activeSfxPlayers: [String: AVAudioPlayer] = [:]
    private var reelLoopPlayer: AVAudioPlayer?
    private var ambientPlayer: AVAudioPlayer?
    private var didConfigureAudioSession: Bool = false
    #endif

    public init() {}

    /// Returns playable audio `Data` (`.m4a` or 16-bit PCM `.wav`) for any sound key, usable both at runtime and in unit tests.
    public func resolvedAudioData(forKey key: String) -> Data {
        lock.lock()
        if let existing = cachedAudioData[key] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let generated: Data
        if let bundled = Self.loadBundledSoundData(named: key) {
            generated = bundled
        } else {
            switch key {
            case "klev":
                generated = Data(base64Encoded: Self.originalKlevM4ABase64) ?? Self.synthesizeBiteBellWAV()
            case "tw":
                generated = Data(base64Encoded: Self.originalTwM4ABase64) ?? Self.synthesizeBiteBellWAV()
            case "sfx_0":
                generated = Self.synthesizeCastPlopWAV()
            case "sfx_1":
                generated = Self.synthesizeBreakSnapWAV(baseFreq: 165.0, duration: 0.34)
            case "sfx_2":
                generated = Self.synthesizeBreakSnapWAV(baseFreq: 240.0, duration: 0.30)
            case "sfx_3":
                generated = Self.synthesizeBreakSnapWAV(baseFreq: 520.0, duration: 0.22)
            case "sfx_4":
                generated = Self.synthesizeFishSplashWAV()
            case "reel_loop":
                generated = Self.synthesizeReelClickLoopWAV()
            case "ambient_day":
                generated = Self.synthesizeAmbientLoopWAV(isDaylight: true, pondIndex: 0)
            case "ambient_night":
                generated = Self.synthesizeAmbientLoopWAV(isDaylight: false, pondIndex: 0)
            default:
                if key.hasPrefix("pond") {
                    let isDay = key.hasSuffix("_day")
                    let digits = key.dropFirst(4).prefix(while: { $0.isNumber })
                    let pIdx = Int(digits) ?? 0
                    generated = Self.synthesizeAmbientLoopWAV(isDaylight: isDay, pondIndex: pIdx)
                } else {
                    generated = Self.synthesizeCastPlopWAV()
                }
            }
        }

        lock.lock()
        cachedAudioData[key] = generated
        lock.unlock()
        return generated
    }

    public func playSoundEffect(_ sfx: FishingSoundEffect) {
        guard !Self.isRunningUnderXCTest else { return }
        let key = "sfx_\(sfx.rawValue)"
        let data = resolvedAudioData(forKey: key)
        playOneShotData(data, key: key, volume: 0.85)
    }

    public func playBiteAlarm(soundUri: String) {
        guard !Self.isRunningUnderXCTest else { return }
        let key = soundUri.lowercased().contains("tw") ? "tw" : "klev"
        let data = resolvedAudioData(forKey: key)
        playOneShotData(data, key: key, volume: 1.0)
    }

    public func setReelLoopPlaying(_ playing: Bool) {
        guard !Self.isRunningUnderXCTest else { return }
        #if canImport(AVFoundation)
        let data = resolvedAudioData(forKey: "reel_loop")
        Task { @MainActor in
            self.configureAudioSessionIfNeeded()
            if playing {
                if self.reelLoopPlayer == nil {
                    self.reelLoopPlayer = try? AVAudioPlayer(data: data)
                    self.reelLoopPlayer?.numberOfLoops = -1
                    self.reelLoopPlayer?.volume = 0.55
                    self.reelLoopPlayer?.prepareToPlay()
                }
                if self.reelLoopPlayer?.isPlaying == false {
                    self.reelLoopPlayer?.play()
                }
            } else {
                self.reelLoopPlayer?.stop()
            }
        }
        #endif
    }

    public func syncAmbientTrack(_ track: AmbientPondTrack, soundEnabled: Bool) {
        guard !Self.isRunningUnderXCTest else { return }
        #if canImport(AVFoundation)
        guard soundEnabled else {
            stopAmbientTrack()
            return
        }
        let specificKey = "pond\(track.pondIndex)_\(track.isDaylightTrack ? "day" : "night")"
        let data = Self.loadBundledSoundData(named: specificKey)
            ?? resolvedAudioData(forKey: specificKey)
        Task { @MainActor in
            self.configureAudioSessionIfNeeded()
            self.ambientPlayer?.stop()
            if let player = try? AVAudioPlayer(data: data) {
                player.numberOfLoops = -1
                player.volume = 0.16
                player.prepareToPlay()
                player.play()
                self.ambientPlayer = player
            }
        }
        #endif
    }

    public func ensureAmbientTrackPlaying(_ track: AmbientPondTrack, soundEnabled: Bool) {
        guard !Self.isRunningUnderXCTest else { return }
        #if canImport(AVFoundation)
        guard soundEnabled else {
            stopAmbientTrack()
            return
        }
        let specificKey = "pond\(track.pondIndex)_\(track.isDaylightTrack ? "day" : "night")"
        let data = Self.loadBundledSoundData(named: specificKey)
            ?? resolvedAudioData(forKey: specificKey)
        Task { @MainActor in
            if let existing = self.ambientPlayer, existing.isPlaying {
                return
            }
            self.configureAudioSessionIfNeeded()
            if let player = try? AVAudioPlayer(data: data) {
                player.numberOfLoops = -1
                player.volume = 0.16
                player.prepareToPlay()
                player.play()
                self.ambientPlayer = player
            }
        }
        #endif
    }

    public func stopAmbientTrack() {
        guard !Self.isRunningUnderXCTest else { return }
        #if canImport(AVFoundation)
        Task { @MainActor in
            self.ambientPlayer?.stop()
            self.ambientPlayer = nil
        }
        #endif
    }

    public func stopAllAudioImmediately() {
        guard !Self.isRunningUnderXCTest else { return }
        #if canImport(AVFoundation)
        Task { @MainActor in
            self.ambientPlayer?.stop()
            self.ambientPlayer = nil
            self.reelLoopPlayer?.stop()
            for (_, player) in self.activeSfxPlayers {
                player.stop()
            }
            self.activeSfxPlayers.removeAll()
        }
        #endif
    }

    private func playOneShotData(_ data: Data, key: String, volume: Float) {
        #if canImport(AVFoundation)
        Task { @MainActor in
            self.configureAudioSessionIfNeeded()
            if let player = try? AVAudioPlayer(data: data) {
                player.volume = volume
                player.prepareToPlay()
                player.play()
                self.activeSfxPlayers[key] = player
            }
        }
        #endif
    }

    #if canImport(AVFoundation)
    @MainActor
    private func configureAudioSessionIfNeeded() {
        guard !didConfigureAudioSession else { return }
        didConfigureAudioSession = true
        #if os(iOS) || os(tvOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
    #endif

    private static func loadBundledSoundData(named name: String, bundle: Bundle = .main) -> Data? {
        let extensions = ["m4a", "wav", "mp3", "caf"]
        let subdirs: [String?] = ["GameAssets/Sounds", "Sounds", nil]
        for sub in subdirs {
            for ext in extensions {
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: sub),
                   let data = try? Data(contentsOf: url), !data.isEmpty {
                    return data
                }
            }
        }
        return nil
    }

    // MARK: - Pure-Swift 16-Bit PCM `.wav` Synthesizers for `F0.p` Sound Effects & Ambient Loops

    public static func encodeMono16BitPCMWAV(samples: [Int16], sampleRate: Int = 22050) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataChunkSize = UInt32(samples.count * 2)
        let riffChunkSize = 36 + dataChunkSize

        var out = Data()
        out.reserveCapacity(Int(44 + dataChunkSize))
        out.append(contentsOf: "RIFF".utf8)
        appendUInt32LE(&out, riffChunkSize)
        out.append(contentsOf: "WAVE".utf8)
        out.append(contentsOf: "fmt ".utf8)
        appendUInt32LE(&out, 16) // PCM fmt chunk size
        appendUInt16LE(&out, 1)  // AudioFormat = 1 (PCM)
        appendUInt16LE(&out, numChannels)
        appendUInt32LE(&out, UInt32(sampleRate))
        appendUInt32LE(&out, byteRate)
        appendUInt16LE(&out, blockAlign)
        appendUInt16LE(&out, bitsPerSample)
        out.append(contentsOf: "data".utf8)
        appendUInt32LE(&out, dataChunkSize)

        for sample in samples {
            var le = sample.littleEndian
            withUnsafeBytes(of: &le) { out.append(contentsOf: $0) }
        }
        return out
    }

    private static func appendUInt16LE(_ data: inout Data, _ value: UInt16) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32LE(_ data: inout Data, _ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    /// Water drop plop for `sfx/bobber.ogg` (`castBobber = 0`).
    private static func synthesizeCastPlopWAV(sampleRate: Int = 22050) -> Data {
        let duration = 0.20
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let env = exp(-t * 22.0) * sin(min(1.0, t * 120.0) * (.pi / 2.0))
            // Upward bubble chirp 280 Hz -> 640 Hz
            let freq = 280.0 + 1800.0 * t
            phase += 2.0 * .pi * freq / Double(sampleRate)
            let val = sin(phase) * env * 0.75
            samples[i] = Int16(max(-1.0, min(1.0, val)) * 30000.0)
        }
        return encodeMono16BitPCMWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Crisp snap + low thud for `rodbreak`, `coilbreak`, `linebreak` (`1..3`).
    private static func synthesizeBreakSnapWAV(baseFreq: Double, duration: Double, sampleRate: Int = 22050) -> Data {
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        var lcg: UInt32 = 0x1234_5678
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            lcg = lcg &* 1664525 &+ 1013904223
            let noise = (Double(lcg & 0xFFFF) / 32768.0) - 1.0
            let env = exp(-t * 16.0)
            let tone = sin(2.0 * .pi * baseFreq * (1.0 - t * 1.4) * t)
            let val = (noise * 0.55 + tone * 0.45) * env * 0.85
            samples[i] = Int16(max(-1.0, min(1.0, val)) * 30000.0)
        }
        return encodeMono16BitPCMWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Water splash burst for `sfx/fishsplash.ogg` (`fishSplash = 4`).
    private static func synthesizeFishSplashWAV(sampleRate: Int = 22050) -> Data {
        let duration = 0.42
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        var lcg: UInt32 = 0x8765_4321
        var lp = 0.0
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            lcg = lcg &* 1664525 &+ 1013904223
            let white = (Double(lcg & 0xFFFF) / 32768.0) - 1.0
            lp = lp * 0.78 + white * 0.22
            let burst1 = exp(-pow((t - 0.04) / 0.05, 2.0))
            let burst2 = 0.7 * exp(-pow((t - 0.16) / 0.09, 2.0))
            let bubble = 0.25 * sin(2.0 * .pi * (340.0 + 420.0 * t) * t) * exp(-t * 8.0)
            let val = (lp * (burst1 + burst2) + bubble) * 0.85
            samples[i] = Int16(max(-1.0, min(1.0, val)) * 30000.0)
        }
        return encodeMono16BitPCMWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Mechanical reel ratchet click loop (`F0.p.c().h()`).
    private static func synthesizeReelClickLoopWAV(sampleRate: Int = 22050) -> Data {
        let duration = 0.25
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        // 4 soft ratchet clicks per 0.25s (= 16 clicks/sec)
        let clickPeriod = Double(sampleRate) / 16.0
        for i in 0..<count {
            let localIdx = Double(i).truncatingRemainder(dividingBy: clickPeriod)
            let localT = localIdx / Double(sampleRate)
            let env = exp(-localT * 180.0)
            let click = sin(2.0 * .pi * 1150.0 * localT) * env * 0.45
            samples[i] = Int16(max(-1.0, min(1.0, click)) * 26000.0)
        }
        return encodeMono16BitPCMWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Gentle, squeak-free ambient water lapping & soft breeze loop (`pondsm.txt` day/night per-pond soundscape).
    /// Uses a 3-stage cascaded low-pass filter (< 350 Hz) with zero high-frequency sine tones so there is no whistle/squeak,
    /// and varies wave cadence across the 15 ponds (`pondIndex = 0..14`).
    private static func synthesizeAmbientLoopWAV(isDaylight: Bool, pondIndex: Int = 0, sampleRate: Int = 22050) -> Data {
        let duration = 4.0
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        let seedOffset = UInt32(max(0, pondIndex) * 7919)
        var lcg: UInt32 = (isDaylight ? 0xCAFE_BABE : 0xDEAD_BEEF) &+ seedOffset
        var lp1 = 0.0
        var lp2 = 0.0
        var lp3 = 0.0
        let waveCycles = Double(1 + (max(0, pondIndex) % 3)) // 1, 2, or 3 gentle shore waves per 4.0s loop
        let filterAlpha = isDaylight ? 0.032 : 0.020

        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            lcg = lcg &* 1664525 &+ 1013904223
            let white = (Double(lcg & 0xFFFF) / 32768.0) - 1.0
            lp1 += filterAlpha * (white - lp1)
            lp2 += filterAlpha * (lp1 - lp2)
            lp3 += filterAlpha * (lp2 - lp3)

            // Smooth periodic wave envelope (exact integer cycles over 4.0s for seamless loop boundary)
            let waveLfo = 0.58 + 0.42 * sin(2.0 * .pi * (waveCycles / duration) * t)
            let breezeLfo = 0.75 + 0.25 * cos(2.0 * .pi * (1.0 / duration) * t)
            // Seamless crossfade envelope at loop edges
            let edgeFade = min(1.0, min(Double(i) / 400.0, Double(count - 1 - i) / 400.0))
            let sig = lp3 * waveLfo * breezeLfo * edgeFade * (isDaylight ? 0.42 : 0.30)
            samples[i] = Int16(max(-1.0, min(1.0, sig)) * 18000.0)
        }
        return encodeMono16BitPCMWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Fallback bell chime if Base64 decoding is unavailable.
    private static func synthesizeBiteBellWAV(sampleRate: Int = 22050) -> Data {
        let duration = 0.45
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let env = exp(-t * 7.5)
            let bell = 0.6 * sin(2.0 * .pi * 1568.0 * t) + 0.4 * sin(2.0 * .pi * 2349.0 * t)
            samples[i] = Int16(max(-1.0, min(1.0, bell * env)) * 28000.0)
        }
        return encodeMono16BitPCMWAV(samples: samples, sampleRate: sampleRate)
    }
}
