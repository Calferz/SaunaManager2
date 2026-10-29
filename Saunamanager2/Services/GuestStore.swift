//
//  GuestScore.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

import Foundation
import Combine
import EventKit

class GuestStore: ObservableObject {
    @Published var records: [GuestRecord] = []
    @Published var showCheckIn: Bool = false
    // 北エリア・南エリアの男女割り当ては水曜7時を境に毎週交互に切り替わる（金曜7時〜土曜7時はMen's dayで両エリア男性）。
    // 通常は自動計算するが、念のため本日限定で手動上書きできるようにする（日付が変わると自動的に解除される）。
    @Published private var manualAssignmentOverride: WeeklyAssignment? = nil
    @Published private var manualAssignmentOverrideDay: Date? = nil

    var weeklyAssignment: WeeklyAssignment {
        if let override = manualAssignmentOverride,
           let overrideDay = manualAssignmentOverrideDay,
           isSameJSTDay(overrideDay, Date()) {
            return override
        }
        return WeeklyAssignment.current(at: Date())
    }

    var hasManualAssignmentOverrideToday: Bool {
        guard let overrideDay = manualAssignmentOverrideDay else { return false }
        return isSameJSTDay(overrideDay, Date())
    }

    // 本日限定で北南の割り当てを手動上書きする
    func setManualAssignmentOverride(north: AreaGender, south: AreaGender) {
        manualAssignmentOverride = WeeklyAssignment(northGender: north, southGender: south)
        manualAssignmentOverrideDay = Date()
        saveManualAssignmentOverride()
    }

    // 手動上書きを解除し、自動計算に戻す
    func clearManualAssignmentOverride() {
        manualAssignmentOverride = nil
        manualAssignmentOverrideDay = nil
        UserDefaults.standard.removeObject(forKey: "manualAssignmentOverride")
        UserDefaults.standard.removeObject(forKey: "manualAssignmentOverrideDay")
    }

    private func saveManualAssignmentOverride() {
        guard let override = manualAssignmentOverride, let day = manualAssignmentOverrideDay else { return }
        if let data = try? JSONEncoder().encode(override) {
            UserDefaults.standard.set(data, forKey: "manualAssignmentOverride")
        }
        UserDefaults.standard.set(day, forKey: "manualAssignmentOverrideDay")
    }

    // 手動上書きを読み込み（日付が変わっていれば自動的に無効となる＝weeklyAssignmentが自動計算にフォールバックする）
    func loadManualAssignmentOverride() {
        guard let data = UserDefaults.standard.data(forKey: "manualAssignmentOverride"),
              let decoded = try? JSONDecoder().decode(WeeklyAssignment.self, from: data),
              let day = UserDefaults.standard.object(forKey: "manualAssignmentOverrideDay") as? Date
        else { return }
        manualAssignmentOverride = decoded
        manualAssignmentOverrideDay = day
    }

    private func isSameJSTDay(_ a: Date, _ b: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar.isDate(a, inSameDayAs: b)
    }

    @Published var customPlans: [String] = []
    @Published var customRentalItems: [String] = []
    @Published var customDiscounts: [String] = []
    @Published var pendingLockerNumbers: [String] = []
    @Published var checkInFormData: [String: CheckInFormData] = [:]
    @Published var dailySetting: DailySetting = DailySetting()
    @Published var aromaList: [String] = []    // アロマのマスターリスト
    @Published var serviceList: [String] = []  // サービスのマスターリスト

    // 在館中一覧の朝活・ナイトサウナ・雨割トグル（ON/OFF）
    // 雨割は完全手動。朝活・ナイトサウナは適用時間の境界（開始・終了）をまたいだ瞬間に自動でON/OFFが切り替わる。
    // 適用時間中に手動で変更した場合は、次の境界（終了時刻）まではその状態を優先する。
    @Published var isMorningActive: Bool = false
    @Published var isNightActive: Bool = false
    @Published var isRainyActive: Bool = false

    private var toggleTimer: Timer?
    private var lastMorningWindowActive: Bool?
    private var lastNightWindowActive: Bool?

    // 朝活（7:25〜10:00）・ナイトサウナ（17:00〜22:05）の適用時間かどうかを現在時刻から判定し、
    // 前回判定から状態が変わった（＝境界をまたいだ）場合のみトグルを自動更新する。
    private func evaluateTimeBasedToggles() {
        let calendar = Calendar.current
        let now = Date()
        let totalMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let morningWindowActive = totalMinutes >= 449 && totalMinutes < 600     // 7:29〜10:00
        let nightWindowActive = totalMinutes >= 1079 && totalMinutes < 1325     // 17:59〜22:05

        if lastMorningWindowActive == nil || morningWindowActive != lastMorningWindowActive {
            isMorningActive = morningWindowActive
            lastMorningWindowActive = morningWindowActive
        }
        if lastNightWindowActive == nil || nightWindowActive != lastNightWindowActive {
            isNightActive = nightWindowActive
            lastNightWindowActive = nightWindowActive
        }
    }

