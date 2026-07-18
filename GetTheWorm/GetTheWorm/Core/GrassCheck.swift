//
//  GrassCheck.swift
//  GetTheWorm
//
//  On-device grass verification via Vision's image classifier. Strict by
//  design: houseplants and trees don't cut it — go outside.
//

import CoreGraphics
import Vision

enum GrassCheck {
    struct Verdict {
        let isGrass: Bool
        /// Top classifications, for the debug readout and threshold tuning.
        let observations: [(label: String, confidence: Float)]
    }

    /// Identifiers in the Vision taxonomy that count as actual grass.
    static let grassIdentifiers: Set<String> = [
        "grass", "lawn", "meadow", "turf", "pasture", "grassland",
    ]

    /// Minimum classifier confidence for a grass label to count.
    /// Tuned against the bundled fixture photos.
    static let minimumConfidence: Float = 0.15

    static func verify(_ image: CGImage) async -> Verdict {
        let request = ClassifyImageRequest()
        guard let results = try? await request.perform(on: image) else {
            return Verdict(isGrass: false, observations: [])
        }
        let sorted = results.sorted { $0.confidence > $1.confidence }
        let top = sorted.prefix(10).map { (label: $0.identifier, confidence: $0.confidence) }
        let isGrass = results.contains {
            grassIdentifiers.contains($0.identifier.lowercased()) && $0.confidence >= minimumConfidence
        }
        return Verdict(isGrass: isGrass, observations: top)
    }
}
