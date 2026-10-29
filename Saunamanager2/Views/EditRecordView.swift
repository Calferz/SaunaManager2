//
//  EditRecordView.swift
//  SaunaManager
//
//  Created on 2026/06/25.
//

// Views/EditRecordView.swift
import SwiftUI

struct EditRecordView: View {
    @EnvironmentObject var store: GuestStore
    @Environment(\.dismiss) var dismiss

    @State var record: GuestRecord
    
    // ロッカー番号の選択肢（北：1〜25の13を除く全番号、南：1〜27の全番号）
    let northLockers = (1...25).filter { $0 != 13 }
        .map { String(format: "N%03d", $0) }
    let southLockers = Array(1...27)
        .map { String(format: "S%03d", $0) }
    var allLockers: [String] { northLockers + southLockers }

    @State private var showCheckInTimePicker: Bool = false
    @State private var showCheckOutTimePicker: Bool = false
    @State private var showSaunaStartTimePicker: Bool = false
    @State private var showLockerPicker: Bool = false

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var rentalItems: [String] {
        ["水着", "ポンチョ", "サウナマット", "サウナハット", "砂時計"] + store.customRentalItems
    }

    private var discounts: [String] {
        var list = ["リロクラブ", "優待券", "LINE水着", "LINEポンチョ", "LINEハット", "LINEマット", "トモダチ割"]
        list += store.customDiscounts
        return list
    }

    // 割引欄の行分け（1行目：基本、2行目：LINE系統、3行目：トモダチ割）
    private var baseDiscounts: [String] {
        discounts.filter { !$0.hasPrefix("LINE") && $0 != "トモダチ割" }
    }
    private var lineDiscounts: [String] {
        discounts.filter { $0.hasPrefix("LINE") }
    }
    private var tomodachiDiscounts: [String] {
        discounts.filter { $0 == "トモダチ割" }
    }

    private var storedItemOptions: [String] {
        ["傘", "荷物"]
    }

    private var plans: [String] {
        let base = [
            "30分", "60分", "90分", "120分", "150分", "無制限",
            "LINE", "優待券", "雨割", "ランステ", "シャワー", "再入館",
            "朝活パック", "朝活ポンチョ", "朝活軽食", "ナイトサウナ"
        ]
        return base + store.customPlans
    }
    
    let originalLockerNumber: String
    let originalCheckInTime: String

