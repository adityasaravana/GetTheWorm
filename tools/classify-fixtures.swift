import Foundation
import Vision

let grassSet: Set<String> = ["grass", "lawn", "meadow", "turf", "pasture", "grassland"]

for path in CommandLine.arguments.dropFirst() {
    let handler = VNImageRequestHandler(url: URL(fileURLWithPath: path))
    let request = VNClassifyImageRequest()
    try handler.perform([request])
    let results = request.results ?? []
    let top = results.sorted { $0.confidence > $1.confidence }.prefix(8)
    let name = (path as NSString).lastPathComponent
    print("== \(name)")
    for observation in top {
        print(String(format: "   %-22s %.3f", (observation.identifier as NSString).utf8String!, observation.confidence))
    }
    let grassHits = results.filter { grassSet.contains($0.identifier.lowercased()) && $0.confidence > 0.01 }
        .sorted { $0.confidence > $1.confidence }
    print("   grass-labels: " + (grassHits.isEmpty ? "none" : grassHits.map {
        String(format: "%@=%.3f", $0.identifier, $0.confidence)
    }.joined(separator: ", ")))
}
