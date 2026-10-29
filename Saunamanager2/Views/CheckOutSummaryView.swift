//
//  CheckOutSummaryView.swift
//  SaunaManager
//
//  Created on 2026/08/13.
//

import SwiftUI

// 退館スキャン時の会計確認ポップアップ（後払い用・確認表示のみ）
struct CheckOutSummaryView: View {
    let guest: GuestRecord
    var onConfirm: () -> Void

    @State private var showRentalReminder: Bool = false

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var stayText: String {
        let minutes = guest.stayDuration ?? 0
        return "\(minutes / 60)時間\(minutes % 60)分"
    }

    // 水着以外のレンタル品（回収確認用）
    private var nonSwimwearRentalItems: [String] {
        guest.rentalItems.filter { $0 != "水着" }
    }

    // 砂時計をレンタルしているか
    private var hasSandTimer: Bool {
        guest.rentalItems.contains("砂時計")
    }

    // 傘を預かっているか
    private var hasUmbrella: Bool {
        guest.storedItems.contains("傘")
    }

    // 荷物を預かっているか
    private var hasLuggage: Bool {
        guest.storedItems.contains("荷物")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ロッカー番号・滞在時間
                    VStack(spacing: 4) {
                        Text(guest.lockerNumber)
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                        Text("退館 ・ 滞在 \(stayText)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                    Divider()

                    if guest.isMorningMeal {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("朝活軽食をお渡ししてください")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        Divider()
                    }

                    if hasSandTimer {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("砂時計を回収してください")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        Divider()
                    }

                    if hasUmbrella {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("傘をお返しください")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        Divider()
                    }

                    if hasLuggage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("荷物をお返しください")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        Divider()
                    }

                    SectionHeader(title: "会計内容（後払い）")
                    VStack(alignment: .leading, spacing: 10) {
                        CheckOutSummaryRow(label: "プラン", value: guest.checkoutPlanDisplayName, valueColor: .primary)
                        CheckOutRentalRow(items: guest.checkoutRentalItemsBilling)
                        CheckOutSummaryRow(
                            label: "割引",
                            value: guest.discounts.isEmpty ? "なし" : guest.discounts.joined(separator: "・"),
                            valueColor: .secondary
                        )
                        CheckOutSummaryRow(
                            label: "荷物預かり",
                            value: guest.storedItems.isEmpty ? "なし" : guest.storedItems.joined(separator: "・"),
                            valueColor: guest.storedItems.isEmpty ? .secondary : .primary
                        )
                        CheckOutSummaryRow(
                            label: "購入",
                            value: guest.cleansingPurchased ? "あり" : "なし",
                            valueColor: guest.cleansingPurchased ? .primary : .secondary
                        )
                        CheckOutSummaryRow(
                            label: "入館時刻",
                            value: timeFormatter.string(from: guest.checkInTime)
                        )
                        CheckOutSummaryRow(
                            label: "退館時刻",
                            value: guest.checkOutTime.map { timeFormatter.string(from: $0) } ?? "-"
                        )
                        if !guest.memo.isEmpty {
                            CheckOutSummaryRow(label: "メモ", value: guest.memo)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("退館・会計確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確認") { onConfirm() }
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "1D9E75"))
                }
            }
        }
        .onAppear {
            showRentalReminder = !nonSwimwearRentalItems.isEmpty
        }
        .alert("レンタル品の回収確認", isPresented: $showRentalReminder) {
            Button("確認") {}
        } message: {
            Text(nonSwimwearRentalItems.joined(separator: "・"))
        }
    }
}

// MARK: - サブビュー（会計内容の行・やや大きめの文字サイズ）
struct CheckOutSummaryRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .fontWeight(valueColor == .primary ? .bold : .medium)
                .foregroundColor(valueColor)
            Spacer()
        }
    }
}

// MARK: - サブビュー（レンタル品の行・課金対象は黒太字、無課金はグレーで表示）
struct CheckOutRentalRow: View {
    let items: [(text: String, isBillable: Bool)]

    var body: some View {
        HStack(alignment: .top) {
            Text("レンタル")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            composedValue
                .font(.subheadline)
            Spacer()
        }
    }

    private var composedValue: Text {
        guard !items.isEmpty else {
            return Text("なし").foregroundColor(.primary).fontWeight(.bold)
        }
        var result = AttributedString()
        for (index, item) in items.enumerated() {
            if index > 0 {
                var separator = AttributedString("・")
                separator.foregroundColor = .secondary
                separator.font = .subheadline.weight(.medium)
                result += separator
            }
            var itemAttr = AttributedString(item.text)
            itemAttr.foregroundColor = item.isBillable ? .primary : .secondary
            itemAttr.font = item.isBillable ? .subheadline.bold() : .subheadline.weight(.medium)
            result += itemAttr
        }
        return Text(result)
    }
}
