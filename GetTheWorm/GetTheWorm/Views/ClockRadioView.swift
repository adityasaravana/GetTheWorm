//
//  ClockRadioView.swift
//  GetTheWorm
//
//  The face of the machine: a bedside LED clock radio by AdityaCorp.
//

import SwiftData
import SwiftUI

struct ClockRadioView: View {
    @Bindable var settings: AlarmSettings
    var scheduler: AlarmScheduler

    @State private var rearmTask: Task<Void, Never>?

    private static let weekdayLabels: [(number: Int, letter: String)] = [
        (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S"),
    ]

    var body: some View {
        ZStack {
            WoodGrainBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                clockCase
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
        }
        .onChange(of: settings.hour) { scheduleRearm() }
        .onChange(of: settings.minute) { scheduleRearm() }
        .onChange(of: settings.weekdays) { scheduleRearm() }
        .onChange(of: settings.isEnabled) { scheduleRearm(debounced: false) }
    }

    private var clockCase: some View {
        VStack(spacing: 16) {
            brandPlate
            displayWindow
            alarmPanel
            SpeakerGrille()
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.black.opacity(0.5), lineWidth: 1)
                }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [WormTheme.caseTop, WormTheme.caseBottom],
                        startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.14), .black.opacity(0.8)],
                                startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.8), radius: 24, y: 14)
        }
    }

    private var brandPlate: some View {
        HStack {
            Text("GET THE WORM")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .kerning(3)
                .embossedLabel()
            Spacer()
            Text("AdityaCorp")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .italic()
                .embossedLabel()
        }
        .padding(.horizontal, 4)
    }

    private var displayWindow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let time = Self.displayTime(for: timeline.date)
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    HStack(spacing: 5) {
                        IndicatorLED(on: settings.isEnabled)
                        Text("ARMED")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(WormTheme.labelText.opacity(0.8))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        LEDText(text: time.isPM ? "PM" : "AM", size: 10, color: WormTheme.ledRed, style: .fourteenSegment)
                        LEDText(text: Self.weekdayText(for: timeline.date), size: 9, color: WormTheme.ledRed, style: .fourteenSegment)
                    }
                }
                LEDText(text: time.text, size: 58, dimColon: !time.colonVisible)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(WormTheme.displayGlass)
                    .overlay(alignment: .top) {
                        // glass reflection
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.07), .clear],
                                    startPoint: .top, endPoint: .center))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.black.opacity(0.9), lineWidth: 2)
                    }
            }
        }
    }

    /// Everything below the glass configures the one alarm this thing exists for.
    private var alarmPanel: some View {
        let alarm = Self.alarmTime(settings)
        return VStack(spacing: 12) {
            HStack {
                Text("ALARM")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .kerning(2)
                    .embossedLabel()
                Spacer()
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        LEDText(text: alarm.text, size: 24, color: WormTheme.ledAmber)
                        LEDText(text: alarm.isPM ? "PM" : "AM", size: 11, color: WormTheme.ledAmber, style: .fourteenSegment)
                    }
                    .opacity(settings.isEnabled ? 1 : 0.35)
                    HStack(spacing: 8) {
                        HoldStepButton(title: "HOUR") {
                            settings.hour = (settings.hour + 1) % 24
                        }
                        HoldStepButton(title: "MIN") {
                            settings.minute = (settings.minute + 1) % 60
                        }
                        Text("SET")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .embossedLabel()
                    }
                }
                Spacer()
                RockerSwitch(isOn: $settings.isEnabled)
            }
            HStack(spacing: 0) {
                ForEach(Self.weekdayLabels, id: \.number) { day in
                    DIPSwitch(label: day.letter, isOn: weekdayBinding(day.number))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(WormTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.black.opacity(0.45), lineWidth: 1)
                }
        }
    }

    // MARK: State

    private func weekdayBinding(_ number: Int) -> Binding<Bool> {
        Binding(
            get: { settings.weekdays.contains(number) },
            set: { isOn in
                if isOn {
                    if !settings.weekdays.contains(number) { settings.weekdays.append(number) }
                } else {
                    settings.weekdays.removeAll { $0 == number }
                }
            })
    }

    /// Settings changes re-register everything with AlarmKit; debounced so
    /// button-mashing HOUR doesn't schedule 30 alarms per tap. The armedAt
    /// stamp updates immediately (not debounced) so a half-dialed time can
    /// never trip the ringing predicate.
    private func scheduleRearm(debounced: Bool = true) {
        settings.armedAt = .now
        rearmTask?.cancel()
        rearmTask = Task {
            if debounced {
                try? await Task.sleep(for: .seconds(1.2))
            }
            guard !Task.isCancelled else { return }
            await scheduler.rearm(settings)
        }
    }

    // MARK: Formatting

    static func displayTime(for date: Date, calendar: Calendar = .current) -> (text: String, colonVisible: Bool, isPM: Bool) {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour24 = components.hour ?? 0
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let text = String(format: "%2d:%02d", hour12, components.minute ?? 0)
        return (text, (components.second ?? 0).isMultiple(of: 2), hour24 >= 12)
    }

    static func alarmTime(_ settings: AlarmSettings) -> (text: String, isPM: Bool) {
        let hour12 = settings.hour % 12 == 0 ? 12 : settings.hour % 12
        return (String(format: "%2d:%02d", hour12, settings.minute), settings.hour >= 12)
    }

    static func weekdayText(for date: Date, calendar: Calendar = .current) -> String {
        let symbols = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
        let weekday = calendar.component(.weekday, from: date)
        return symbols[weekday - 1]
    }
}
