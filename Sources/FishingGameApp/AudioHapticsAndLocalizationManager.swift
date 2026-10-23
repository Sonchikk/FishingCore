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