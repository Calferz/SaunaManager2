//
//  SaunaManagerApp.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

import SwiftUI
import AudioToolbox

@main
struct SaunaManagerApp: App {
    @StateObject private var store = GuestStore()
    @State private var checkOutSummaryGuest: GuestRecord? = nil

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { url in
                    guard url.host == "checkin",
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let locker = components.queryItems?.first(where: { $0.name == "locker" })?.value
                    else { return }

                    // 在館中かどうかを先に確認
                    // onOpenURL内の退館処理部分
                    if let activeRecord = store.records.first(where: {
                        $0.lockerNumber == locker && $0.isCheckedIn
                    }) {
                        if activeRecord.plan == "ランステ＋通常利用", activeRecord.saunaStartTime == nil {
                            // ランニングから帰還：退館処理はせず、サウナ利用開始時刻のみ記録
                            store.startSaunaUsage(id: activeRecord.id, time: Date())

                            AudioServicesPlaySystemSound(1407)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } else {
                            // 退館処理
                            store.checkOut(id: activeRecord.id, time: Date())

                            // 音と触覚フィードバック ← 追加
                            AudioServicesPlaySystemSound(1407)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)

                            // 後払い：会計確認ポップアップを表示（プラン・レンタル品・割引・滞在時間）
                            if let updatedRecord = store.records.first(where: { $0.id == activeRecord.id }) {
                                checkOutSummaryGuest = updatedRecord
                            }
                        }
                    } else {
                        // 入館処理
                        store.addScannedLocker(locker)
                        store.showCheckIn = true
                        
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                }
                .sheet(item: $checkOutSummaryGuest) { guest in
                    CheckOutSummaryView(guest: guest) {
                        checkOutSummaryGuest = nil
                    }
                }
                .sheet(isPresented: $store.showCheckIn, onDismiss: {
                    store.clearPendingLockers()
                }) {
                    if !store.pendingLockerNumbers.isEmpty {  // ← ロッカーがある時だけ表示
                        CheckInView()
                            .environmentObject(store)
                    }
                }
                .onAppear {
                    store.load()
                    store.loadManualAssignmentOverride()
                    store.loadCustomItems()
                    store.loadDailySetting()
                    store.loadAromaList()
                    store.loadServiceList()
                    store.startAutoTimeBasedToggles()
                }
        }
    }
}