    init(record: GuestRecord) {
        _record = State(initialValue: record)
        self.originalLockerNumber = record.lockerNumber
        self.originalCheckInTime = record.checkInTimeString
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ロッカー番号
                    SectionHeader(title: "ロッカー番号")
                    Button {
                        showLockerPicker = true
                    } label: {
                        HStack {
                            Text(record.lockerNumber)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .sheet(isPresented: $showLockerPicker) {
                        NavigationView {
                            Picker("ロッカー番号", selection: $record.lockerNumber) {
                                ForEach(allLockers, id: \.self) { locker in
                                    Text(locker).tag(locker)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: record.lockerNumber) {
                                record.gender = store.genderForLocker(record.lockerNumber)
                            }
                            .navigationTitle("ロッカー番号を選択")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完了") {
                                        showLockerPicker = false
                                    }
                                    .foregroundColor(Color(hex: "1D9E75"))
                                }
                            }
                        }
                        .presentationDetents([.height(300)])
                    }

                    Divider()

                    // 性別
                    SectionHeader(title: "性別")
                    HStack(spacing: 8) {
                        ForEach(["男", "女"], id: \.self) { gender in
                            Button {
                                record.gender = gender
                            } label: {
                                Text(gender)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 52, height: 32)
                                    .background(record.gender == gender
                                        ? (gender == "男" ? Color.blue.opacity(0.15) : Color.pink.opacity(0.15))
                                        : Color(.systemBackground))
                                    .foregroundColor(record.gender == gender
                                        ? (gender == "男" ? .blue : .pink)
                                        : .secondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(record.gender == gender
                                                ? (gender == "男" ? Color.blue : Color.pink)
                                                : Color(.systemGray4),
                                                lineWidth: 0.5)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Divider()

                    // 入館時刻
                    SectionHeader(title: "入館時刻")
                    Button {
                        showCheckInTimePicker = true
                    } label: {
                        HStack {
                            Text(timeFormatter.string(from: record.checkInTime))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .sheet(isPresented: $showCheckInTimePicker) {
                        NavigationView {
                            DatePicker(
                                "",
                                selection: $record.checkInTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .navigationTitle("入館時刻を変更")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完了") { showCheckInTimePicker = false }
                                        .foregroundColor(Color(hex: "1D9E75"))
                                }
                            }
                        }
                        .presentationDetents([.height(300)])
                    }

                    Divider()

                    // 退館時刻
                    SectionHeader(title: "退館時刻")
                    Button {
                        showCheckOutTimePicker = true
                    } label: {
                        HStack {
                            Text(record.checkOutTime.map { timeFormatter.string(from: $0) } ?? "未退館")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .sheet(isPresented: $showCheckOutTimePicker) {
                        NavigationView {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { record.checkOutTime ?? Date() },
                                    set: { record.checkOutTime = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .navigationTitle("退館時刻を変更")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完了") { showCheckOutTimePicker = false }
                                        .foregroundColor(Color(hex: "1D9E75"))
                                }
                            }
                        }
                        .presentationDetents([.height(300)])
                    }

                    // サウナ利用開始時刻（「ランステ＋通常利用」のみ）
                    saunaStartSection

                    Divider()

                    // プラン
                    SectionHeader(title: "利用プラン")
                    LazyVGrid(
                        columns: Array(repeating: .init(.flexible()),
                                       count: plans.count <= 4 ? plans.count : 3),
                        spacing: 8
                    ) {
                        ForEach(plans, id: \.self) { plan in
                            PlanCard(title: plan, isSelected: record.plan == plan) {
                                record.plan = plan
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.vertical, 8)

                    // レンタル品（水着も含む）
                    SectionHeader(title: "レンタル品")
                    FlowLayout(spacing: 8) {
                        ForEach(rentalItems, id: \.self) { item in
                            ChipButton(
                                title: item,
                                isSelected: record.rentalItems.contains(item),
                                style: .green,
                                isLarge: item == "水着"
                            ) {
                                if record.rentalItems.contains(item) {
                                    record.rentalItems.removeAll { $0 == item }
                                } else {
                                    record.rentalItems.append(item)
                                }
                                if item == "水着" {
                                    record.swimwearRental = record.rentalItems.contains("水着")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.vertical, 8)

                    // 割引
                    SectionHeader(title: "割引")
                    VStack(alignment: .leading, spacing: 8) {
                        editDiscountRow(baseDiscounts)
                        editDiscountRow(lineDiscounts)
                        editDiscountRow(tomodachiDiscounts)
                    }
                    .padding(.horizontal)

                    Divider().padding(.vertical, 8)

                    // 荷物預かり
                    SectionHeader(title: "荷物預かり")
                    FlowLayout(spacing: 8) {
                        ForEach(storedItemOptions, id: \.self) { item in
                            ChipButton(
                                title: item,
                                isSelected: record.storedItems.contains(item),
                                style: .green
                            ) {
                                if record.storedItems.contains(item) {
                                    record.storedItems.removeAll { $0 == item }
                                } else {
                                    record.storedItems.append(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.vertical, 8)

                    // クレンジング購入
                    SectionHeader(title: "購入")
                    FlowLayout(spacing: 8) {
                        ChipButton(
                            title: "クレンジング",
                            isSelected: record.cleansingPurchased,
                            style: .green
                        ) {
                            record.cleansingPurchased.toggle()
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.vertical, 8)

                    // メモ
                    TextField("備考", text: $record.memo, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .submitLabel(.return)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.updateRecord(
                                record,
                                originalLockerNumber: originalLockerNumber,
                                originalCheckInTime: originalCheckInTime
                            )
                        dismiss()
                    } label: {
                        HStack(spacing: 4){
                            Image(systemName: "arrow.clockwise")
                            Text("更新")
                        }
                            .font(.caption)
                            .foregroundColor(Color(hex: "1D9E75"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                }
            }
            .sheet(isPresented: $showSaunaStartTimePicker) {
                NavigationView {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { record.saunaStartTime ?? Date() },
                            set: { record.saunaStartTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .navigationTitle("サウナ利用開始時刻を変更")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完了") { showSaunaStartTimePicker = false }
                                .foregroundColor(Color(hex: "1D9E75"))
                        }
                    }
                }
                .presentationDetents([.height(300)])
            }
        }
    }

    private func editDiscountRow(_ items: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                ChipButton(
                    title: item,
                    isSelected: record.discounts.contains(item),
                    style: item == "トモダチ割" ? .purple : .warning
                ) {
                    if record.discounts.contains(item) {
                        record.discounts.removeAll { $0 == item }
                    } else {
                        record.discounts.append(item)
                    }
                }
            }
        }
    }

    // サウナ利用開始時刻欄（「ランステ＋通常利用」のみ表示）。
    // 未開始なら開始ボタン、開始済みならタップで時刻を修正できる。
    @ViewBuilder
    private var saunaStartSection: some View {
        if record.plan == "ランステ＋通常利用" {
            Divider()

            SectionHeader(title: "サウナ利用開始時刻")
            if record.saunaStartTime != nil {
                Button {
                    showSaunaStartTimePicker = true
                } label: {
                    HStack {
                        Text(timeFormatter.string(from: record.saunaStartTime!))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            } else {
                Button {
                    record.saunaStartTime = Date()
                } label: {
                    HStack {
                        Image(systemName: "flame")
                        Text("サウナ利用を開始する（未開始）")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "1D9E75"))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

