//
//  CheckOutView.swift
//  SaunaManager
//
//  Created on 2026/05/03.
//

import SwiftUI

struct CheckOutView: View {
    @EnvironmentObject var store: GuestStore
    let guest: GuestRecord

    @Environment(\.dismiss) var dismiss
    @State private var checkOutTime: Date = Date()
    @State private var additionalNote: String = ""
    @State private var showConfirmation: Bool = false
    @State private var showTimePicker: Bool = false
    @State private var checkedOutRecord: GuestRecord? = nil

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    // 滞在時間（分）
    // checkInTime は日付部分が基準日（2001/1/1）に固定されて保存されるため、
    // 時刻（時分秒）のみを比較する。日をまたいだ退館（深夜営業）にも対応。
    private var stayMinutes: Int {
        let calendar = Calendar.current

        let inTotalSeconds = calendar.component(.hour, from: guest.checkInTime) * 3600
            + calendar.component(.minute, from: guest.checkInTime) * 60
            + calendar.component(.second, from: guest.checkInTime)

        var outTotalSeconds = calendar.component(.hour, from: checkOutTime) * 3600
            + calendar.component(.minute, from: checkOutTime) * 60
            + calendar.component(.second, from: checkOutTime)

        if outTotalSeconds < inTotalSeconds {
            outTotalSeconds += 24 * 3600
        }

        return (outTotalSeconds - inTotalSeconds) / 60
    }

    private var stayText: String {
        "\(stayMinutes / 60)時間\(stayMinutes % 60)分"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // 退館時刻
                    VStack(spacing: 4) {
                        Text(formatter.string(from: checkOutTime))
                            .font(.system(size: 52, weight: .light, design: .rounded))
                            .foregroundColor(.primary)
                        Text("退館時刻")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    Divider()

                    // 利用内容の確認
                    SectionHeader(title: "利用内容の確認")
                    VStack(alignment: .leading, spacing: 6) {
                        CheckOutInfoRow(label: "ロッカー", value: "\(guest.lockerNumber)")
                        CheckOutInfoRow(label: "プラン", value: guest.displayPlanName)
                        CheckOutInfoRow(
                            label: "水着レンタル",
                            value: guest.swimwearRental ? "あり" : "なし"
                        )
                        if !guest.rentalItems.isEmpty {
                            CheckOutInfoRow(
                                label: "レンタル品",
                                value: guest.rentalItems.joined(separator: "・")
                            )
                        }
                        if !guest.discounts.isEmpty {
                            CheckOutInfoRow(
                                label: "割引",
                                value: guest.discounts.joined(separator: "・")
                            )
                        }
                        CheckOutInfoRow(
                            label: "入館時刻",
                            value: formatter.string(from: guest.checkInTime)
                        )
                        if !guest.memo.isEmpty {
                            CheckOutInfoRow(label: "メモ", value: guest.memo)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))

                    Divider()

                    // 退館時刻の手動調整
                    SectionHeader(title: "退館時刻（調整可）")
                    DatePicker(
                        "",
                        selection: $checkOutTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    
                    // 退館時刻の手動調整ver.2
                    HStack {
                        Text("退館時刻")
                        Spacer()
                        Button {
                            showTimePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                
                            }
                        }
                    }

                    Divider()

                    // 追記メモ
                    SectionHeader(title: "追記メモ（任意）")
                    TextField("延長料金・追加購入など", text: $additionalNote, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...3)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("退館処理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 退館ボタン
                    Button {
                        showConfirmation = true
                    } label: {
                        HStack(spacing: 4){
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("退館")
                        }
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white)
                            .foregroundColor(Color(hex: "E24B4A"))
                    }
                    .alert("退館を確定しますか？", isPresented: $showConfirmation) {
                        Button("キャンセル", role: .cancel) {}
                        Button("退館を記録", role: .destructive) {
                            saveCheckOut()
                        }
                    } message: {
                        Text("\(guest.lockerNumber) ・ 滞在 \(stayText)")
                    }
                }
            }
            .sheet(item: $checkedOutRecord) { record in
                CheckOutSummaryView(guest: record) {
                    checkedOutRecord = nil
                    dismiss()
                }
            }
        }
    }

    private func saveCheckOut() {
        store.checkOut(id: guest.id, time: checkOutTime)
        // 退館後のレコード（checkOutTime反映済み）を取得し、会計確認ポップアップを表示
        checkedOutRecord = store.records.first { $0.id == guest.id }
    }
}

// MARK: - サブビュー

struct CheckOutInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