    // アプリ起動時に呼ぶ。即座に現在時刻で判定した上で、以後は定期的に境界をまたいだかどうかをチェックする。
    func startAutoTimeBasedToggles() {
        evaluateTimeBasedToggles()
        toggleTimer?.invalidate()
        toggleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluateTimeBasedToggles()
        }
    }

    deinit {
        toggleTimer?.invalidate()
    }

    func addScannedLocker(_ lockerNumber: String) {
        // 重複追加を防ぐ
        if !pendingLockerNumbers.contains(lockerNumber) {
            pendingLockerNumbers.append(lockerNumber)
        }
    }

    func clearPendingLockers() {
        pendingLockerNumbers = []
        checkInFormData = [:]
    }

    // 在館中の客
    var activeGuests: [GuestRecord] {
        records.filter { $0.isCheckedIn }
    }

    // 在館人数としてカウントする客（ランニング中のランステ利用者を除く＝サウナ利用者のみ）
    var saunaGuests: [GuestRecord] {
        activeGuests.filter { !$0.isRunningOnly }
    }

    var todayCheckedOutGuests: [GuestRecord] {
        let calendar = Calendar.current
        return records.filter {
            !$0.isCheckedIn &&
            calendar.isDateInToday($0.checkInTime)
        }
    }
    
    // 同じロッカー番号がすでに在館中の場合は追加を拒否する（二重入館防止）。
    // 成功した場合のみ true を返す。
    @discardableResult
    func addRecord(_ record: GuestRecord) -> Bool {
        let hasActiveConflict = records.contains {
            $0.lockerNumber == record.lockerNumber && $0.isCheckedIn
        }
        guard !hasActiveConflict else { return false }

        records.append(record)
        save()
        // ここでSheets送信が呼ばれているか確認
        Task {
            await SheetsService.sendCheckIn(record)
        }
        return true
    }

    // 「ランステ＋通常利用」プランで、ランニングから帰還した際のサウナ利用開始を記録する。
    // 退館処理は行わない（在館中のまま）。
    func startSaunaUsage(id: UUID, time: Date) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].saunaStartTime = time
            save()
            let updatedRecord = records[index]
            Task {
                await SheetsService.sendSaunaStart(updatedRecord)
            }
        }
    }

    func checkOut(id: UUID, time: Date) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].checkOutTime = time
            save()
            // checkOutTimeがセットされた後のrecordを渡す
            let updatedRecord = records[index]
            Task {
                await SheetsService.sendCheckOut(updatedRecord)
            }
        }
    }

    // UserDefaultsに永続化
    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "guestRecords")
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: "guestRecords"),
           let decoded = try? JSONDecoder().decode([GuestRecord].self, from: data) {
            records = decoded
        }
    }
    
    // 今日が祝日かどうか（カレンダーの「祝日」カレンダーに予定があるか）を判定する。
    // 入館画面（NFC・手動）で共通利用。アクセス不許可・エラー時は false。
    static func isPublicHolidayToday() async -> Bool {
        let eventStore = EKEventStore()
        do {
            guard try await eventStore.requestFullAccessToEvents() else { return false }
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let calendars = eventStore.calendars(for: .event).filter {
                $0.title.contains("祝日") || $0.title.contains("Holiday")
            }
            let predicate = eventStore.predicateForEvents(
                withStart: startOfDay,
                end: endOfDay,
                calendars: calendars.isEmpty ? nil : calendars
            )
            return !eventStore.events(matching: predicate).isEmpty
        } catch {
            print("祝日チェックエラー: \(error.localizedDescription)")
            return false
        }
    }

    // ロッカー番号から性別を自動判別
    func genderForLocker(_ lockerNumber: String) -> String {
        let prefix = lockerNumber.prefix(1).uppercased()
        switch prefix {
        case "N": return weeklyAssignment.northGender.rawValue
        case "S": return weeklyAssignment.southGender.rawValue
        default:  return ""
        }
    }

    func saveCustomItems() {
        UserDefaults.standard.set(customPlans, forKey: "customPlans")
        UserDefaults.standard.set(customRentalItems, forKey: "customRentalItems")
        UserDefaults.standard.set(customDiscounts, forKey: "customDiscounts")
    }

    func loadCustomItems() {
        customPlans = UserDefaults.standard.stringArray(forKey: "customPlans") ?? []
        customRentalItems = UserDefaults.standard.stringArray(forKey: "customRentalItems") ?? []
        customDiscounts = UserDefaults.standard.stringArray(forKey: "customDiscounts") ?? []
    }
    
    // レコードを削除
    func deleteRecord(_ record: GuestRecord) {
        records.removeAll { $0.id == record.id }
        save()
        Task {
            await SheetsService.deleteRecord(record)
        }
    }

    // レコードを更新
    func updateRecord(_ record: GuestRecord, originalLockerNumber: String, originalCheckInTime: String) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
            save()
            Task {
                await SheetsService.updateRecord(
                    record,
                    originalLockerNumber: originalLockerNumber,
                    originalCheckInTime: originalCheckInTime
                )
            }
        }
    }
    
    func saveDailySetting() {
        if let data = try? JSONEncoder().encode(dailySetting) {
            UserDefaults.standard.set(data, forKey: "dailySetting")
        }
    }

    func loadDailySetting() {
        if let data = UserDefaults.standard.data(forKey: "dailySetting"),
           let decoded = try? JSONDecoder().decode(DailySetting.self, from: data) {
            dailySetting = decoded
        }
    }
    
    func saveAromaList() {
        UserDefaults.standard.set(aromaList, forKey: "aromaList")
    }

    func loadAromaList() {
        aromaList = UserDefaults.standard.stringArray(forKey: "aromaList") ?? [
            "シトラス", "ひのき", "ユーカリ", "バーチ", "ベリー", "タール", "ウィンタースパイス"
        ]
    }

    func saveServiceList() {
        UserDefaults.standard.set(serviceList, forKey: "serviceList")
    }

    func loadServiceList() {
        serviceList = UserDefaults.standard.stringArray(forKey: "serviceList") ?? [
            "平日料金(2500円)", "休日料金(3000円)", "平日朝活(2000円)", "休日朝活(2500円)",
            "ナイトサウナ(2000円)", "ナイトサウナ(2500円)", "雨割(2000円) 水着込", "雨割(2500円) 水着込",
            "トモダチ割(2人~水着無料)", "営業終了", "整理券配布中", "ヴィヒタ利用可", "4種のアロマ",
            "撮影可能", "メンテナンス日", "貸切営業", "Men's day"
        ]
    }
}

