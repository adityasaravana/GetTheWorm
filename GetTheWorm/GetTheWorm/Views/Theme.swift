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

    private var font: Font {
        style == .sevenSegment ? WormTheme.sevenSegment(size) : WormTheme.fourteenSegment(size)
    }

    /// Every character position shows its full unlit segment set behind the lit ones.
    private var ghostText: String {
        String(text.map { character in
            switch character {
            case ":", ".": character
            default: "8"
            }
        })
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Text(ghostText)
                .font(font)
                .foregroundStyle(color.opacity(0.09))
            Text(text)
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

struct PlasticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
                color: .black.opacity(configuration.isPressed ? 0.2 : 0.55),
                radius: configuration.isPressed ? 1 : 3,
                y: configuration.isPressed ? 1 : 3)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
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
