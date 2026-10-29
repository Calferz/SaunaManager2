//
//  SettingsView.swift
//  SaunaManager
//
//  Created on 2026/05/04.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: GuestStore

    @State private var newPlan: String = ""
    @State private var newRentalItem: String = ""
    @State private var newDiscount: String = ""
    @State private var showDeletePlanAlert: Bool = false
    @State private var showDeleteRentalAlert: Bool = false
    @State private var showDeleteDiscountAlert: Bool = false
    @State private var deleteTarget: String = ""
    @State private var newAroma: String = ""
    @State private var newService: String = ""
    @State private var showDeleteAromaAlert: Bool = false
    @State private var showDeleteServiceAlert: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSavedAlert: Bool = false


    // 本日の設定を保存し、スプレッドシートへ送信する。完了後にポップアップを表示する。
    private func saveSettings() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSaving = true

        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        store.dailySetting.date = f.string(from: Date())
        store.dailySetting.northGender = store.weeklyAssignment.northGender.rawValue
        store.dailySetting.southGender = store.weeklyAssignment.southGender.rawValue
        store.saveDailySetting()

        Task {
            await SheetsService.updateDailySetting(store.dailySetting)
            await SheetsService.updateAssignment(
                northGender: store.weeklyAssignment.northGender.rawValue,
                southGender: store.weeklyAssignment.southGender.rawValue
            )
            await MainActor.run {
                isSaving = false
                showSavedAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - 本日の設定
                Section {
                    // 北エリア・南エリアの男女割り当ては水曜7時を境に自動で切り替わる（金曜7時〜土曜7時はMen's dayで両エリア男性）。
                    // 念のため本日限定で手動上書きも可能。
                    HStack {
                        Text("北側")
                        Spacer()
                        Picker("北エリア", selection: Binding(
                            get: { store.weeklyAssignment.northGender },
                            set: { store.setManualAssignmentOverride(north: $0, south: store.weeklyAssignment.southGender) }
                        )) {
                            Text("男性").tag(AreaGender.male)
                            Text("女性").tag(AreaGender.female)
                        }
                        .pickerStyle(.segmented)
                    }
                    HStack {
                        Text("南側")
                        Spacer()
                        Picker("南エリア", selection: Binding(
                            get: { store.weeklyAssignment.southGender },
                            set: { store.setManualAssignmentOverride(north: store.weeklyAssignment.northGender, south: $0) }
                        )) {
                            Text("男性").tag(AreaGender.male)
                            Text("女性").tag(AreaGender.female)
                        }
                        .pickerStyle(.segmented)
                    }
                    if store.hasManualAssignmentOverrideToday {
                        HStack {
                            Text("本日のみ手動設定中")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Spacer()
                            Button("自動に戻す") {
                                store.clearManualAssignmentOverride()
                            }
                            .font(.caption2)
                        }
                    }
                    Text("北南の割り当ては水曜7:00に自動で切り替わります\n（金曜7:00〜土曜7:00はMen's dayで両エリア男性）")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    // 上サウナ室アロマ
                    VStack(alignment: .leading, spacing: 6) {
                        Text("上サウナ室 アロマ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(store.aromaList, id: \.self) { aroma in
                                Button {
                                    if store.dailySetting.upperAroma.contains(aroma) {
                                        store.dailySetting.upperAroma.removeAll { $0 == aroma }
                                    } else {
                                        store.dailySetting.upperAroma.append(aroma)
                                    }
                                } label: {
                                    Text(aroma)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(store.dailySetting.upperAroma.contains(aroma)
                                                    ? Color(hex: "1D9E75")
                                                    : Color(.systemGray5))
                                        .foregroundColor(store.dailySetting.upperAroma.contains(aroma)
                                                         ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !store.dailySetting.upperAroma.isEmpty {
                            Text("選択中: " + store.dailySetting.upperAroma.joined(separator: "・"))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "1D9E75"))
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 下サウナ室アロマ
                    VStack(alignment: .leading, spacing: 6) {
                        Text("下サウナ室 アロマ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(store.aromaList, id: \.self) { aroma in
                                Button {
                                    if store.dailySetting.lowerAroma.contains(aroma) {
                                        store.dailySetting.lowerAroma.removeAll { $0 == aroma }
                                    } else {
                                        store.dailySetting.lowerAroma.append(aroma)
                                    }
                                } label: {
                                    Text(aroma)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(store.dailySetting.lowerAroma.contains(aroma)
                                                    ? Color(hex: "4A90A4")
                                                    : Color(.systemGray5))
                                        .foregroundColor(store.dailySetting.lowerAroma.contains(aroma)
                                                         ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !store.dailySetting.lowerAroma.isEmpty {
                            Text("選択中: " + store.dailySetting.lowerAroma.joined(separator: "・"))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "4A90A4"))
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // サービス
                    VStack(alignment: .leading, spacing: 6) {
                        Text("適用中のサービス")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(store.serviceList, id: \.self) { service in
                                Button {
                                    if store.dailySetting.services.contains(service) {
                                        store.dailySetting.services.removeAll { $0 == service }
                                    } else {
                                        store.dailySetting.services.append(service)
                                    }
                                } label: {
                                    Text(service)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(store.dailySetting.services.contains(service)
                                                    ? Color(hex: "C07A5A")
                                                    : Color(.systemGray5))
                                        .foregroundColor(store.dailySetting.services.contains(service)
                                                         ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !store.dailySetting.services.isEmpty {
                            Text("選択中: " + store.dailySetting.services.joined(separator: "・"))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "C07A5A"))
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 保存ボタン（押下中は「保存中…」表示で二重押しを防ぎ、完了後にポップアップを表示）
                    Button {
                        saveSettings()
                    } label: {
                        HStack(spacing: 6) {
                            if isSaving {
                                ProgressView()
                                Text("保存中…")
                            } else {
                                Image(systemName: "paperplane")
                                Text("保存")
                            }
                        }
                        .foregroundColor(isSaving ? .secondary : Color(hex: "1D9E75"))
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .disabled(isSaving)
                    .buttonStyle(.plain)
                    
                } header: {
                    Text("今日の設定")
                }
                
                // MARK: - カスタムプラン
                Section {
                    // 既存のカスタムプラン一覧
                    ForEach(store.customPlans, id: \.self) { plan in
                        HStack {
                            Text(plan)
                            Spacer()
                            Button {
                                deleteTarget = plan
                                showDeletePlanAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)  // ← 追加
                        }
                    }
                    
                    // 新規追加
                    HStack {
                        TextField("新しいプラン名", text: $newPlan)
                        Button("追加") {
                            let trimmed = newPlan.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            store.customPlans.append(trimmed)
                            store.saveCustomItems()
                            newPlan = ""
                        }
                        .buttonStyle(.plain)  // ← 追加
                        .disabled(newPlan.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(Color(hex: "1D9E75"))
                    }
                } header: {
                    Text("プラン追加")
                } footer: {
                    Text("追加したプランは入館登録画面に表示されます")
                }
                .alert("削除しますか？", isPresented: $showDeletePlanAlert) {
                    Button("削除", role: .destructive) {
                        store.customPlans.removeAll { $0 == deleteTarget }
                        store.saveCustomItems()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("「\(deleteTarget)」を削除します")
                }
                
                // MARK: - カスタムレンタル品
                Section {
                    // 既存のカスタムレンタル品一覧
                    ForEach(store.customRentalItems, id: \.self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button {
                                deleteTarget = item
                                showDeleteRentalAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)  // ← 追加
                        }
                    }
                    
                    // 新規追加
                    HStack {
                        TextField("新しいレンタル品名", text: $newRentalItem)
                        Button("追加") {
                            let trimmed = newRentalItem.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            store.customRentalItems.append(trimmed)
                            store.saveCustomItems()
                            newRentalItem = ""
                        }
                        .buttonStyle(.plain)  // ← 追加
                        .disabled(newRentalItem.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(Color(hex: "1D9E75"))
                    }
                } header: {
                    Text("レンタル品追加")
                } footer: {
                    Text("追加したレンタル品は入館登録画面に表示されます")
                }
                .alert("削除しますか？", isPresented: $showDeleteRentalAlert) {
                    Button("削除", role: .destructive) {
                        store.customRentalItems.removeAll { $0 == deleteTarget }
                        store.saveCustomItems()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("「\(deleteTarget)」を削除します")
                }
                
                // 割引追加
                Section {
                    // 既存のカスタムレンタル品一覧
                    ForEach(store.customDiscounts, id: \.self) { discount in
                        HStack {
                            Text(discount)
                            Spacer()
                            Button {
                                deleteTarget = discount
                                showDeleteDiscountAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)  // ← 追加
                        }
                    }
                    
                    // 新規追加
                    HStack {
                        TextField("新しい割引名", text: $newDiscount)
                        Button("追加") {
                            let trimmed = newDiscount.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            store.customDiscounts.append(trimmed)
                            store.saveCustomItems()
                            newDiscount = ""
                        }
                        .buttonStyle(.plain)  // ← 追加
                        .disabled(newDiscount.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(Color(hex: "1D9E75"))
                    }
                } header: {
                    Text("割引追加")
                } footer: {
                    Text("追加した割引は入館登録画面に表示されます")
                }
                .alert("削除しますか？", isPresented: $showDeleteDiscountAlert) {
                    Button("削除", role: .destructive) {
                        store.customDiscounts.removeAll { $0 == deleteTarget }
                        store.saveCustomItems()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("「\(deleteTarget)」を削除します")
                }
                
                // MARK: - アロマリスト管理
                Section {
                    ForEach(store.aromaList, id: \.self) { aroma in
                        HStack {
                            Text(aroma)
                            Spacer()
                            Button {
                                deleteTarget = aroma
                                showDeleteAromaAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("新しいアロマ", text: $newAroma)
                        Button {
                            let trimmed = newAroma.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                store.aromaList.append(trimmed)
                                store.saveAromaList()
                                newAroma = ""
                            }
                        } label: {
                            Text("追加")
                        }
                        .buttonStyle(.plain)
                        .disabled(newAroma.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(Color(hex: "1D9E75"))
                    }
                } header: {
                    Text("アロマリスト")
                }
                .alert("削除しますか？", isPresented: $showDeleteAromaAlert) {
                    Button("削除", role: .destructive) {
                        store.aromaList.removeAll { $0 == deleteTarget }
                        store.saveAromaList()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("「\(deleteTarget)」を削除します")
                }
                
                // MARK: - サービスリスト管理
                Section {
                    ForEach(store.serviceList, id: \.self) { service in
                        HStack {
                            Text(service)
                            Spacer()
                            Button {
                                deleteTarget = service
                                showDeleteServiceAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("新しいサービス名", text: $newService)
                        Button {
                            let trimmed = newService.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                store.serviceList.append(trimmed)
                                store.saveServiceList()
                                newService = ""
                            }
                        } label: {
                            Text("追加")
                        }
                        .buttonStyle(.plain)
                        .disabled(newService.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(Color(hex: "1D9E75"))
                    }
                } header: {
                    Text("サービスリスト")
                }
                .alert("削除しますか？", isPresented: $showDeleteServiceAlert) {
                    Button("削除", role: .destructive) {
                        store.serviceList.removeAll { $0 == deleteTarget }
                        store.saveServiceList()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("「\(deleteTarget)」を削除します")
                }
                
            }
            .alert("保存しました", isPresented: $showSavedAlert) {
                Button("OK") {}
            } message: {
                Text("本日の設定をスプレッドシートに送信しました。")
            }
            .navigationTitle("設定")
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

