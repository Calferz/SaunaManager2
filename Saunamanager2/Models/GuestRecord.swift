//
//  GuestRecord.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

import Foundation

struct GuestRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var lockerNumber: String
    var date: Date
    var checkInTime: Date
    var checkOutTime: Date?
    // 「ランステ＋通常利用」プラン専用：ランニングから帰還しサウナ利用を開始した時刻。
    // nilの間は「ランニング中」、値がセットされたら「サウナ利用中」を意味する。
    var saunaStartTime: Date?
    var plan: String
    var gender: String
    var swimwearRental: Bool
    var rentalItems: [String]
    var discounts: [String]
    var storedItems: [String]
    var cleansingPurchased: Bool
    var memo: String
    var isHoliday: Bool

    init(
        id: UUID = UUID(),
        lockerNumber: String,
        date: Date,
        checkInTime: Date,
        checkOutTime: Date? = nil,
        saunaStartTime: Date? = nil,
        plan: String,
        gender: String,
        swimwearRental: Bool,
        rentalItems: [String],
        discounts: [String],
        storedItems: [String] = [],
        cleansingPurchased: Bool = false,
        memo: String,
        isHoliday: Bool
    ) {
        self.id = id
        self.lockerNumber = lockerNumber
        self.date = date
        self.checkInTime = checkInTime
        self.checkOutTime = checkOutTime
        self.saunaStartTime = saunaStartTime
        self.plan = plan
        self.gender = gender
        self.swimwearRental = swimwearRental
        self.rentalItems = rentalItems
        self.discounts = discounts
        self.storedItems = storedItems
        self.cleansingPurchased = cleansingPurchased
        self.memo = memo
        self.isHoliday = isHoliday
    }

    // storedItems・cleansingPurchased は後から追加したフィールドのため、既存の保存データ（このキーを持たない）を
    // デコードする際に失敗しないようカスタムデコードでフォールバックする。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        lockerNumber = try c.decode(String.self, forKey: .lockerNumber)
        date = try c.decode(Date.self, forKey: .date)
        checkInTime = try c.decode(Date.self, forKey: .checkInTime)
        checkOutTime = try c.decodeIfPresent(Date.self, forKey: .checkOutTime)
        saunaStartTime = try c.decodeIfPresent(Date.self, forKey: .saunaStartTime)
        plan = try c.decode(String.self, forKey: .plan)
        gender = try c.decode(String.self, forKey: .gender)
        swimwearRental = try c.decode(Bool.self, forKey: .swimwearRental)
        rentalItems = try c.decode([String].self, forKey: .rentalItems)
        discounts = try c.decode([String].self, forKey: .discounts)
        storedItems = try c.decodeIfPresent([String].self, forKey: .storedItems) ?? []
        cleansingPurchased = try c.decodeIfPresent(Bool.self, forKey: .cleansingPurchased) ?? false
        memo = try c.decode(String.self, forKey: .memo)
        isHoliday = try c.decode(Bool.self, forKey: .isHoliday)
    }

    // 時刻（時分秒）のみを比較した分単位の差分。
    // checkInTime等は日付部分が基準日（2001/1/1）に固定されて保存されるため、時刻のみで比較する。
    // 日をまたぐ場合（深夜営業）にも対応。
    private static func minutesBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current

        let startTotalSeconds = calendar.component(.hour, from: start) * 3600
            + calendar.component(.minute, from: start) * 60
            + calendar.component(.second, from: start)

        var endTotalSeconds = calendar.component(.hour, from: end) * 3600
            + calendar.component(.minute, from: end) * 60
            + calendar.component(.second, from: end)

        if endTotalSeconds < startTotalSeconds {
            endTotalSeconds += 24 * 3600
        }

        return (endTotalSeconds - startTotalSeconds) / 60
    }

    // 滞在時間（分）
    // 「ランステ＋通常利用」プランのみ、サウナ利用開始（saunaStartTime）から退館までを基準にする。
    // それ以外のプランは入館（checkInTime）から退館まで。
    var stayDuration: Int? {
        guard let out = checkOutTime else { return nil }
        if plan == "ランステ＋通常利用", let saunaStart = saunaStartTime {
            return Self.minutesBetween(saunaStart, out)
        }
        return Self.minutesBetween(checkInTime, out)
    }

    // 入館（ランニング開始）から現在までの経過分。checkInTime は日付が基準日固定のため時刻のみで比較する。
    func runningElapsedMinutes(now: Date = Date()) -> Int {
        Self.minutesBetween(checkInTime, now)
    }

    // ランニング利用時間（分）：「ランステ＋通常利用」プランの入館〜サウナ利用開始まで
    var runningDuration: Int? {
        guard let saunaStart = saunaStartTime else { return nil }
        return Self.minutesBetween(checkInTime, saunaStart)
    }
    // 在館中かどうか
    var isCheckedIn: Bool {
        return checkOutTime == nil
    }
    
    // ランニング中（サウナ未利用）かどうか。
    // 「ランステ」、および「ランステ＋通常利用」でサウナ利用開始前のもの。在館人数には含めない。
    var isRunningOnly: Bool {
        plan == "ランステ" || (plan == "ランステ＋通常利用" && saunaStartTime == nil)
    }

    // 朝活軽食
    var isMorningMeal: Bool {
        plan == "朝活軽食"
    }
    
    // 日付フォーマット（日付のみ）
    var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")  // ← 追加
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    // 時刻フォーマット（時刻のみ）
    var checkInTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: checkInTime)
    }

    var checkOutTimeString: String? {
        guard let out = checkOutTime else { return nil }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: out)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")  // ← 追加
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    // MARK: - 退館時プラン表示名の分岐（通常利用・雨割・ナイトサウナ）

    private var isMale: Bool { gender == "男" }

    // 朝活の「＋〜」項目は、保存値(plan)はそのままに、
    // 在館中一覧・履歴・退館確認のタグ表示だけ「朝活＋〜」とする。
    private static let morningPlusPlans: Set<String> = ["＋軽食", "＋ポンチョ", "＋パック", "＋ステッカー"]
    var displayPlanName: String {
        if Self.morningPlusPlans.contains(plan) {
            return "朝活" + plan
        }
        return plan
    }

    // スプレッドシート送信専用の表示名。朝活の「＋〜」項目は、アプリ内表示（「朝活＋〜」）とは異なり、
    // 旧表示の「朝活〜」（「＋」なし）に戻す。アプリ内の表示（displayPlanName）には影響しない。
    private static let morningPlusToOldSheetName: [String: String] = [
        "＋軽食": "朝活軽食",
        "＋ポンチョ": "朝活ポンチョ",
        "＋パック": "朝活パック",
        "＋ステッカー": "朝活ステッカー"
    ]
    // 「ランステ＋通常利用」でサウナ利用開始済みの間は「（サウナ中）」を付ける。
    // Apps Script 側がランニング中（在館人数に含めない）とサウナ利用中を区別するための目印。
    // 退館時は sheetCheckoutPlanName で最終プラン名に上書きされる。
    var sheetPlanName: String {
        if plan == "ランステ＋通常利用", saunaStartTime != nil {
            return "ランステ＋通常利用（サウナ中）"
        }
        return Self.morningPlusToOldSheetName[plan] ?? plan
    }

    // 退館ポップアップに表示するプラン名
    var checkoutPlanDisplayName: String {
        resolvedCheckoutPlanName(fallback: displayPlanName)
    }

    // スプレッドシート送信専用の退館時プラン名。朝活の「＋〜」項目のみ旧表示の「朝活〜」（「＋」なし）に戻す。
    var sheetCheckoutPlanName: String {
        resolvedCheckoutPlanName(fallback: sheetPlanName)
    }

    // 退館時のプラン名の分岐。通常利用・雨割・ナイトサウナ等はここで確定し、それ以外は fallback を返す。
    private func resolvedCheckoutPlanName(fallback: String) -> String {
        if discounts.contains("リロクラブ") {
            return "無制限"
        }
        let stay = stayDuration ?? 0
        switch plan {
        case "ランステ＋通常利用":
            return "ランステ+" + resolvedNormalUsePlanName(stay: stay)
        case "通常利用":
            return resolvedNormalUsePlanName(stay: stay)
        case "雨割":
            return resolvedRainOrNightPlanName(stay: stay, baseLabel: "雨割")
        case "ナイトサウナ":
            return resolvedRainOrNightPlanName(stay: stay, baseLabel: "ナイトサウナ")
        default:
            return fallback
        }
    }

    // 退館ポップアップに表示するレンタル品と、課金対象（実際にお金がかかるもの）かどうか
    // ・休日・短時間の雨割/ナイトサウナ＋水着レンタル時は「水着」を追加表示
    // ・LINE系割引（水着・ポンチョ・ハット・マット）やトモダチ割が適用される場合、金銭は発生しない
    // ・砂時計は常に金銭が発生しないものとして扱う
    var checkoutRentalItemsBilling: [(text: String, isBillable: Bool)] {
        var items = rentalItems

        if plan == "雨割" || plan == "ナイトサウナ" {
            let stay = stayDuration ?? 0
            let shortLimit = isMale ? 65 : 95
            if isHoliday, swimwearRental, stay <= shortLimit, !items.contains("水着") {
                items.append("水着")
            }
        }

        // 退館ポップアップに「平日/休日 ナイトサウナ・雨割」（フル名称）が表示される場合は、
        // LINE割引の有無にかかわらず水着を黒文字（非課金扱い）で表示する
        let isFullPlanNameDisplayed = (plan == "雨割" || plan == "ナイトサウナ")
            && checkoutPlanDisplayName == "\(isHoliday ? "休日" : "平日")\(plan)"
        // 朝活プラン（＋軽食／＋ポンチョ／＋パック／＋ステッカー、旧表記の朝活◯◯）は水着代がかからない。
        // 朝活ポンチョ（＋ポンチョ）はポンチョ代もかからない。
        let isMorningPlan = Self.morningPlusPlans.contains(plan) || ["朝活軽食", "朝活ポンチョ", "朝活パック"].contains(plan)
        let isMorningPonchoPlan = plan == "＋ポンチョ" || plan == "朝活ポンチョ"
        // 休日の雨割・ナイトサウナは、男性は60分・女性は90分を超過した時点で水着代が無料になる
        // （プラン名の切り替わりの猶予5分より優先する）。
        let isOvertimeSwimwearFree = (plan == "雨割" || plan == "ナイトサウナ") && isHoliday
            && (stayDuration ?? 0) > (isMale ? 60 : 90)
        let swimwearDiscounted = discounts.contains("LINE水着") || discounts.contains("トモダチ割")
            || isFullPlanNameDisplayed || isMorningPlan || isOvertimeSwimwearFree
        let ponchoDiscounted = discounts.contains("LINEポンチョ") || isMorningPonchoPlan
        let hatDiscounted = discounts.contains("LINEハット")
        let matDiscounted = discounts.contains("LINEマット")

        func isFree(_ item: String) -> Bool {
            if item.contains("水着"), swimwearDiscounted { return true }
            if item.contains("ポンチョ"), ponchoDiscounted { return true }
            if item.contains("ハット"), hatDiscounted { return true }
            if item.contains("マット"), matDiscounted { return true }
            if item.contains("砂時計") { return true }
            return false
        }

        return Self.applyRentalSets(items, isFree: isFree)
    }

    // レンタル品の組み合わせを最安になるようセット名／単品にまとめる。
    // ・水着＋ハット＋マット＋ポンチョ → セットC（950円）
    // ・ハット＋マット＋ポンチョ       → セットB（500円）
    // ・ハット＋マット                 → セットA（300円）
    // ・水着→500円、ハット・マット・ポンチョ→各250円（単品）
    // 割引等で無料になった品はセットの計算に含めず、単独で無課金表示する
    // （無料の品を課金セットに含めると、その分だけ割高な会計になってしまうため）。
    // 例：水着＋ハット＋マット＋ポンチョをレンタルし、トモダチ割で水着のみ無料の場合、
    //     セットC（950円）ではなく、水着を無課金表示にした上でセットB（500円）を課金表示する。
    // セット対象外の品（砂時計・カスタム品等）は従来通り個別に課金/無課金を判定する。
    private static func applyRentalSets(_ items: [String], isFree: (String) -> Bool) -> [(text: String, isBillable: Bool)] {
        func billing(_ item: String) -> (text: String, isBillable: Bool) {
            (text: item, isBillable: !isFree(item))
        }

        let coreItemNames: Set<String> = ["水着", "ハット", "マット", "ポンチョ"]
        let coreItems = items.filter { coreItemNames.contains($0) }
        let otherItems = items.filter { !coreItemNames.contains($0) }

        guard !coreItems.isEmpty else {
            return otherItems.map(billing)
        }

        let freeCoreItems = coreItems.filter(isFree)
        let billableCoreItems = Set(coreItems).subtracting(freeCoreItems)

        let grouping = minimumCostRentalGrouping(billableCoreItems)
        let groupResults = grouping.map { (text: $0.name, isBillable: true) }
        let freeResults = freeCoreItems.map { (text: $0, isBillable: false) }

        return groupResults + freeResults + otherItems.map(billing)
    }

    private struct RentalBundle {
        let name: String
        let items: Set<String>
        let price: Int
    }

    private static let rentalBundles: [RentalBundle] = [
        RentalBundle(name: "セットC", items: ["水着", "ハット", "マット", "ポンチョ"], price: 950),
        RentalBundle(name: "セットB", items: ["ハット", "マット", "ポンチョ"], price: 500),
        RentalBundle(name: "セットA", items: ["ハット", "マット"], price: 300),
    ]

    private static let rentalSinglePrices: [String: Int] = [
        "水着": 500, "ハット": 250, "マット": 250, "ポンチョ": 250,
    ]

    // 課金対象の品ぞろえに対し、セット料金・単品料金の組み合わせのうち合計が最安になるものを総当たりで求める。
    // 品数が最大4つ（水着・ハット・マット・ポンチョ）のため、単純な再帰で十分高速。
    private static func minimumCostRentalGrouping(_ billableItems: Set<String>) -> [(name: String, price: Int)] {
        guard !billableItems.isEmpty else { return [] }

        var bestResult: [(name: String, price: Int)] = []
        var bestPrice = Int.max

        for bundle in rentalBundles where bundle.items.isSubset(of: billableItems) {
            let remaining = billableItems.subtracting(bundle.items)
            let subResult = minimumCostRentalGrouping(remaining)
            let totalPrice = bundle.price + subResult.reduce(0) { $0 + $1.price }
            if totalPrice < bestPrice {
                bestPrice = totalPrice
                bestResult = [(bundle.name, bundle.price)] + subResult
            }
        }

        for item in billableItems {
            guard let price = rentalSinglePrices[item] else { continue }
            let remaining = billableItems.subtracting([item])
            let subResult = minimumCostRentalGrouping(remaining)
            let totalPrice = price + subResult.reduce(0) { $0 + $1.price }
            if totalPrice < bestPrice {
                bestPrice = totalPrice
                bestResult = [(item, price)] + subResult
            }
        }

        return bestResult
    }

    // 「通常利用」：性別・平日休日・滞在時間（+5分バッファ）で分岐
    // 30分プランの適用判定：平日・男女共通・利用開始から33分以内、かつ利用開始が10:00〜18:00の間。
    // 利用開始は、通常は入館時刻、「ランステ＋通常利用」ではサウナ利用開始時刻。
    private func isThirtyMinutePlan(stay: Int) -> Bool {
        guard !isHoliday, stay <= 33 else { return false }
        let start = (plan == "ランステ＋通常利用" ? saunaStartTime : nil) ?? checkInTime
        let calendar = Calendar.current
        let minutes = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
        return minutes >= 10 * 60 && minutes <= 18 * 60
    }

    private func resolvedNormalUsePlanName(stay: Int) -> String {
        if isThirtyMinutePlan(stay: stay) { return "30分" }
        if isMale {
            if stay <= 65 { return "60分" }
            if stay <= 95 { return "90分" }
            if isHoliday, stay <= 125 { return "120分" }
            return "無制限"
        } else {
            if stay <= 95 { return "90分" }
            if stay <= 125 { return "120分" }
            if isHoliday, stay <= 155 { return "150分" }
            return "無制限"
        }
    }

    // 「雨割」「ナイトサウナ」：性別・平日休日・滞在時間・水着レンタル有無で分岐
    // ・水着をLINE割引でレンタルした場合は、通常のレンタル（水着なし）と同様に短時間ラベルを表示する
    private func resolvedRainOrNightPlanName(stay: Int, baseLabel: String) -> String {
        let shortLimit = isMale ? 65 : 95
        let midLimit = isMale ? 95 : 125
        let shortLabel = isMale ? "60分" : "90分"
        let midLabel = isMale ? "90分" : "120分"
        let swimwearFree = !swimwearRental || discounts.contains("LINE水着")

        if isHoliday {
            if stay <= shortLimit { return shortLabel }
            if stay <= midLimit, swimwearFree { return midLabel }
            return "休日\(baseLabel)"
        } else {
            if stay <= shortLimit, swimwearFree { return shortLabel }
            return "平日\(baseLabel)"
        }
    }
}

