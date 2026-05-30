import Foundation
import Vision
import AppKit

struct OCRText: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect // normalized, origin bottom-left
    let confidence: Float
}

enum ImageOCRService {
    static func recognizeText(in url: URL) async -> [OCRText] {
        guard let cgImage = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en", "vi"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("[OCR] Error: \(error)")
            return []
        }

        guard let observations = request.results else {
            return []
        }

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let confidence = candidate.confidence
            let text = candidate.string
            // boundingBox is normalized, origin bottom-left
            let box = observation.boundingBox
            return OCRText(text: text, boundingBox: box, confidence: confidence)
        }
    }
}
