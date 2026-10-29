//
//  CheckInView.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

import SwiftUI

struct CheckInView: View {
    @EnvironmentObject var store: GuestStore
    @Environment(\.dismiss) var dismiss

    private var lockerNumbers: [String] { store.pendingLockerNumbers }
    @State private var selectedTab: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // タブバー（2人以上の場合のみ表示）
                if lockerNumbers.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(lockerNumbers.enumerated()), id: \.offset) { index, locker in
                                Button {
                                    selectedTab = index
                                } label: {
                                    Text(locker)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(selectedTab == index
                                                    ? Color(hex: "1D9E75")
                                                    : Color(.systemGray5))
                                        .foregroundColor(selectedTab == index
                                                         ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    Divider()
                }

                // 各人のフォーム（横スクロール）
                TabView(selection: $selectedTab) {
                    ForEach(Array(lockerNumbers.enumerated()), id: \.offset) { index, locker in
                        CheckInFormView(lockerNumber: locker)
                            .environmentObject(store)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(lockerNumbers.count > 1
                             ? "入館登録（\(lockerNumbers.count)名）"
                             : "入館登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        removeLocker(at: selectedTab)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("削除")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveAll()
                    } label: {
                        HStack(spacing: 4){
                            Image(systemName: "paperplane")
                            Text("保存")
                        }
                            .font(.caption)
                            .foregroundColor(isSaveDisabled ? .gray : Color(hex: "1D9E75"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { duplicateLockerMessage != nil },
            set: { if !$0 { duplicateLockerMessage = nil } }
        )) {
            Button("OK") { duplicateLockerMessage = nil }
        } message: {
            Text(duplicateLockerMessage ?? "")
        }
    }

    // MARK: - タブ削除
    private func removeLocker(at index: Int) {
        let locker = lockerNumbers[index]

        // フォームデータも削除
        store.checkInFormData.removeValue(forKey: locker)
        store.pendingLockerNumbers.remove(at: index)

        // タブが0になったら画面を閉じる
        if store.pendingLockerNumbers.isEmpty {
            store.showCheckIn = false
            store.clearPendingLockers()
            dismiss()
            return
        }

        // 選択中のタブを調整
        if selectedTab >= store.pendingLockerNumbers.count {
            selectedTab = store.pendingLockerNumbers.count - 1
        }
    }

    // 全員プランが選択されているか確認
    private var isSaveDisabled: Bool {
        lockerNumbers.contains { locker in
            (store.checkInFormData[locker]?.plan ?? "").isEmpty
        }
    }

    @State private var duplicateLockerMessage: String? = nil

    private func saveAll() {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!  // ← 追加

        // 秒まで含めた時刻を生成
        let timeOnly = calendar.date(
            bySettingHour: calendar.component(.hour, from: now),
            minute: calendar.component(.minute, from: now),
            second: calendar.component(.second, from: now),  // ← 追加
            of: Date(timeIntervalSinceReferenceDate: 0)
        ) ?? now

        let dateOnly = calendar.startOfDay(for: now)

        // 既に在館中のロッカーには保存しない（二重入館防止）。失敗したロッカーは番号を集めて知らせる。
        var failedLockers: [String] = []
        for locker in lockerNumbers {
            let data = store.checkInFormData[locker] ?? CheckInFormData()
            let record = GuestRecord(
                lockerNumber: locker,
                date: dateOnly,
                checkInTime: timeOnly,
                plan: data.plan,
                gender: data.gender,
                swimwearRental: data.rentalItems.contains("水着"),
                rentalItems: data.rentalItems,
                discounts: data.discounts,
                storedItems: data.storedItems,
                cleansingPurchased: data.cleansingPurchased,
                memo: data.memo,
                isHoliday: data.isHoliday
            )
            if !store.addRecord(record) {
                failedLockers.append(locker)
            }
        }

        if failedLockers.isEmpty {
            store.showCheckIn = false
            store.clearPendingLockers()
            dismiss()
        } else {
            // 保存できたロッカーだけタブから取り除き、失敗したロッカーは残して知らせる
            for locker in lockerNumbers where !failedLockers.contains(locker) {
                store.checkInFormData.removeValue(forKey: locker)
            }
            store.pendingLockerNumbers = failedLockers
            if selectedTab >= failedLockers.count {
                selectedTab = max(0, failedLockers.count - 1)
            }
            duplicateLockerMessage = "すでに在館中のためロッカー \(failedLockers.joined(separator: "・")) は保存できませんでした。番号を確認してください。"
        }
    }
}

