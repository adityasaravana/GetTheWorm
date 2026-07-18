//
//  RingingView.swift
//  GetTheWorm
//
//  The alarm is ringing. The stop button lied to you. This screen is the
//  only honest way out: photograph real grass.
//

import SwiftUI

struct RingingView: View {
    @Bindable var settings: AlarmSettings
    var scheduler: AlarmScheduler
    /// Called synchronously on a verified grass photo, before teardown.
    var onVictory: () -> Void

    @State private var camera = CameraController()
    @State private var isVerifying = false
    @State private var failMessage: String?
    @State private var lastObservations: [(label: String, confidence: Float)] = []

    private static let failMessages = [
        "NOT GRASS", "STILL NOT GRASS", "NICE TRY", "GO OUTSIDE"
    ]

    var body: some View {
        ZStack {
            WormTheme.room.ignoresSafeArea()
            VStack(spacing: 22) {
                header
                viewfinder
                verdictReadout
                captureButton
            }
            .padding(20)
        }
        .task {
            #if !targetEnvironment(simulator)
            await camera.start()
            #endif
        }
        .onDisappear {
            #if !targetEnvironment(simulator)
            camera.stop()
            #endif
        }
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 0.6)) { timeline in
            let blinkOn = Int(timeline.date.timeIntervalSinceReferenceDate / 0.6).isMultiple(of: 2)
            VStack(spacing: 12) {
                LEDText(text: "WAKE UP", size: 40, style: .fourteenSegment)
                    .opacity(blinkOn ? 1 : 0.12)
                LEDText(
                    text: "PHOTOGRAPH GRASS TO SILENCE",
                    size: 11, color: WormTheme.ledAmber, style: .fourteenSegment)
            }
        }
    }

    private var viewfinder: some View {
        ZStack {
            #if targetEnvironment(simulator)
            SimulatedCameraGrid { image, isGrassTruth in
                Task { await verify(image, simulatorGroundTruth: isGrassTruth) }
            }
            #else
            switch camera.status {
            case .running, .idle:
                CameraPreview(session: camera.session)
            case .denied:
                cameraProblem(
                    "CAMERA ACCESS DENIED",
                    detail: "The alarm will keep ringing. Enable the camera in Settings.",
                    showsSettingsButton: true)
            case .unavailable:
                cameraProblem("NO CAMERA FOUND", detail: "This device has no usable camera.")
            }
            #endif
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.08)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 5)
        }
        .shadow(color: .black.opacity(0.7), radius: 16, y: 8)
    }

    private func cameraProblem(_ title: String, detail: String, showsSettingsButton: Bool = false) -> some View {
        VStack(spacing: 14) {
            LEDText(text: title, size: 12, style: .fourteenSegment)
            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WormTheme.labelText)
                .multilineTextAlignment(.center)
            if showsSettingsButton {
                Button("OPEN SETTINGS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(PlasticButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WormTheme.displayGlass)
    }

    private var verdictReadout: some View {
        VStack(spacing: 8) {
            if isVerifying {
                LEDText(text: "ANALYZING...", size: 13, color: WormTheme.ledAmber, style: .fourteenSegment)
            } else if let failMessage {
                LEDText(text: failMessage, size: 13, style: .fourteenSegment)
            }
            #if DEBUG
            if !lastObservations.isEmpty {
                Text(lastObservations.prefix(4)
                    .map { "\($0.label) \(String(format: "%.2f", $0.confidence))" }
                    .joined(separator: "  ·  "))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(WormTheme.labelText.opacity(0.6))
            }
            #endif
        }
        .frame(minHeight: 40)
    }

    private var captureButton: some View {
        #if targetEnvironment(simulator)
        EmptyView()
        #else
        Button {
            Task {
                guard let image = await camera.capture() else { return }
                await verify(image)
            }
        } label: {
            Text("PROVE IT")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .kerning(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.85, green: 0.16, blue: 0.12), Color(red: 0.55, green: 0.07, blue: 0.05)],
                        startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.6), radius: 4, y: 4)
        }
        .disabled(isVerifying || camera.status != .running)
        #endif
    }

    private func verify(_ image: UIImage, simulatorGroundTruth: Bool? = nil) async {
        guard let cgImage = image.cgImage else {
            failMessage = "BAD PHOTO. TRY AGAIN."
            return
        }
        isVerifying = true
        failMessage = nil
        let verdict: GrassCheck.Verdict
        #if targetEnvironment(simulator)
        // Vision classification is unavailable in the simulator (espresso
        // context failure); fixtures carry their ground truth instead.
        try? await Task.sleep(for: .milliseconds(600))
        verdict = GrassCheck.Verdict(
            isGrass: simulatorGroundTruth ?? false,
            observations: [("simulator-fixture", 1.0)])
        #else
        verdict = await GrassCheck.verify(cgImage)
        #endif
        isVerifying = false
        lastObservations = verdict.observations
        if verdict.isGrass {
            onVictory()
            await scheduler.victory(settings)
        } else {
            failMessage = Self.failMessages.randomElement()
        }
    }
}