enum AreaGender: String, Codable {
    case male = "男"
    case female = "女"
}

struct WeeklyAssignment: Codable {
    var northGender: AreaGender
    var southGender: AreaGender

    // 基準日: 2026/8/19（水）7:00 は 北=女性・南=男性。ここから7日単位で交互に切り替わる。
    private static let referenceComponents = DateComponents(
        year: 2026, month: 8, day: 19, hour: 7
    )

    // 北エリア・南エリアの男女割り当てを、指定した時刻から自動計算する。
    // ・水曜7:00を境に毎週交互（基準週=北女南男、翌週=北男南女、…）
    // ・例外: 金曜7:00〜土曜7:00はMen's dayで北南とも男性
    static func current(at date: Date) -> WeeklyAssignment {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

        guard let referenceDate = calendar.date(from: referenceComponents) else {
            return WeeklyAssignment(northGender: .male, southGender: .female)
        }

        let weekLength: TimeInterval = 7 * 24 * 3600
        let secondsSinceReference = date.timeIntervalSince(referenceDate)
        let weeksElapsed = Int(floor(secondsSinceReference / weekLength))
        let isReferenceWeekPattern = ((weeksElapsed % 2) + 2) % 2 == 0

        var north: AreaGender = isReferenceWeekPattern ? .female : .male
        var south: AreaGender = isReferenceWeekPattern ? .male : .female

        // Men's day（金曜7:00〜土曜7:00）は北南とも男性
        let weekday = calendar.component(.weekday, from: date)  // 1=日, 6=金, 7=土
        let hour = calendar.component(.hour, from: date)
        let isFridayFrom7 = weekday == 6 && hour >= 7
        let isSaturdayBefore7 = weekday == 7 && hour < 7
        if isFridayFrom7 || isSaturdayBefore7 {
            north = .male
            south = .male
        }

        return WeeklyAssignment(northGender: north, southGender: south)
    }
}

struct CheckInFormData {
    var plan: String = ""
    var isHoliday: Bool = false
    var rentalItems: [String] = []
    var discounts: [String] = []
    var storedItems: [String] = []
    var cleansingPurchased: Bool = false
    var gender: String = ""
    var memo: String = ""
}

struct DailySetting: Codable {
    var date: String = ""
    var upperAroma: [String] = []    // 上サウナ室
    var lowerAroma: [String] = []    // 下サウナ室
    var services: [String] = []      // サービス
    var northGender: String = "男"
    var southGender: String = "女"
    var note: String = ""
}

