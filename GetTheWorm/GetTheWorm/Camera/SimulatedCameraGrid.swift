//
//  SimulatedCameraGrid.swift
//  GetTheWorm
//
//  The simulator has no camera, so in that environment the viewfinder becomes
//  a picker of bundled fixture photos, fed through the exact same Vision
//  pipeline as a real capture.
//

#if targetEnvironment(simulator)
import SwiftUI

struct SimulatedCameraGrid: View {
    var onPick: (UIImage) -> Void

    private let fixtures = Self.loadFixtures()

    static func loadFixtures() -> [(name: String, image: UIImage)] {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("fixture-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return urls.compactMap { url in
            UIImage(contentsOfFile: url.path).map {
                (url.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "fixture-", with: ""), $0)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("SIMULATOR: PICK A 'PHOTO'")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WormTheme.labelText)
                    .padding(.top, 10)
                if fixtures.isEmpty {
                    Text("No fixture-*.jpg images bundled.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(WormTheme.labelText)
                        .padding(.top, 40)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(fixtures, id: \.name) { fixture in
                        Button {
                            onPick(fixture.image)
                        } label: {
                            VStack(spacing: 4) {
                                Image(uiImage: fixture.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 82)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(fixture.name)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(WormTheme.labelText)
                            }
                        }
                        .accessibilityIdentifier("fixture-\(fixture.name)")
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .background(WormTheme.displayGlass)
    }
}
#endif
