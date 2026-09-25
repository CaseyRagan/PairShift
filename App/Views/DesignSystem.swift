import SwiftUI

enum PairShiftStyle {
    static let ink = Color(red: 0.035, green: 0.064, blue: 0.11)
    static let ice = Color(red: 0.63, green: 0.83, blue: 1)
    static let champagne = Color(red: 0.96, green: 0.84, blue: 0.67)
    static func text(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 0.92, green: 0.95, blue: 1) : Color(red: 0.08, green: 0.16, blue: 0.24) }
    static func secondary(_ scheme: ColorScheme) -> Color { text(scheme).opacity(scheme == .dark ? 0.62 : 0.7) }
    static func accent(_ scheme: ColorScheme) -> Color { scheme == .dark ? ice : Color(red: 0.13, green: 0.35, blue: 0.55) }
}

struct AtmosphereBackground: View {
    @Environment(\.colorScheme) private var scheme
    var scenic = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PairShiftStyle.ink
                Image("Atmosphere")
                    .resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(scheme == .dark ? (scenic ? 0.75 : 0.48) : 0.38)
                if scheme == .dark {
                    LinearGradient(colors: [PairShiftStyle.ink.opacity(0.54), PairShiftStyle.ink.opacity(scenic ? 0.1 : 0.39), PairShiftStyle.ink.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(colors: [Color(red: 0.9, green: 0.94, blue: 0.96).opacity(0.87), Color(red: 0.91, green: 0.91, blue: 0.9).opacity(0.7), Color(red: 0.88, green: 0.93, blue: 0.96)], startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(PairShiftStyle.text(scheme))
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(scheme == .dark ? 0.12 : 0.7), Color.white.opacity(scheme == .dark ? 0.035 : 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(scheme == .dark ? 0.12 : 0.65), lineWidth: 0.7) }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Color(red: 0.07, green: 0.17, blue: 0.27))
            .frame(maxWidth: .infinity).frame(minHeight: 52)
            .background {
                Capsule().fill(LinearGradient(colors: [Color(red: 0.82, green: 0.93, blue: 1), PairShiftStyle.ice], startPoint: .top, endPoint: .bottom))
                    .overlay { Capsule().strokeBorder(.white.opacity(0.75), lineWidth: 0.8) }
                    .shadow(color: PairShiftStyle.ice.opacity(0.2), radius: 16, y: 5)
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
    }
}

struct RoundIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 18, weight: .light)).frame(width: 46, height: 46) }
            .buttonStyle(GlassButtonStyle())
            .accessibilityLabel(label)
    }
}

struct Eyebrow: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2.4)
            .foregroundStyle(PairShiftStyle.secondary(scheme))
    }
}
