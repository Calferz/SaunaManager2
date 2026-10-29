//
//  LockerMapView.swift
//  SaunaManager
//
//  Created on 2026/05/04.
//

// Views/LockerMapView.swift 全体を差し替え
import SwiftUI
import UIKit
import Combine

struct LockerMapView: View {
    @EnvironmentObject var store: GuestStore

    // 経過時間表示を定期的に更新するための現在時刻
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    let northLockers = [1, 3, 5, 7, 9, 11, 15, 17, 19, 21, 23, 25]
    let southLockers = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27]

    private var activeNorthNumbers: Set<Int> {
        Set(store.activeGuests
            .filter { $0.lockerNumber.hasPrefix("N") }
            .compactMap { Int($0.lockerNumber.dropFirst()) }
        )
    }

    private var activeSouthNumbers: Set<Int> {
        Set(store.activeGuests
            .filter { $0.lockerNumber.hasPrefix("S") }
            .compactMap { Int($0.lockerNumber.dropFirst()) }
        )
    }

    private func guestForLocker(_ prefix: String, _ number: Int) -> GuestRecord? {
        let id = String(format: "\(prefix)%03d", number)
        return store.activeGuests.first { $0.lockerNumber == id }
    }

    // ランステ利用中（ランニング中）のロッカー一覧。
    // ・「ランステ」：終始ランニングのみのプラン
    // ・「ランステ＋通常利用」でまだサウナ利用を開始していない（＝ランニング中）もの
    private var runningStayGuests: [GuestRecord] {
        store.activeGuests
            .filter { $0.plan == "ランステ" || ($0.plan == "ランステ＋通常利用" && $0.saunaStartTime == nil) }
            .sorted { $0.lockerNumber < $1.lockerNumber }
    }

    private var northGenderLabel: String { store.weeklyAssignment.northGender.rawValue }
    private var southGenderLabel: String { store.weeklyAssignment.southGender.rawValue }
    private var northGenderColor: Color { store.weeklyAssignment.northGender == .male ? .blue : .pink }
    private var southGenderColor: Color { store.weeklyAssignment.southGender == .male ? .blue : .pink }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {

                    // 北エリア
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("北エリア")
                                .font(.headline)
                            Text(northGenderLabel)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(northGenderColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(northGenderColor.opacity(0.12))
                                .clipShape(Capsule())
                            Spacer()
                            Text("\(northLockers.filter { activeNorthNumbers.contains($0) }.count) / \(northLockers.count)使用中")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        let northRow1 = Array(northLockers.prefix(6))
                        let northRow2 = Array(northLockers.suffix(6))

                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(northRow1, id: \.self) { number in
                                    LockerCell(
                                        label: "\(number)",
                                        isActive: activeNorthNumbers.contains(number),
                                        guest: guestForLocker("N", number),
                                        isNorth: true,
                                        now: now
                                    )
                                }
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(uiColor: .lightGray))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                    Text("13")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 64)
                            }
                            HStack(spacing: 6) {
                                ForEach(northRow2, id: \.self) { number in
                                    LockerCell(
                                        label: "\(number)",
                                        isActive: activeNorthNumbers.contains(number),
                                        guest: guestForLocker("N", number),
                                        isNorth: true,
                                        now: now
                                    )
                                }
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(uiColor: .lightGray))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                    Text("27")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 64)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal)

                    // 南エリア
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("南エリア")
                                .font(.headline)
                            Text(southGenderLabel)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(southGenderColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(southGenderColor.opacity(0.12))
                                .clipShape(Capsule())
                            Spacer()
                            Text("\(southLockers.filter { activeSouthNumbers.contains($0) }.count) / \(southLockers.count)使用中")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        let southRow1 = Array(southLockers.prefix(7))
                        let southRow2 = Array(southLockers.suffix(7))

                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(southRow1, id: \.self) { number in
                                    LockerCell(
                                        label: "\(number)",
                                        isActive: activeSouthNumbers.contains(number),
                                        guest: guestForLocker("S", number),
                                        isNorth: false,
                                        now: now
                                    )
                                }
                            }
                            HStack(spacing: 6) {
                                ForEach(southRow2, id: \.self) { number in
                                    LockerCell(
                                        label: "\(number)",
                                        isActive: activeSouthNumbers.contains(number),
                                        guest: guestForLocker("S", number),
                                        isNorth: false,
                                        now: now
                                    )
                                }
                            }
                        }

                    }
                    .padding()
                    .background(Color(uiColor: .lightGray))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal)

                    // ランステ利用中のロッカーを横並びで表示（ロゴ＋ロッカー番号）・南エリアの外に独立して配置
                    if !runningStayGuests.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ランステ利用中")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            FlowLayout(spacing: 5) {
                                ForEach(runningStayGuests) { guest in
                                    HStack(spacing: 2) {
                                        Image("Running")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 8)
                                        Text(guest.lockerNumber)
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)
                    }

                }
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ロッカー使用状況")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(timer) { input in
            now = input
        }
    }
}

