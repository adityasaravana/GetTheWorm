//
//  TallyCounter.swift
//  GetTheWorm
//
//  A chrome hand tally counter sitting on the nightstand, clicking up one
//  notch per morning you beat the alarm. Tap the plunger to click it by hand,
//  hold it to spin, and hold the tiny button set into the dome to zero it.
//

import SwiftUI

struct TallyCounter: View {
    /// The number on the drums.
    @Binding var count: Int
    /// How crooked it's lying on the table. Applied before the drop shadow so
    /// the shadow still falls straight down.
    var tilt: Angle = .zero

    /// Four drums, like the real thing.
    static let maximum = 9999

    @State private var plungerPressed = false
    @State private var resetPressed = false
    @State private var resetCount = 0

    private let diameter: CGFloat = 118
    private static let digitCount = 4

    /// Hold the reset knob this long before it zeroes. A streak is worth too
    /// much to lose to a stray tap.
    private static let resetHoldDuration: TimeInterval = 0.8

    private var digits: [Int] {
        let clamped = min(max(count, 0), Self.maximum)
        let text = String(format: "%0\(Self.digitCount)d", clamped)
        return text.compactMap(\.wholeNumberValue)
    }

    var body: some View {
        ZStack {
            fingerRing
                .offset(x: -diameter * 0.56, y: diameter * 0.10)
            chromeBody
            // Below the plunger in z-order so the plunger wins where their
            // hit areas touch.
            resetButton
                .offset(x: -diameter * 0.18, y: -diameter * 0.30)
            plunger
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
        .rotationEffect(tilt)
        .shadow(color: .black.opacity(0.75), radius: 18, y: 12)
        .sensoryFeedback(.impact(weight: .light), trigger: count)
        .sensoryFeedback(.warning, trigger: resetCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wake-up streak")
        .accessibilityValue("\(count) days")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: click()
            case .decrement: count = max(count - 1, 0)
            @unknown default: break
            }
        }
        .accessibilityAction(named: "Reset") { reset() }
    }

    // MARK: Actions

    private func click() {
        guard count < Self.maximum else { return }
        count += 1
    }

    private func reset() {
        guard count != 0 else { return }
        count = 0
        resetCount += 1
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

    // MARK: Plunger (count button)

    private var plunger: some View {
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
        .shadow(color: .black.opacity(0.6), radius: plungerPressed ? 1 : 3, y: plungerPressed ? 1 : 2)
        // pushes down into the body while held
        .offset(y: plungerPressed ? 4 : 0)
        .animation(.easeOut(duration: 0.06), value: plungerPressed)
        // generous hit area: the drawn knob is small
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .holdToRepeat(isPressed: $plungerPressed, step: click)
    }

    // MARK: Reset button

    /// The tiny chrome push button set into the dome near the top. Hold it
    /// to zero the drums.
    private var resetButton: some View {
        ZStack {
            // countersunk recess
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.45), .white.opacity(0.35)],
                        startPoint: .top, endPoint: .bottom))
                .frame(width: 12, height: 12)
            // the button itself
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.97), Color(white: 0.50)],
                        startPoint: .top, endPoint: .bottom))
                .overlay { Circle().strokeBorder(.black.opacity(0.55), lineWidth: 0.6) }
                .overlay {
                    Circle().fill(.black.opacity(0.3)).frame(width: 2.5, height: 2.5)
                }
                .frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.5), radius: resetPressed ? 0 : 1, y: resetPressed ? 0 : 1)
                // sinks into the recess while held
                .scaleEffect(resetPressed ? 0.8 : 1)
                .animation(.easeOut(duration: 0.1), value: resetPressed)
        }
        // hit area well beyond the 8pt button
        .padding(10)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: Self.resetHoldDuration) {
            reset()
        } onPressingChanged: { pressing in
            resetPressed = pressing
        }
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
            .frame(width: diameter * 0.28, height: diameter * 0.48)
            .rotationEffect(.degrees(28))
            .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
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
    @Previewable @State var count = 27
    ZStack {
        WoodGrainBackground()
        TallyCounter(count: $count, tilt: .degrees(16))
    }
    .preferredColorScheme(.dark)
}
