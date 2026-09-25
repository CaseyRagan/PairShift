import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("showDirectionControls") private var showDirectionControls = false

    var body: some View {
        ZStack {
            AtmosphereBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Eyebrow(text: "Make yourself comfortable")
                        Spacer()
                        RoundIconButton(symbol: "xmark", label: "Close Settings") { dismiss() }
                            .accessibilityIdentifier("closeSettings")
                    }
                    Text("Your space.").font(.system(.largeTitle, design: .serif, weight: .light)).tracking(-1)
                    VStack(alignment: .leading, spacing: 15) {
                        Eyebrow(text: "Feel & sound")
                        settingToggle("Sound", subtitle: "Soft clicks and a little harmony.", symbol: "speaker.wave.2", binding: $store.settings.soundEnabled)
                        Divider().overlay(.white.opacity(0.06))
                        settingToggle("Haptics", subtitle: "A gentle touch when pairs connect.", symbol: "waveform", binding: $store.settings.hapticsEnabled)
                    }.settingsCard()
                    VStack(alignment: .leading, spacing: 17) {
                        Eyebrow(text: "Appearance")
                        Picker("Appearance", selection: $store.settings.appearance) {
                            Text("System").tag(AppAppearance.system)
                            Text("Light").tag(AppAppearance.light)
                            Text("Dark").tag(AppAppearance.dark)
                        }.pickerStyle(.segmented).accessibilityIdentifier("appearancePicker")
                        settingToggle("Reduce motion", subtitle: systemReduceMotion ? "Your iPhone’s Reduce Motion setting is active." : "Gentler transitions. The same clear feedback.", symbol: "circle.dotted", binding: $store.settings.reduceMotion)
                    }.settingsCard()
                    VStack(alignment: .leading, spacing: 15) {
                        Eyebrow(text: "Play your way")
                        settingToggle("Direction buttons", subtitle: "An alternative to swiping the board.", symbol: "arrow.up.and.down.and.arrow.left.and.right", binding: $showDirectionControls)
                        Text("VoiceOver automatically shows direction buttons. Every tile also has a distinct symbol.")
                            .font(.system(size: 12)).foregroundStyle(PairShiftStyle.secondary(scheme)).lineSpacing(3)
                    }.settingsCard()
                    VStack(alignment: .leading, spacing: 17) {
                        Eyebrow(text: "A few simple things")
                        rule("01", "Move together.", "Swipe anywhere on the board. Every loose tile slides until it meets an edge or another piece.")
                        rule("02", "Make a connection.", "Matching symbols bond when they finish side by side. Each connection stays in place.")
                        rule("03", "Find your own way.", "Connect every pair. Undo and restart as often as you like. There’s no timer.")
                    }.settingsCard()
                    Text("PAIRSHIFT").font(.system(size: 11, weight: .light)).tracking(3)
                        .foregroundStyle(PairShiftStyle.secondary(scheme)).frame(maxWidth: .infinity).padding(.vertical, 10)
                }.padding(26)
            }.scrollIndicators(.hidden)
        }
        .foregroundStyle(PairShiftStyle.text(scheme))
        .tint(PairShiftStyle.accent(scheme))
        .presentationCornerRadius(30)
    }

    private func settingToggle(_ title: String, subtitle: String, symbol: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: symbol).font(.system(size: 16, weight: .light)).frame(width: 23, height: 22).foregroundStyle(PairShiftStyle.accent(scheme))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 15, weight: .medium))
                    Text(subtitle).font(.subheadline).foregroundStyle(PairShiftStyle.secondary(scheme)).fixedSize(horizontal: false, vertical: true).lineSpacing(2)
                }
            }
        }.accessibilityIdentifier(title)
    }

    private func rule(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.system(size: 10, design: .monospaced)).foregroundStyle(PairShiftStyle.accent(scheme)).padding(.top, 4)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline.weight(.medium))
                Text(detail).font(.subheadline).foregroundStyle(PairShiftStyle.secondary(scheme)).lineSpacing(3)
            }
        }
    }
}

private extension View {
    func settingsCard() -> some View {
        self.padding(20)
            .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.12), lineWidth: 0.6) }
    }
}
