//
//  ManualCheckInView.swift
//  SaunaManager
//
//  Created on 2026/05/04.
//

import SwiftUI

struct ManualCheckInView: View {
    @EnvironmentObject var store: GuestStore
    @Environment(\.dismiss) var dismiss

    // ロッカー番号の選択肢（北：1〜25の13を除く全番号、南：1〜27の全番号）
    let northLockers = (1...25).filter { $0 != 13 }
        .map { String(format: "N%03d", $0) }
    let southLockers = Array(1...27)
        .map { String(format: "S%03d", $0) }
    var allLockers: [String] { northLockers + southLockers }

    // 在館中（使用中）のロッカー番号は選択肢から除外する
    private var activeLockerNumbers: Set<String> {
        Set(store.activeGuests.map { $0.lockerNumber })
    }
    private var availableLockers: [String] {
        allLockers.filter { !activeLockerNumbers.contains($0) }
    }

    // 曜日判定
    private var dayType: DayType {
        let weekday = Calendar.current.component(.weekday, from: Date())
        if weekday == 1 { return .holiday }
        if weekday == 7 { return .saturday }
        if isPublicHoliday { return .holiday }
        return .weekday
    }

    private var isHoliday: Bool {
        dayType == .saturday || dayType == .holiday
    }

    // 入力状態
    @State private var selectedLocker: String = "N001"
    @State private var manualGender: String = ""
    @State private var selectedPlan: String = ""
    @State private var selectedRentals: Set<String> = []
    @State private var selectedDiscounts: Set<String> = []
    @State private var selectedStoredItems: Set<String> = []
    @State private var cleansingPurchased: Bool = false
    @State private var memo: String = ""
    @State private var isPublicHoliday: Bool = false
    @State private var checkInTime: Date = Date()
    @State private var showTimePicker: Bool = false
    @State private var showLockerPicker: Bool = false
    @State private var showDuplicateLockerAlert: Bool = false
    @State private var activePlanCategory: PlanCategory? = nil
    @State private var morningBubbleHeight: CGFloat = 0

    private var rentalItems: [String] {
        let base = ["水着", "ハット", "マット", "ポンチョ", "砂時計"]
        return base + store.customRentalItems
    }

    private var autoGender: String {
        store.genderForLocker(selectedLocker)
    }

    // 最終的な性別（手動上書きがあればそちらを優先）
    private var resolvedGender: String {
        manualGender.isEmpty ? autoGender : manualGender
    }

    private var normalPlans: [String] {
        if store.isMorningActive {
            return ["＋軽食", "＋ポンチョ", "＋パック", "＋ステッカー", "通常利用"]
        }
        if store.isNightActive {
            return ["ナイトサウナ"]
        }
        if store.isRainyActive {
            return ["雨割"]
        }
        return ["通常利用"]
    }

    private var runStePlans: [String] {
        ["ランステ", "シャワーのみ", "ランステ＋通常利用"]
    }

    private var otherPlans: [String] {
        ["LINE", "優待券", "再入館"] + store.customPlans
    }

    private func plans(for category: PlanCategory) -> [String] {
        switch category {
        case .normal: return normalPlans
        case .runSte: return runStePlans
        case .other:  return otherPlans
        }
    }

    // 通常利用アイコンの切り替え（朝活／ナイトサウナ／雨割トグルがONの場合）
    private var normalIconTitle: String {
        if store.isMorningActive { return "朝活" }
        if store.isNightActive { return "ナイトサウナ" }
        if store.isRainyActive { return "雨割" }
        return "通常利用"
    }

    private var normalIcon: CategoryIcon {
        if store.isMorningActive { return .system("sun.max.fill") }
        if store.isNightActive { return .system("moon.stars.fill") }
        if store.isRainyActive { return .system("umbrella.fill") }
        return .asset("standard")
    }

    private var normalIconSize: CGFloat {
        if store.isMorningActive { return 34 }
        if store.isNightActive { return 40 }
        if store.isRainyActive { return 38 }
        return 52
    }

