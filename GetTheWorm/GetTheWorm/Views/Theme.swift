//
//  Theme.swift
//  GetTheWorm
//
//  The plastic and the glow: shared pieces of the 90s clock-radio look.
//

import SwiftUI

enum WormTheme {
    // LED colors
    static let ledRed = Color(red: 1.00, green: 0.23, blue: 0.16)
    static let ledGreen = Color(red: 0.35, green: 1.00, blue: 0.45)
    static let ledAmber = Color(red: 1.00, green: 0.72, blue: 0.20)

    // Case plastics
    static let caseTop = Color(white: 0.18)
    static let caseBottom = Color(white: 0.09)
    static let panel = Color(white: 0.13)
    static let well = Color(white: 0.055)
    static let displayGlass = Color(red: 0.05, green: 0.016, blue: 0.012)
    static let labelText = Color(white: 0.60)
    static let room = Color(white: 0.03)

    static func sevenSegment(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "DSEG7Classic-Bold" : "DSEG7Classic-Regular", size: size)
    }

    static func fourteenSegment(_ size: CGFloat) -> Font {
        .custom("DSEG14Classic-Regular", size: size)
    }
}

// MARK: - LED display text

/// Seven/fourteen-segment text with unlit ghost segments and a phosphor glow.
struct LEDText: View {
    enum Style {
        case sevenSegment
        case fourteenSegment
    }

    var text: String
    var size: CGFloat
    var color: Color = WormTheme.ledRed
    var style: Style = .sevenSegment
    /// Renders the colon at ghost brightness (for blinking) without ever
    /// changing the string — glyph widths must stay identical or the display
    /// shifts.
    var dimColon: Bool = false

    private var font: Font {
        style == .sevenSegment ? WormTheme.sevenSegment(size) : WormTheme.fourteenSegment(size)
    }

    private var ghostColor: Color { color.opacity(0.09) }

    /// Every character position shows its full unlit segment set behind the lit ones.
    private var ghostText: String {
        String(text.map { character in
            switch character {
            case ":", ".", " ": character
            default: "8"
            }
        })
    }

    private var litText: AttributedString {
        var attributed = AttributedString(text)
        if dimColon {
            var index = attributed.startIndex
            for character in text {
                let next = attributed.index(index, offsetByCharacters: 1)
                if character == ":" {
                    attributed[index..<next].foregroundColor = ghostColor
                }
                index = next
            }
        }
        return attributed
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Text(ghostText)
                .font(font)
                .foregroundStyle(ghostColor)
            Text(litText)
                .font(font)
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.85), radius: size * 0.10)
                .shadow(color: color.opacity(0.40), radius: size * 0.28)
        }
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - Plastic controls

/// Shared plastic-button surface (fill, bevel, press-down animation). Used by
/// both the tap-only `PlasticButtonStyle` and the press-and-hold
/// `HoldStepButton` so the two look identical.
struct PlasticButtonSurface: ViewModifier {
    var isPressed: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .kerning(1.2)
            .foregroundStyle(WormTheme.labelText)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.26), Color(white: 0.15)],
                            startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .black.opacity(0.55)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(isPressed ? 0.2 : 0.55),
                radius: isPressed ? 1 : 3,
                y: isPressed ? 1 : 3)
            .offset(y: isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

struct PlasticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(PlasticButtonSurface(isPressed: configuration.isPressed))
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

/// A plastic button that steps once on tap, then repeats at a fixed fast
/// cadence while held down — the way a bedside clock's HOUR/MIN buttons behave.
/// Steady velocity, no acceleration.
struct HoldStepButton: View {
    let title: String
    let step: () -> Void

    @State private var isPressed = false
    @State private var repeatTask: Task<Void, Never>?

    /// Pause after the first step before the held repeat kicks in, then the
    /// gap between each rapid step.
    private static let holdDelay: Duration = .milliseconds(350)
    private static let stepInterval: Duration = .milliseconds(70)

    var body: some View {
        Text(title)
            .modifier(PlasticButtonSurface(isPressed: isPressed))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        step()  // first step lands immediately, like a tap
                        startRepeating()
                    }
                    .onEnded { _ in stop() }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
            .onDisappear { stop() }
    }

    private func startRepeating() {
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: Self.holdDelay)
            while !Task.isCancelled {
                step()
                try? await Task.sleep(for: Self.stepInterval)
            }
        }
    }

    private func stop() {
        repeatTask?.cancel()
        repeatTask = nil
        isPressed = false
    }
}