// MARK: - ロッカーセル

struct LockerCell: View {
    let label: String
    let isActive: Bool
    let guest: GuestRecord?
    let isNorth: Bool
    let now: Date

    // 入館からの経過時間（HH:mm）
    // checkInTime は日付部分が基準日（2001/1/1）に固定されて保存されるため、
    // 時刻（時分秒）のみを比較する。日をまたいだ在館にも対応。
    // now は再描画のトリガー用（LockerMapViewのタイマー更新時に古い値のままだと、
    // 入館直後にまだ更新されていない過去の now と比較して日またぎ判定が誤作動するため、
    // 比較には必ずその場で取得した現在時刻を使う。
    private var elapsedText: String? {
        guard isActive, let guest = guest else { return nil }
        _ = now  // 再描画のトリガーとしてのみ利用

        let elapsed = guest.runningElapsedMinutes()
        let hours = elapsed / 60
        let minutes = elapsed % 60
        return String(format: "%02d:%02d", hours, minutes)
    }


    // 朝活軽食かどうか（新表記「＋軽食」／旧表記「朝活軽食」の両方に対応）
    private var isMorningMeal: Bool {
        guest?.plan == "＋軽食" || guest?.plan == "朝活軽食"
    }

    // ランステかどうか
    private var isRunningStay: Bool {
        guest?.plan == "ランステ"
    }

    private var deadline: Date? {
        guard let guest = guest else { return nil }
        switch guest.plan {
        case "30分":  return Calendar.current.date(byAdding: .minute, value: 33,  to: guest.checkInTime)
        case "60分":  return Calendar.current.date(byAdding: .minute, value: 60,  to: guest.checkInTime)
        case "90分":  return Calendar.current.date(byAdding: .minute, value: 90,  to: guest.checkInTime)
        case "120分": return Calendar.current.date(byAdding: .minute, value: 120, to: guest.checkInTime)
        case "150分": return Calendar.current.date(byAdding: .minute, value: 150, to: guest.checkInTime)
        default:      return nil
        }
    }

    private var remainingMinutes: Int? {
        guard let dl = deadline else { return nil }
        return max(0, Int(dl.timeIntervalSince(Date()) / 60))
    }

    private var deadlineText: String? {
        guard let dl = deadline else { return nil }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: dl)
    }

    private var timeColor: Color {
        guard let remaining = remainingMinutes else { return .clear }
        if remaining <= 10 { return .red }
        if remaining <= 20 { return Color(red: 1.0, green: 0.3, blue: 0.0) }
        if remaining <= 30 { return .orange }
        if remaining <= 45 { return Color(red: 1.0, green: 0.9, blue: 0.0) }
        return .white
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(hex: "50C878") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 1)
                )

            // ロッカー番号は経過時間・アイコンの有無に関わらず常にセル中央の固定位置に表示
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(
                    isActive ? .white : .black
                )

            // 経過時間・期限は番号と重ならない下部の帯の中で、上下の余白が均等になるよう縦方向に中央揃え
            if elapsedText != nil || deadlineText != nil {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: 2) {
                        if let elapsed = elapsedText {
                            Text(elapsed)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                        }
                        if let timeText = deadlineText {
                            Text(timeText)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(timeColor)
                        }
                    }
                    .frame(height: 24)
                }
                .frame(width: 44, height: 64)
            }

            // 朝活軽食・ランステのアイコンは番号と重ならない上部の余白に表示
            if isActive && (isMorningMeal || isRunningStay) {
                VStack(spacing: 0) {
                    if isMorningMeal {
                        // 上下の余白が均等になるよう、上部の帯の中で縦方向に中央揃え
                        Image("SOYJOY")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 30, maxHeight: 20)
                            .frame(height: 24)
                    } else {
                        // 上下の余白が均等になるよう、上部の帯の中で縦方向に中央揃え
                        Image("Running")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 40, maxHeight: 14)
                            .frame(height: 24)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 44, height: 64)
            }
        }
        .frame(width: 44, height: 64)
    }
}

