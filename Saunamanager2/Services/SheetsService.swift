//
//  SheetsService.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

import Foundation

class SheetsService {
    
    // スプレッドシートのURL
    private static let webAppURL = Config.sheetsWebAppURL
    
    // MARK: - 入館データを送信
    static func sendCheckIn(_ record: GuestRecord) async {
        let payload: [String: Any] = [
            "action":         "checkin",
            "lockerNumber":   record.lockerNumber,
            "date":           record.dateString,
            "dayOfWeek":      record.dayOfWeek,
            "checkInTime":    record.checkInTimeString,
            "plan":           record.sheetPlanName,
            "gender":         record.gender,
            "swimwearRental": record.swimwearRental,
            "rentalItems":    record.rentalItems.filter { $0 != "水着" }.joined(separator: "・"),
            "discounts":      record.discounts.joined(separator: "・"),
            "storedItems":    record.storedItems.joined(separator: "・"),
            "cleansingPurchased": record.cleansingPurchased,
            "memo":           record.memo
        ]
        print("sendCheckIn payload: \(payload)")
        await send(payload)
    }
    
    // MARK: - 退館データを送信
    // プランは退館時に確定する最終情報（checkoutPlanDisplayName）を送信する。
    // レンタル品は割引の有無によらず、実際に記録した内容（rentalItems）をそのまま送信する。
    // 性別・割引・メモ等、入館時から変わらない情報は checkin 送信済みのためここでは送らない。
    static func sendCheckOut(_ record: GuestRecord) async {
        guard let checkOutTimeString = record.checkOutTimeString else { return }

        var payload: [String: Any] = [
            "action":        "checkout",
            "lockerNumber":  record.lockerNumber,
            "date":          record.dateString,    // ← 追加
            "checkOutTime":  checkOutTimeString,
            "plan":          record.sheetCheckoutPlanName,
            "rentalItems":   record.rentalItems.filter { $0 != "水着" }.joined(separator: "・")
        ]
        addRunStePhases(record, to: &payload)
        await send(payload)
    }

    // 「ランステ＋通常利用」でサウナ利用が始まっている場合のみ、
    // ランニング時間・サウナ利用時間（分）を追加する（滞在時間セルの2行表示用）。
    private static func addRunStePhases(_ record: GuestRecord, to payload: inout [String: Any]) {
        guard record.plan == "ランステ＋通常利用",
              let running = record.runningDuration,
              let sauna = record.stayDuration else { return }
        payload["runningMinutes"] = running
        payload["saunaMinutes"] = sauna
    }

    // MARK: - サウナ利用開始を送信（「ランステ＋通常利用」）
    // プラン欄を「ランステ＋通常利用（サウナ中）」に更新し、在館人数の集計にサウナ利用者として含める。
    static func sendSaunaStart(_ record: GuestRecord) async {
        let payload: [String: Any] = [
            "action":       "saunaStart",
            "lockerNumber": record.lockerNumber,
            "date":         record.dateString,
            "plan":         record.sheetPlanName
        ]
        await send(payload)
    }

    // MARK: - 共通送信処理
    private static func send(_ payload: [String: Any]) async {
        guard let url = URL(string: webAppURL),
              let body = try? JSONSerialization.data(withJSONObject: payload)
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Sheets送信結果: \(httpResponse.statusCode)")
            }
        } catch {
            print("Sheets送信エラー: \(error.localizedDescription)")
        }
    }

    // Services/SheetsService.swift に追加

    // レコードを削除
    static func deleteRecord(_ record: GuestRecord) async {
        let payload: [String: Any] = [
            "action":       "delete",
            "lockerNumber": record.lockerNumber,
            "date":         record.dateString,
            "checkInTime":  record.checkInTimeString
        ]
        print("deleteRecord payload: \(payload)")
        await send(payload)
    }

    // SheetsService.swift に追加
    static func updateRecord(_ record: GuestRecord, originalLockerNumber: String, originalCheckInTime: String) async {
        var payload: [String: Any] = [
            "action":                "update",
            "originalLockerNumber":  originalLockerNumber,   // ← 元のロッカー番号
            "originalCheckInTime":   originalCheckInTime,    // ← 元の入館時刻
            "lockerNumber":          record.lockerNumber,    // ← 新しいロッカー番号
            "date":                  record.dateString,
            "checkInTime":           record.checkInTimeString,
            "checkOutTime":          record.checkOutTimeString ?? "",
            "plan":                  record.sheetPlanName,
            "gender":                record.gender,
            "swimwearRental":        record.swimwearRental,
            "rentalItems":           record.rentalItems.filter { $0 != "水着" }.joined(separator: "・"),
            "discounts":             record.discounts.joined(separator: "・"),
            "storedItems":           record.storedItems.joined(separator: "・"),
            "cleansingPurchased":    record.cleansingPurchased,
            "memo":                  record.memo
        ]
        addRunStePhases(record, to: &payload)
        await send(payload)
    }

    static func updateDailySetting(_ setting: DailySetting) async {
        let payload: [String: Any] = [
            "action":      "updateDailySetting",
            "date":        setting.date,
            "upperAroma":  setting.upperAroma.joined(separator: "・"),
            "lowerAroma":  setting.lowerAroma.joined(separator: "・"),
            "services":    setting.services.joined(separator: "・"),
            "northGender": setting.northGender,
            "southGender": setting.southGender,
            "note":        setting.note
        ]
        print("updateDailySetting payload: \(payload)")
        await send(payload)
    }

    static func updateAssignment(northGender: String, southGender: String) async {
        let payload: [String: Any] = [
            "action":      "updateAssignment",
            "northGender": northGender,
            "southGender": southGender
        ]
        await send(payload)
    }
}