/// One switch of the weekday DIP bank.
struct DIPSwitch: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .embossedLabel(bright: isOn)
            ZStack(alignment: isOn ? .top : .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(WormTheme.well)
                    .frame(width: 20, height: 36)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(.black.opacity(0.7), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.06))
                            .frame(height: 1.5)
                            .padding(.horizontal, 1)
                    }
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.55), Color(white: 0.34)],
                            startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: 15)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                    .padding(3)
            }
            IndicatorLED(on: isOn)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isOn)
    }
}

/// The big physical ALARM on/off rocker: nub up = armed.
struct RockerSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("ON")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .embossedLabel(bright: isOn)
            ZStack(alignment: isOn ? .top : .bottom) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(WormTheme.well)
                    .frame(width: 34, height: 58)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.black.opacity(0.7), lineWidth: 1.2)
                    }
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Color(red: 0.85, green: 0.25, blue: 0.20), Color(red: 0.55, green: 0.10, blue: 0.08)]
                                : [Color(white: 0.55), Color(white: 0.34)],
                            startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 26)
                    .overlay {
                        // grip ridges
                        VStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { _ in
                                Capsule().fill(.black.opacity(0.25)).frame(width: 14, height: 1.5)
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1.5)
                    .padding(4)
            }
            Text("OFF")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .embossedLabel(bright: !isOn)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                isOn.toggle()
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: isOn)
        .accessibilityRepresentation {
            Toggle("Alarm armed", isOn: $isOn)
        }
    }
}

struct IndicatorLED: View {
    var on: Bool
    var color: Color = WormTheme.ledRed

    var body: some View {
        Circle()
            .fill(on ? color : Color(white: 0.10))
            .frame(width: 6, height: 6)
            .shadow(color: on ? color.opacity(0.9) : .clear, radius: 3.5)
            .overlay {
                Circle().strokeBorder(.black.opacity(0.6), lineWidth: 0.5)
            }
    }
}

struct SpeakerGrille: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10
            let radius: CGFloat = 2.1
            var row = 0
            var y = spacing / 2
            while y < size.height {
                let offset = row.isMultiple(of: 2) ? spacing / 2 : spacing
                var x = offset
                while x < size.width - spacing / 4 {
                    let hole = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    let shine = hole.offsetBy(dx: 0, dy: 0.8)
                    context.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.055)))
                    context.fill(Path(ellipseIn: hole), with: .color(.black.opacity(0.85)))
                    x += spacing
                }
                y += spacing * 0.82
                row += 1
            }
        }
    }
}

// MARK: - Wood grain

/// The bedside table the radio sits on: procedural dark walnut veneer.
/// Seeded RNG so the grain is identical every render.
struct WoodGrainBackground: View {
    var body: some View {
        Canvas { context, size in
            let top = Color(red: 0.26, green: 0.17, blue: 0.10)
            let bottom = Color(red: 0.15, green: 0.09, blue: 0.05)
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [top, bottom]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)))

            var rng = SplitMix64(seed: 0x60D5_EED)
            for _ in 0..<170 {
                let y = CGFloat(rng.next01()) * size.height
                let isHighlight = rng.next01() < 0.22
                let color = isHighlight
                    ? Color(red: 0.42, green: 0.29, blue: 0.16)
                    : Color(red: 0.07, green: 0.04, blue: 0.02)
                let alpha = 0.05 + rng.next01() * 0.13
                let width = 0.5 + CGFloat(rng.next01()) * 1.9

                var path = Path()
                var x: CGFloat = -20
                var currentY = y
                path.move(to: CGPoint(x: x, y: currentY))
                while x < size.width + 20 {
                    let step = 50 + CGFloat(rng.next01()) * 90
                    let nextY = y + CGFloat(rng.next01() - 0.5) * 9
                    path.addQuadCurve(
                        to: CGPoint(x: x + step, y: nextY),
                        control: CGPoint(x: x + step / 2, y: currentY + CGFloat(rng.next01() - 0.5) * 7))
                    x += step
                    currentY = nextY
                }
                context.stroke(path, with: .color(color.opacity(alpha)), lineWidth: width)
            }

            // soft vignette so the case stays the brightest thing on screen
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.55)]),
                    center: CGPoint(x: size.width / 2, y: size.height * 0.45),
                    startRadius: size.width * 0.35,
                    endRadius: size.height * 0.75))
        }
        .ignoresSafeArea()
    }
}

/// Tiny deterministic RNG (SplitMix64) for stable procedural textures.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next01() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

// MARK: - Helpers

extension View {
    /// Text engraved into the plastic case.
    func embossedLabel(bright: Bool = false) -> some View {
        self
            .foregroundStyle(bright ? Color(white: 0.85) : WormTheme.labelText)
            .shadow(color: .black.opacity(0.9), radius: 0.5, y: -0.6)
            .shadow(color: .white.opacity(0.10), radius: 0.5, y: 0.8)
    }
}
