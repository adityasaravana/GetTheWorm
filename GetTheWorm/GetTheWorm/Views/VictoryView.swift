//
//  VictoryView.swift
//  GetTheWorm
//

import SwiftUI

struct VictoryView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            WormTheme.room.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("🪱")
                    .font(.system(size: 92))
                    .shadow(color: WormTheme.ledGreen.opacity(0.7), radius: 24)
                LEDText(text: "YOU GOT THE WORM", size: 22, color: WormTheme.ledGreen, style: .fourteenSegment)
                LEDText(text: "GOOD MORNING", size: 13, color: WormTheme.ledAmber, style: .fourteenSegment)
                Spacer()
                Button("START THE DAY") {
                    onDismiss()
                }
                .buttonStyle(PlasticButtonStyle())
                .padding(.bottom, 30)
            }
            .padding(20)
        }
        .sensoryFeedback(.success, trigger: true)
    }
}
