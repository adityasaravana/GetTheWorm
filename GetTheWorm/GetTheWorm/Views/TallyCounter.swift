//
//  TallyCounter.swift
//  GetTheWorm
//
//  A chrome hand tally counter sitting on the nightstand, clicking up one
//  notch per morning you beat the alarm.
//

import SwiftUI

struct TallyCounter: View {
    /// The number on the drums. Clamped to four digits like the real thing.
    var count: Int

    private let diameter: CGFloat = 118
    private static let digitCount = 4

    private var digits: [Int] {
        let clamped = min(max(count, 0), 9999)
        let text = String(format: "%0\(Self.digitCount)d", clamped)
        return text.compactMap(\.wholeNumberValue)
    }

    var body: some View {
        ZStack {
            fingerRing
                .offset(x: -diameter * 0.56, y: diameter * 0.10)
            chromeBody
            resetKnob
                .offset(y: -diameter * 0.50)
            VStack(spacing: 7) {
                Text("STREAK")
                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(.black.opacity(0.5))
                    .shadow(color: .white.opacity(0.4), radius: 0, y: 0.7)
                digitWindow
            }
            .offset(y: diameter * 0.20)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.75), radius: 18, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wake-up streak")
        .accessibilityValue("\(count) days")
    }

    // MARK: Chrome body

    private var chromeBody: some View {
        Circle()
            .fill(Self.chrome)
            .overlay {
                // radial sheen so the dome reads as curved
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.08), .black.opacity(0.25)],
                            center: UnitPoint(x: 0.32, y: 0.26),
                            startRadius: 0, endRadius: diameter * 0.75))
            }
            .overlay {
                // machined rim
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [.white.opacity(0.9), .black.opacity(0.6), .white.opacity(0.7), .black.opacity(0.7), .white.opacity(0.9)],
                            center: .center),
                        lineWidth: 3)
            }
            .overlay {
                Circle()
                    .strokeBorder(.black.opacity(0.6), lineWidth: 0.8)
            }
            .overlay {
                // the little rivet near the top
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.45)],
                            startPoint: .top, endPoint: .bottom))
                    .frame(width: 5, height: 5)
                    .overlay { Circle().strokeBorder(.black.opacity(0.5), lineWidth: 0.5) }
                    .offset(x: -diameter * 0.18, y: -diameter * 0.30)
            }
    }

    /// Polished chrome: alternating light and dark bands around the circle.
    private static let chrome = AngularGradient(
        stops: [
            .init(color: Color(white: 0.92), location: 0.00),
            .init(color: Color(white: 0.55), location: 0.12),
            .init(color: Color(white: 0.85), location: 0.25),
            .init(color: Color(white: 0.40), location: 0.40),
            .init(color: Color(white: 0.78), location: 0.52),
            .init(color: Color(white: 0.35), location: 0.65),
            .init(color: Color(white: 0.88), location: 0.78),
            .init(color: Color(white: 0.50), location: 0.90),
            .init(color: Color(white: 0.92), location: 1.00),
        ],
        center: .center,
        angle: .degrees(-40))

    // MARK: Reset knob

    private var resetKnob: some View {
        let width = diameter * 0.30
        let height = diameter * 0.19
        return ZStack {
            // knurled black cylinder
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.08), Color(white: 0.22)],
                        startPoint: .leading, endPoint: .trailing))
                .overlay {
                    // knurling ridges
                    HStack(spacing: 2.2) {
                        ForEach(0..<9, id: \.self) { _ in
                            Rectangle()
                                .fill(.black.opacity(0.55))
                                .frame(width: 1)
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.black.opacity(0.8), lineWidth: 0.8)
                }
                .frame(width: width, height: height)
            // top cap
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.35), Color(white: 0.12)],
                        startPoint: .top, endPoint: .bottom))
                .overlay {
                    Ellipse().strokeBorder(.black.opacity(0.8), lineWidth: 0.8)
                }
                .overlay {
                    Ellipse()
                        .fill(Color(white: 0.04))
                        .padding(width * 0.22)
                }
                .frame(width: width, height: height * 0.55)
                .offset(y: -height * 0.5)
        }
        .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
    }

    // MARK: Digit window

    private var digitWindow: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                DrumDigit(value: digit)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.05))
        }
        .overlay {
            // recessed bezel
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    LinearGradient(
                        colors: [.black.opacity(0.9), .white.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5)
        }
    }

    // MARK: Finger ring

    private var fingerRing: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [Color(white: 0.95), Color(white: 0.45), Color(white: 0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 5)
            .overlay {
                Capsule().strokeBorder(.black.opacity(0.35), lineWidth: 0.8)
                Capsule().strokeBorder(.black.opacity(0.35), lineWidth: 0.8).padding(4.2)
            }
            .frame(width: diameter * 0.26, height: diameter * 0.44)
            .rotationEffect(.degrees(28))
    }
}

/// One mechanical drum: white numeral on a black cylinder, rolling vertically
/// when the value changes.
private struct DrumDigit: View {
    var value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.96))
            .contentTransition(.numericText(countsDown: false))
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: value)
            .frame(width: 13, height: 20)
            .background {
                // cylinder shading: dark at the top and bottom edges
                LinearGradient(
                    colors: [.black, Color(white: 0.17), Color(white: 0.17), .black],
                    startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .trailing) {
                Rectangle().fill(.black).frame(width: 0.8)
            }
    }
}

#Preview("Tally counter") {
    ZStack {
        WoodGrainBackground()
        VStack(spacing: 40) {
            TallyCounter(count: 0)
            TallyCounter(count: 27)
            TallyCounter(count: 1234)
        }
    }
    .preferredColorScheme(.dark)
}
