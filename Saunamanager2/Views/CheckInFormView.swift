//
//  ChekInFormView.swift
//  SaunaManager
//
//  Created on 2026/05/11.
//

import SwiftUI

struct CheckInFormView: View {
    @EnvironmentObject var store: GuestStore
    let lockerNumber: String

    @State private var isPublicHoliday: Bool = false
    @State private var activePlanCategory: PlanCategory? = nil
    @State private var morningBubbleHeight: CGFloat = 0

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

    private var autoGender: String {
        store.genderForLocker(lockerNumber)
    }

    private var formData: CheckInFormData {
        store.checkInFormData[lockerNumber] ?? CheckInFormData()
    }

    private func updateForm(_ update: (inout CheckInFormData) -> Void) {
        var data = store.checkInFormData[lockerNumber] ?? CheckInFormData()
        update(&data)
        data.gender = autoGender
        data.isHoliday = isHoliday
        store.checkInFormData[lockerNumber] = data
    }

    private var rentalItems: [String] {
        ["水着", "ハット", "マット", "ポンチョ", "砂時計"] + store.customRentalItems
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider()
                planSection
                Divider().padding(.vertical, 8)
                HStack(alignment: .top, spacing: 0) {
                    rentalSection.frame(width: 170, alignment: .leading)
                    discountSection.frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider().padding(.vertical, 8)
                HStack(alignment: .top, spacing: 0) {
                    storedItemSection.frame(width: 170, alignment: .leading)
                    cleansingPurchaseSection.frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider().padding(.vertical, 8)
                memoSection
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            updateForm { data in
                if data.plan.isEmpty {
                    if store.isMorningActive {
                        data.plan = "＋軽食"
                    } else if store.isNightActive {
                        data.plan = "ナイトサウナ"
                    } else if store.isRainyActive {
                        data.plan = "雨割"
                    } else {
                        data.plan = "通常利用"
                    }
                }
            }
            checkIfHoliday()
        }
    }

    // MARK: - サブビュー
    private var headerRow: some View {
        HStack {
            Label(lockerNumber, systemImage: "lock.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
            gender
            Spacer()
            Label(Date().formatted(date: .omitted, time: .shortened),
                  systemImage: "clock")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var gender: some View {
        Text(autoGender)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(autoGender == "男" ? .blue : .pink)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(autoGender == "男" ? Color.blue.opacity(0.15) : Color.pink.opacity(0.15))
            .clipShape(Capsule())
    }

    private func planPopoverContent(for category: PlanCategory) -> some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible()),
                           count: plans(for: category).count <= 2 ? plans(for: category).count : 2),
            spacing: 8
        ) {
            ForEach(plans(for: category), id: \.self) { plan in
                PlanCard(title: plan, isSelected: formData.plan == plan) {
                    updateForm { $0.plan = plan }
                    activePlanCategory = nil
                }
            }
        }
        .padding()
        .frame(width: 260)
        .presentationCompactAdaptation(.popover)
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "利用プラン（\(isHoliday ? "休日" : "平日")・1つ選択）")

            if store.isMorningActive {
                morningPlanRow
                    .padding(.vertical, 10)
            } else {
                standardCategoryRow
                    .padding(.vertical, 10)
            }

            if !formData.plan.isEmpty {
                Text("選択中：\(formData.plan)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 6)
            }
        }
    }

    // 朝活ON時：アイコンを小さくして上に寄せ、空いた下段にランステ・その他を配置。右側に項目の吹き出し
    private var morningPlanRow: some View {
        let iconButtonSize: CGFloat = 76
        return HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 0) {
                CategoryIconButton(
                    title: normalIconTitle,
                    icon: normalIcon,
                    isSelected: normalPlans.contains(formData.plan),
                    iconSize: normalIconSize * 0.75,
                    buttonSize: iconButtonSize
                ) {}

                Spacer(minLength: 16)

                CategoryPillButton(
                    title: "ランステ",
                    icon: .asset("Running"),
                    isSelected: runStePlans.contains(formData.plan)
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
                    isSelected: otherPlans.contains(formData.plan)
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
                    PlanCard(title: plan, isSelected: formData.plan == plan) {
                        updateForm { $0.plan = plan }
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
                isSelected: normalPlans.contains(formData.plan),
                iconSize: normalIconSize
            ) {
                if store.isNightActive {
                    updateForm { $0.plan = "ナイトサウナ" }
                } else if store.isRainyActive {
                    updateForm { $0.plan = "雨割" }
                } else {
                    updateForm { $0.plan = "通常利用" }
                }
            }
            CategoryIconButton(
                title: "ランステ",
                icon: .asset("Running"),
                isSelected: runStePlans.contains(formData.plan),
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
                isSelected: otherPlans.contains(formData.plan)
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

    private func toggleRentalItem(_ item: String) {
        updateForm {
            if $0.rentalItems.contains(item) {
                $0.rentalItems.removeAll { $0 == item }
            } else {
                $0.rentalItems.append(item)
            }
        }
    }

    private var rentalSection: some View {
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
                    isSelected: formData.rentalItems.contains("水着"),
                    style: .green,
                    isLarge: true
                ) {
                    toggleRentalItem("水着")
                }
                FlowLayout(spacing: 8) {
                    ForEach(rentalItems.filter { $0 != "水着" }, id: \.self) { item in
                        ChipButton(
                            title: item,
                            isSelected: formData.rentalItems.contains(item),
                            style: .green
                        ) {
                            toggleRentalItem(item)
                        }
                    }
                }
            }
            .padding(.leading, 16)
        }
    }

    private var discountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("割引")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.top, 8)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                discountRow(baseDiscounts)
                discountRow(lineDiscounts)
                discountRow(tomodachiDiscounts)
            }
            .padding(.leading, 4)
            .padding(.trailing)
        }
    }

    private func discountRow(_ items: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { discount in
                ChipButton(
                    title: discount,
                    isSelected: formData.discounts.contains(discount),
                    style: .green
                ) {
                    updateForm {
                        if $0.discounts.contains(discount) {
                            $0.discounts.removeAll { $0 == discount }
                        } else {
                            $0.discounts.append(discount)
                        }
                    }
                }
            }
        }
    }

    private var storedItemSection: some View {
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
                        isSelected: formData.storedItems.contains(item),
                        style: .green
                    ) {
                        updateForm {
                            if $0.storedItems.contains(item) {
                                $0.storedItems.removeAll { $0 == item }
                            } else {
                                $0.storedItems.append(item)
                            }
                        }
                    }
                }
            }
            .padding(.leading, 16)
        }
    }

    private var cleansingPurchaseSection: some View {
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
                    isSelected: formData.cleansingPurchased,
                    style: .green
                ) {
                    updateForm { $0.cleansingPurchased.toggle() }
                }
            }
            .padding(.leading, 4)
            .padding(.trailing)
        }
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("備考", text: Binding(
                get: { formData.memo },
                set: { val in updateForm { $0.memo = val } }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
            .submitLabel(.return)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - 祝日チェック

    private func checkIfHoliday() {
        Task {
            let isHoliday = await GuestStore.isPublicHolidayToday()
            await MainActor.run { isPublicHoliday = isHoliday }
        }
    }
}

