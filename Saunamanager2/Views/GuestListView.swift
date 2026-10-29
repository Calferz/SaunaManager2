//
//  GuestListView.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

//  在館者一覧

import SwiftUI

struct GuestListView: View {
    @EnvironmentObject var store: GuestStore
    @State private var sheetType: SheetType? = nil

    // GuestListView.swift に追加
    private var maleCount: Int {
        store.saunaGuests.filter { $0.gender == "男" }.count
    }

    private var femaleCount: Int {
        store.saunaGuests.filter { $0.gender == "女" }.count
    }

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationView {
            Group {
                if store.activeGuests.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("現在の在館者はいません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(store.activeGuests) { guest in
                                Button {
                                    sheetType = .checkOut(guest)  // ← 行タップ
                                } label: {
                                    GuestRowView(guest: guest, formatter: formatter)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    // 「ランステ＋通常利用」でまだランニング中（サウナ利用未開始）の場合のみ、
                                    // 手動でサウナ利用への切り替え（NFC再スキャンと同じ処理）を行えるようにする
                                    if guest.plan == "ランステ＋通常利用", guest.saunaStartTime == nil {
                                        Button {
                                            store.startSaunaUsage(id: guest.id, time: Date())
                                        } label: {
                                            Label("サウナ利用開始", systemImage: "flame")
                                        }
                                        .tint(.orange)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.deleteRecord(guest)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("在館中")
                                Spacer()
                                HStack(spacing: 8) {
                                    Text("計 \(store.saunaGuests.count)名")
                                        .foregroundColor(.secondary)
                                    Text("男 \(maleCount)名")
                                        .foregroundColor(.blue)
                                    Text("女 \(femaleCount)名")
                                        .foregroundColor(.pink)
                                }
                                .font(.caption)
                            }
                        }

                        let todayCheckedOut = store.todayCheckedOutGuests
                        if !todayCheckedOut.isEmpty && store.activeGuests.isEmpty {
                            Section {
                                ForEach(todayCheckedOut) { guest in
                                    GuestRowView(guest: guest, formatter: formatter)
                                        .opacity(0.5)
                                }
                            } header: {
                                Text("本日の退館済み（\(todayCheckedOut.count)名）")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("在館中一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.isMorningActive.toggle()
                    } label: {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(store.isMorningActive ? .orange : .gray)
                    }
                }
                ToolbarSpacer(.fixed, placement: .navigationBarLeading)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.isNightActive.toggle()
                    } label: {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(store.isNightActive ? .indigo : .gray)
                    }
                }
                ToolbarSpacer(.fixed, placement: .navigationBarLeading)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.isRainyActive.toggle()
                    } label: {
                        Image(systemName: "umbrella.fill")
                            .foregroundColor(store.isRainyActive ? .blue : .gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sheetType = .manualCheckIn  // ← +ボタン
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $sheetType) { type in
                switch type {
                case .checkOut(let guest):
                    CheckOutView(guest: guest)
                        .environmentObject(store)
                case .manualCheckIn:
                    ManualCheckInView()
                        .environmentObject(store)
                }
            }
        }
    }
    
}

// MARK: - 1行分のゲスト情報

struct GuestRowView: View {
    let guest: GuestRecord
    let formatter: DateFormatter

    // 時間制プランの期限計算
    private var deadline: Date? {
        switch guest.plan {
        case "30分":  return Calendar.current.date(byAdding: .minute, value: 33,  to: guest.checkInTime)
        case "60分":  return Calendar.current.date(byAdding: .minute, value: 60,  to: guest.checkInTime)
        case "90分":  return Calendar.current.date(byAdding: .minute, value: 90,  to: guest.checkInTime)
        case "120分": return Calendar.current.date(byAdding: .minute, value: 120, to: guest.checkInTime)
        case "150分": return Calendar.current.date(byAdding: .minute, value: 150, to: guest.checkInTime)
        default:      return nil  // 無制限はnill
        }
    }

    // 期限まで残り何分か
    private var remainingMinutes: Int? {
        guard let dl = deadline else { return nil }
        return max(0, Int(dl.timeIntervalSince(Date()) / 60))
    }

    // 「ランステ＋通常利用」：ランニングの目安上限（3時間）

    // 滞在時間（退館済み用）
    private var stayText: String? {
        guard let min = guest.stayDuration else { return nil }
        return "\(min / 60)h\(min % 60)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // ロッカー番号
                Text(guest.lockerNumber)
                    .font(.headline)

                Spacer()

                // 在館中 or 退館済みバッジ
                if guest.isCheckedIn {
                    StatusBadge(label: "在館中", color: .green)
                } else {
                    StatusBadge(label: "退館済", color: .red)
                }
            }

            // プラン・レンタル・割引
            Text(summaryText)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                if guest.isCheckedIn {
                    if guest.plan == "ランステ＋通常利用" {
                        if let saunaStart = guest.saunaStartTime {
                            // サウナ利用開始後
                            Label("サウナ利用中（開始 \(formatter.string(from: saunaStart))）",
                                  systemImage: "flame")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            // ランニング中（目安：上限3時間、経過時間を表示）
                            let elapsed = guest.runningElapsedMinutes()
                            Label("ランニング中・経過\(elapsed)分",
                                  systemImage: "figure.run")
                                .font(.caption2)
                                .foregroundColor(elapsed >= 165 ? .orange : .secondary)
                        }
                    } else {
                        // 入館時刻
                        Label("入館 \(formatter.string(from: guest.checkInTime))",
                              systemImage: "arrow.right.circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // 期限 or 無制限
                        if let dl = deadline {
                            Label("期限 \(formatter.string(from: dl))",
                                  systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(remainingMinutes ?? 99 <= 15 ? .orange : .secondary)
                        } else {
                            Label("無制限", systemImage: "infinity")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // 退館済み：入館〜退館・滞在時間
                    if let out = guest.checkOutTime, let stay = stayText {
                        Label("\(formatter.string(from: guest.checkInTime)) 〜 \(formatter.string(from: out))（\(stay)）",
                              systemImage: "clock.arrow.circlepath")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var summaryText: String {
        var parts: [String] = [guest.displayPlanName]
        if guest.swimwearRental { parts.append("水着") }
        let otherRentalItems = guest.rentalItems.filter { $0 != "水着" }
        if !otherRentalItems.isEmpty { parts.append(otherRentalItems.joined(separator: "・")) }
        if !guest.discounts.isEmpty { parts.append(guest.discounts.joined(separator: "・")) }
        return parts.joined(separator: " ／ ")
    }
}

