// Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: GuestStore
    @State private var selectedDate: Date = Date()
    @State private var editingRecord: GuestRecord? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var recordsForSelectedDate: [GuestRecord] {
        let calendar = Calendar.current
        return store.records
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.checkInTime < $1.checkInTime }
    }

    private var summary: Summary {
        let records = recordsForSelectedDate
        let total = records.count
        let male = records.filter { $0.gender == "男" }.count
        let female = records.filter { $0.gender == "女" }.count
        let swimwear = records.filter { $0.swimwearRental }.count
        let discounted = records.filter { !$0.discounts.isEmpty && $0.discounts != ["なし"] }.count
        return Summary(
            total: total,
            male: male,
            female: female,
            swimwear: swimwear,
            discounted: discounted
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if recordsForSelectedDate.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("この日の記録はありません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            SummaryCardView(summary: summary)
                        } header: {
                            Text("集計")
                        }

                        Section {
                            ForEach(recordsForSelectedDate) { record in
                                HistoryRowView(record: record, formatter: dateFormatter)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingRecord = record
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            store.deleteRecord(record)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text("利用記録（\(recordsForSelectedDate.count)件）")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("今日") {
                        selectedDate = Date()
                    }
                    .disabled(Calendar.current.isDateInToday(selectedDate))
                }
            }
            .sheet(item: $editingRecord) { record in
                EditRecordView(record: record)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - 集計データ
struct Summary {
    let total: Int
    let male: Int
    let female: Int
    let swimwear: Int
    let discounted: Int
}

// MARK: - 集計カード
struct SummaryCardView: View {
    let summary: Summary

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                SummaryItem(label: "合計", value: "\(summary.total)名", color: .primary)
                Divider().frame(height: 32)
                SummaryItem(label: "男性", value: "\(summary.male)名", color: .blue)
                Divider().frame(height: 32)
                SummaryItem(label: "女性", value: "\(summary.female)名", color: .pink)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SummaryItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 履歴1行
struct HistoryRowView: View {
    let record: GuestRecord
    let formatter: DateFormatter

    private var stayText: String {
        guard let minutes = record.stayDuration else { return "在館中" }
        return "\(minutes / 60)時間\(minutes % 60)分"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.lockerNumber)
                    .font(.headline)
                Text(record.gender)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(record.gender == "男"
                                ? Color.blue.opacity(0.15)
                                : Color.pink.opacity(0.15))
                    .foregroundColor(record.gender == "男" ? .blue : .pink)
                    .clipShape(Capsule())
                Spacer()
                StatusBadge(
                    label: record.isCheckedIn ? "在館中" : "退館済",
                    color: record.isCheckedIn ? .green : .red
                )
            }

            summaryText
                .font(.caption)

            HStack(spacing: 8) {
                Label(
                    "入館 \(formatter.string(from: record.checkInTime))",
                    systemImage: "arrow.right.circle"
                )
                .font(.caption2)
                .foregroundColor(.secondary)

                if let out = record.checkOutTime {
                    Label(
                        "退館 \(formatter.string(from: out))",
                        systemImage: "arrow.left.circle"
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }

                Label(stayText, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // プラン・レンタル品・割引をまとめて表示。会計画面と同じ配色ルール
    // （金額がかかるもの＝黒文字、かからないもの＝グレー文字）を適用する。
    private var summaryText: Text {
        var result = AttributedString()
        var isFirst = true

        func append(_ text: String, color: Color) {
            if !isFirst {
                var separator = AttributedString(" ／ ")
                separator.foregroundColor = .secondary
                separator.font = .caption
                result += separator
            }
            var segment = AttributedString(text)
            segment.foregroundColor = color
            segment.font = color == .primary ? .caption.bold() : .caption
            result += segment
            isFirst = false
        }

        append(record.displayPlanName, color: .primary)

        for item in record.checkoutRentalItemsBilling {
            append(item.text, color: item.isBillable ? .primary : .secondary)
        }

        if !record.discounts.isEmpty && record.discounts != ["なし"] {
            append(record.discounts.joined(separator: "・"), color: .secondary)
        }

        return Text(result)
    }
}

