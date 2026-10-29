//
//  Components.swift
//  SaunaManager
//
//  Created on 2026/05/11.
//

import SwiftUI

// MARK: - 曜日タイプ
enum DayType {
    case weekday, saturday, holiday
}

// MARK: - popover風の吹き出し形状（左向き矢印つき角丸カード）
struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 14
    var arrowWidth: CGFloat = 10
    var arrowHeight: CGFloat = 16
    /// 矢印の先端のY座標（吹き出し左上を0とした絶対位置）。nilなら縦中央。
    var arrowY: CGFloat? = nil

    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(x: rect.minX + arrowWidth, y: rect.minY,
                                 width: rect.width - arrowWidth, height: rect.height)
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)

        let midY = arrowY ?? rect.midY
        var arrow = Path()
        arrow.move(to: CGPoint(x: bubbleRect.minX, y: midY - arrowHeight / 2))
        arrow.addLine(to: CGPoint(x: rect.minX, y: midY))
        arrow.addLine(to: CGPoint(x: bubbleRect.minX, y: midY + arrowHeight / 2))
        arrow.closeSubpath()
        path.addPath(arrow)
        return path
    }
}

// MARK: - 吹き出しの実測高さをアイコン列に伝えるPreferenceKey
struct BubbleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - セクションヘッダー
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

// MARK: - 利用プランの大分類（アイコンボタン→ポップアップ選択）
enum PlanCategory: Identifiable {
    case normal, runSte, other
    var id: Self { self }
    var title: String {
        switch self {
        case .normal: return "通常利用"
        case .runSte: return "ランステ"
        case .other:  return "その他"
        }
    }
}

// MARK: - カテゴリアイコンボタン（利用プランの大分類選択）
enum CategoryIcon {
    case system(String)
    case asset(String)
    case dots
}

struct CategoryIconButton: View {
    let title: String
    let icon: CategoryIcon
    let isSelected: Bool
    var iconSize: CGFloat = 36
    var buttonSize: CGFloat = 100
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    switch icon {
                    case .system(let name):
                        Image(systemName: name)
                            .font(.system(size: iconSize))
                    case .asset(let name):
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                    case .dots:
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle().frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                .frame(width: buttonSize * 0.52, height: buttonSize * 0.52)

                Text(title)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(isSelected ? Color(hex: "0F6E56") : .primary)
            .frame(width: buttonSize, height: buttonSize)
            .background(Circle().fill(isSelected ? Color(hex: "E1F5EE") : Color(.systemBackground)))
            .overlay(
                Circle().stroke(isSelected ? Color(hex: "1D9E75") : Color(.systemGray4),
                                 lineWidth: isSelected ? 1.5 : 0.5)
            )
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - カテゴリピルボタン（横長・左アイコン＋右ラベル）
struct CategoryPillButton: View {
    let title: String
    let icon: CategoryIcon
    let isSelected: Bool
    var iconSize: CGFloat = 22
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    switch icon {
                    case .system(let name):
                        Image(systemName: name)
                            .font(.system(size: iconSize))
                    case .asset(let name):
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                    case .dots:
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle().frame(width: 5, height: 5)
                            }
                        }
                    }
                }
                .frame(width: 28, height: 28)

                Text(title)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? Color(hex: "0F6E56") : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(alignment: .center)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "E1F5EE") : Color(.systemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color(hex: "1D9E75") : Color(.systemGray4),
                             lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
    }
}

// MARK: - プランカード
struct PlanCard: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color(hex: "E1F5EE") : Color(.systemBackground))
                .foregroundColor(isSelected ? Color(hex: "0F6E56") : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(hex: "1D9E75") : Color(.systemGray4),
                                lineWidth: isSelected ? 1.5 : 0.5)
                )
                .cornerRadius(8)
        }
    }
}

// MARK: - チップボタン
struct ChipButton: View {
    enum ChipStyle { case green, warning, purple, neutral }
    let title: String
    let isSelected: Bool
    let style: ChipStyle
    var isLarge: Bool = false
    let action: () -> Void

    var selectedBg: Color {
        switch style {
        case .green:   return Color(hex: "E1F5EE")
        case .warning: return Color(hex: "FAEEDA")
        case .purple:  return Color(hex: "EEEDFE")
        case .neutral: return Color(.systemGray5)
        }
    }
    var selectedFg: Color {
        switch style {
        case .green:   return Color(hex: "0F6E56")
        case .warning: return Color(hex: "854F0B")
        case .purple:  return Color(hex: "534AB7")
        case .neutral: return Color(.secondaryLabel)
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isLarge ? .subheadline : .caption)
                .fontWeight(isLarge ? .medium : .regular)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, isLarge ? 16 : 12)
                .padding(.vertical, isLarge ? 8 : 5)
                .background(isSelected ? selectedBg : Color(.systemBackground))
                .foregroundColor(isSelected ? selectedFg : .secondary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? selectedFg : Color(.systemGray4), lineWidth: isLarge ? 1 : 0.5)
                )
                .clipShape(Capsule())
        }
    }
}

// MARK: - ステータスバッジ
struct StatusBadge: View {
    let label: String
    let color: Color

    var bg: Color { color == .green ? Color(hex: "E1F5EE") : Color(hex: "FCEBEB") }
    var fg: Color { color == .green ? Color(hex: "0F6E56") : Color(hex: "A32D2D") }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .foregroundColor(fg)
            .clipShape(Capsule())
    }
}

enum SheetType: Identifiable {
    case checkOut(GuestRecord)
    case manualCheckIn

    var id: String {
        switch self {
        case .checkOut(let record): return record.id.uuidString
        case .manualCheckIn:        return "manualCheckIn"
        }
    }
}

// MARK: - Color hex拡張
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// SharedComponents.swift に追加

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: frame.minX + bounds.minX, y: frame.minY + bounds.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        // サイズの異なる要素が混在する場合、各行の下端に揃えて配置する（水着チップなど）
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            // 1st pass: 行ごとにグループ化
            var rows: [[(index: Int, size: CGSize)]] = [[]]
            var x: CGFloat = 0
            var maxX: CGFloat = 0

            for (index, subview) in subviews.enumerated() {
                let itemSize = subview.sizeThatFits(.unspecified)
                if x + itemSize.width > maxWidth && x > 0 {
                    x = 0
                    rows.append([])
                }
                rows[rows.count - 1].append((index, itemSize))
                x += itemSize.width + spacing
                maxX = max(maxX, x - spacing)
            }

            // 2nd pass: 行の最大高さに下揃えでフレームを確定
            var frameByIndex: [Int: CGRect] = [:]
            var y: CGFloat = 0

            for row in rows where !row.isEmpty {
                let rowHeight = row.map { $0.size.height }.max() ?? 0
                var rowX: CGFloat = 0
                for (index, itemSize) in row {
                    let itemY = y + (rowHeight - itemSize.height)
                    frameByIndex[index] = CGRect(origin: CGPoint(x: rowX, y: itemY), size: itemSize)
                    rowX += itemSize.width + spacing
                }
                y += rowHeight + spacing
            }

            frames = (0..<subviews.count).map { frameByIndex[$0] ?? .zero }
            let totalHeight = max(0, y - spacing)
            self.size = CGSize(width: maxX, height: totalHeight)
        }
    }
}

