import SwiftUI
import PairShiftCore

struct JourneyView: View {
    @ObservedObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AtmosphereBackground(scenic: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HStack {
                        Eyebrow(text: "PAIRSHIFT")
                        Spacer()
                        RoundIconButton(symbol: "xmark", label: "Close Journey") { dismiss() }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your journey.").font(.system(size: 40, weight: .light, design: .serif)).tracking(-1)
                        Text("A little space to think.\nOne connection at a time.")
                            .font(.system(size: 15)).lineSpacing(5).foregroundStyle(PairShiftStyle.secondary(scheme))
                    }
                    VStack(spacing: 10) {
                        HStack {
                            Eyebrow(text: "\(store.completedLevelIDs.count) of \(store.levels.count) connected")
                            Spacer()
                            Text("\(Int(Double(store.completedLevelIDs.count) / Double(store.levels.count) * 100))%")
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(PairShiftStyle.accent(scheme))
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(PairShiftStyle.text(scheme).opacity(0.1))
                                Capsule().fill(LinearGradient(colors: [PairShiftStyle.ice, PairShiftStyle.champagne], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(0, proxy.size.width * Double(store.completedLevelIDs.count) / Double(store.levels.count)))
                            }
                        }.frame(height: 3)
                    }
                    ForEach(0..<4) { chapter in
                        chapterSection(chapter)
                    }
                    Text("There’s no hurry here.")
                        .font(.system(size: 15, weight: .light, design: .serif)).italic()
                        .foregroundStyle(PairShiftStyle.secondary(scheme))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }.padding(26)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(PairShiftStyle.text(scheme))
        .presentationCornerRadius(30)
    }

    private func chapterSection(_ index: Int) -> some View {
        let levels = Array(store.levels.dropFirst(index * 5).prefix(5))
        return VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1)).font(.system(size: 10, design: .monospaced)).foregroundStyle(PairShiftStyle.accent(scheme))
                Text(levels.first?.chapter ?? "Journey").font(.system(size: 18, weight: .light, design: .serif))
                Rectangle().fill(PairShiftStyle.text(scheme).opacity(0.12)).frame(height: 0.7)
            }
            HStack(spacing: 8) {
                ForEach(levels) { level in
                    levelButton(level)
                }
            }
        }
    }

    private func levelButton(_ level: LevelDefinition) -> some View {
        let unlocked = store.isUnlocked(level)
        let complete = store.completedLevelIDs.contains(level.id)
        let current = level.id == store.level.id
        return Button {
            store.selectLevel(id: level.id)
            dismiss()
        } label: {
            VStack(spacing: 9) {
                if unlocked {
                    Text(String(format: "%02d", level.id)).font(.system(size: 20, weight: .light, design: .rounded)).monospacedDigit()
                } else {
                    Image(systemName: "lock").font(.system(size: 16, weight: .light)).frame(height: 24)
                }
                Image(systemName: complete ? "link" : (current ? "circle.fill" : "minus"))
                    .font(.system(size: complete ? 10 : 5, weight: .medium))
                    .foregroundStyle(complete ? PairShiftStyle.accent(scheme) : PairShiftStyle.secondary(scheme))
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity).frame(height: 76)
            .background {
                RoundedRectangle(cornerRadius: 15).fill(current ? PairShiftStyle.ice.opacity(scheme == .dark ? 0.15 : 0.22) : Color.white.opacity(scheme == .dark ? 0.025 : 0.25))
            }
            .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(current ? PairShiftStyle.accent(scheme).opacity(0.55) : .clear, lineWidth: 1) }
        }
        .buttonStyle(GlassButtonStyle())
        .disabled(!unlocked).opacity(unlocked ? 1 : 0.38)
        .accessibilityIdentifier("level_\(level.id)")
        .accessibilityLabel("Level \(level.id), \(level.title)\(complete ? ", completed" : "")\(unlocked ? "" : ", locked")")
        .accessibilityValue(store.bestMoves[level.id].map { "Best: \($0) moves" } ?? "")
    }
}