    private var discounts: [String] {
        var list = ["リロクラブ", "優待券", "学割", "LINE水着", "LINEポンチョ", "LINEハット", "LINEマット"]
        if dayType == .saturday { list.append("トモダチ割") }
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

    private func planPopoverContent(for category: PlanCategory) -> some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible()),
                           count: plans(for: category).count <= 2 ? plans(for: category).count : 2),
            spacing: 8
        ) {
            ForEach(plans(for: category), id: \.self) { plan in
                PlanCard(title: plan, isSelected: selectedPlan == plan) {
                    selectedPlan = plan
                    activePlanCategory = nil
                }
            }
        }
        .padding()
        .frame(width: 260)
        .presentationCompactAdaptation(.popover)
    }

    // 朝活ON時：通常利用アイコンの右側に項目を常時表示する吹き出し
    // 朝活ON時：アイコンを小さくして上に寄せ、空いた下段にランステ・その他を配置。右側に項目の吹き出し
    private var morningPlanRow: some View {
        let iconButtonSize: CGFloat = 76
        return HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 0) {
                CategoryIconButton(
                    title: normalIconTitle,
                    icon: normalIcon,
                    isSelected: normalPlans.contains(selectedPlan),
                    iconSize: normalIconSize * 0.75,
                    buttonSize: iconButtonSize
                ) {}

                Spacer(minLength: 16)

                CategoryPillButton(
                    title: "ランステ",
                    icon: .asset("Running"),
                    isSelected: runStePlans.contains(selectedPlan)
                ) {
                    activePlanCategory = .runSte
                }
                .popover(isPresented: Binding(
                    get: { activePlanCategory == .runSte },
                    set: { if !$0 { activePlanCategory = nil } }
                ), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    planPopoverContent(for: .runSte)
                }

                Spacer().frame(height: 14)

                CategoryPillButton(
                    title: "その他",
                    icon: .dots,
                    isSelected: otherPlans.contains(selectedPlan)
                ) {
                    activePlanCategory = .other
                }
                .popover(isPresented: Binding(
                    get: { activePlanCategory == .other },
                    set: { if !$0 { activePlanCategory = nil } }
                ), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    planPopoverContent(for: .other)
                }
            }
            .frame(width: 100, height: morningBubbleHeight > 0 ? morningBubbleHeight : nil)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(normalPlans, id: \.self) { plan in
                    PlanCard(title: plan, isSelected: selectedPlan == plan) {
                        selectedPlan = plan
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)
            .padding(.leading, 24)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    SpeechBubbleShape(arrowY: iconButtonSize / 2)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
                        .preference(key: BubbleHeightKey.self, value: geo.size.height)
                }
            )
        }
        .padding(.horizontal)
        .onPreferenceChange(BubbleHeightKey.self) { morningBubbleHeight = $0 }
    }

    // 朝活OFF時：従来の3アイコン横並び（タップでポップアップ）
    private var standardCategoryRow: some View {
        HStack(spacing: 12) {
            CategoryIconButton(
                title: normalIconTitle,
                icon: normalIcon,
                isSelected: normalPlans.contains(selectedPlan),
                iconSize: normalIconSize
            ) {
                if store.isNightActive {
                    selectedPlan = "ナイトサウナ"
                } else if store.isRainyActive {
                    selectedPlan = "雨割"
                } else {
                    selectedPlan = "通常利用"
                }
            }
            CategoryIconButton(
                title: "ランステ",
                icon: .asset("Running"),
                isSelected: runStePlans.contains(selectedPlan),
                iconSize: 52
            ) {
                activePlanCategory = .runSte
            }
            .popover(isPresented: Binding(
                get: { activePlanCategory == .runSte },
                set: { if !$0 { activePlanCategory = nil } }
            ), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                planPopoverContent(for: .runSte)
            }
            CategoryIconButton(
                title: "その他",
                icon: .dots,
                isSelected: otherPlans.contains(selectedPlan)
            ) {
                activePlanCategory = .other
            }
            .popover(isPresented: Binding(
                get: { activePlanCategory == .other },
                set: { if !$0 { activePlanCategory = nil } }
            ), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                planPopoverContent(for: .other)
            }
        }
        .padding(.horizontal)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // 入館時刻（タップで変更可能）
                    HStack {
                        Label("入館時刻", systemImage: "clock")
                        Spacer()
                        Button {
                            showTimePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(timeString(from: checkInTime))
                            }
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "1D9E75"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "1D9E75").opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .sheet(isPresented: $showTimePicker) {
                        NavigationView {
                            DatePicker(
                                "",
                                selection: $checkInTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                            .navigationTitle("入館時刻を選択")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("完了") {
                                        showTimePicker = false
                                    }
                                    .foregroundColor(Color(hex: "1D9E75"))
                                }
                            }
                        }
                        .presentationDetents([.height(300)])
                    }

                    Divider()

                    // ロッカー番号（タップでホイール表示）＋ 性別（自動判別）
                    HStack(spacing: 12) {
                        Label("ロッカー番号", systemImage: "lock.fill")
                        Spacer()
                        Text("\(autoGender)")
                            .foregroundColor(autoGender == "男" ? Color(hex: "007AFF") : Color(hex: "FF4D4D"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(autoGender == "男" ? Color(hex: "007AFF").opacity(0.12) : Color(hex: "FF4D4D").opacity(0.12))
                            .clipShape(Capsule())
                        Button {
                            showLockerPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedLocker)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .sheet(isPresented: $showLockerPicker) {
                        NavigationView {
                            Picker("ロッカー番号", selection: $selectedLocker) {
                                ForEach(availableLockers, id: \.self) { locker in
                                    Text(locker).tag(locker)
                                }
                            }
                            .pickerStyle(.wheel)
                            .onChange(of: selectedLocker) {
                                // ロッカー変更時に手動性別をリセット
                                manualGender = ""
                                selectedPlan = ""
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

                    // 利用プラン
                    SectionHeader(title: "利用プラン（\(isHoliday ? "休日" : "平日")・1つ選択）")
                    if store.isMorningActive {
                        morningPlanRow
                            .padding(.vertical, 10)
                    } else {
                        standardCategoryRow
                            .padding(.vertical, 10)
                    }

                    if !selectedPlan.isEmpty {
                        Text("選択中：\(selectedPlan)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 6)
                    }

                    Divider().padding(.vertical, 8)

                    // レンタル品・割引
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("レンタル品")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            VStack(alignment: .leading, spacing: 8) {
                                ChipButton(
                                    title: "水着",
                                    isSelected: selectedRentals.contains("水着"),
                                    style: .green,
                                    isLarge: true
                                ) {
                                    if selectedRentals.contains("水着") {
                                        selectedRentals.remove("水着")
                                    } else {
                                        selectedRentals.insert("水着")
                                    }
                                }
                                FlowLayout(spacing: 8) {
                                    ForEach(rentalItems.filter { $0 != "水着" }, id: \.self) { item in
                                        ChipButton(
                                            title: item,
                                            isSelected: selectedRentals.contains(item),
                                            style: .green
                                        ) {
                                            if selectedRentals.contains(item) {
                                                selectedRentals.remove(item)
                                            } else {
                                                selectedRentals.insert(item)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 16)
                        }
                        .frame(width: 170, alignment: .leading)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("割引")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            VStack(alignment: .leading, spacing: 8) {
                                manualDiscountRow(baseDiscounts)
                                manualDiscountRow(lineDiscounts)
                                manualDiscountRow(tomodachiDiscounts)
                            }
                            .padding(.leading, 4)
                            .padding(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider().padding(.vertical, 8)

                    // 荷物預かり・クレンジング購入
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("荷物預かり")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            FlowLayout(spacing: 8) {
                                ForEach(storedItemOptions, id: \.self) { item in
                                    ChipButton(
                                        title: item,
                                        isSelected: selectedStoredItems.contains(item),
                                        style: .green
                                    ) {
                                        if selectedStoredItems.contains(item) {
                                            selectedStoredItems.remove(item)
                                        } else {
                                            selectedStoredItems.insert(item)
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 16)
                        }
                        .frame(width: 170, alignment: .leading)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("購入")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            FlowLayout(spacing: 8) {
                                ChipButton(
                                    title: "クレンジング",
                                    isSelected: cleansingPurchased,
                                    style: .green
                                ) {
                                    cleansingPurchased.toggle()
                                }
                            }
                            .padding(.leading, 4)
                            .padding(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider().padding(.vertical, 8)

                    // メモ
                    TextField("備考", text: $memo, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .submitLabel(.return)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("入館登録")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 保存ボタン
                    Button {
                        saveRecord()
                    } label: {
                        HStack(spacing: 4){
                            Image(systemName: "paperplane")
                            Text("保存")
                        }
                            .foregroundColor(selectedPlan.isEmpty ? Color.gray : Color(hex: "1D9E75"))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .disabled(selectedPlan.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("このロッカーはすでに在館中です", isPresented: $showDuplicateLockerAlert) {
                Button("OK") {
                    if let firstAvailable = availableLockers.first {
                        selectedLocker = firstAvailable
                    }
                }
            } message: {
                Text("別のロッカー番号を選び直してください。")
            }
            .onAppear {
                checkIfHoliday()
                // 初期選択のロッカーが在館中で使用できない場合は、空いている番号に差し替える
                if activeLockerNumbers.contains(selectedLocker), let firstAvailable = availableLockers.first {
                    selectedLocker = firstAvailable
                }
                if selectedPlan.isEmpty {
                    if store.isMorningActive {
                        selectedPlan = "＋軽食"
                    } else if store.isNightActive {
                        selectedPlan = "ナイトサウナ"
                    } else if store.isRainyActive {
                        selectedPlan = "雨割"
                    } else {
                        selectedPlan = "通常利用"
                    }
                }
            }
        }
    }
    
    private func manualDiscountRow(_ items: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { discount in
                ChipButton(
                    title: discount,
                    isSelected: selectedDiscounts.contains(discount),
                    style: .green
                ) {
                    if selectedDiscounts.contains(discount) {
                        selectedDiscounts.remove(discount)
                    } else {
                        selectedDiscounts.insert(discount)
                    }
                }
            }
        }
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func saveRecord() {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let dateOnly = calendar.startOfDay(for: now)

        // 手動設定した時刻を使用
        let timeOnly = calendar.date(
            bySettingHour: calendar.component(.hour, from: checkInTime),
            minute: calendar.component(.minute, from: checkInTime),
            second: calendar.component(.second, from: checkInTime),
            of: Date(timeIntervalSinceReferenceDate: 0)
        ) ?? checkInTime

        let record = GuestRecord(
            lockerNumber: selectedLocker,
            date: dateOnly,
            checkInTime: timeOnly,
            plan: selectedPlan,
            gender: resolvedGender,
            swimwearRental: selectedRentals.contains("水着"),
            rentalItems: Array(selectedRentals),
            discounts: Array(selectedDiscounts),
            storedItems: Array(selectedStoredItems),
            cleansingPurchased: cleansingPurchased,
            memo: memo,
            isHoliday: isHoliday
        )
        if store.addRecord(record) {
            dismiss()
        } else {
            // すでに在館中のロッカーだった場合（他の端末等での操作と競合した場合）は保存せず、選び直してもらう
            showDuplicateLockerAlert = true
        }
    }
    
    private func checkIfHoliday() {
        Task {
            let isHoliday = await GuestStore.isPublicHolidayToday()
            await MainActor.run { isPublicHoliday = isHoliday }
        }
    }
}

