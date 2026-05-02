// OCRPipeline.swift
// Runs OCR and QR detection, copies best result to clipboard.

import AppKit
import Vision

enum OCRPipeline {
    static func process(image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLanguages = ["en-US"]
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        let barcodeRequest = VNDetectBarcodesRequest()

        do {
            try handler.perform([barcodeRequest, textRequest])
        } catch {
            return
        }

        var collected = [String]()
        if let results = textRequest.results as? [VNRecognizedTextObservation] {
            let strings = results.compactMap { $0.topCandidates(1).first?.string }
            if !strings.isEmpty { collected.append(strings.joined(separator: "\n")) }
        }
        if let results = barcodeRequest.results as? [VNBarcodeObservation] {
            let qr = results.first(where: { $0.symbology == .QR })
            if let payload = qr?.payloadStringValue, !payload.isEmpty { collected.insert(payload, at: 0) }
        }

        guard let output = collected.first, !output.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
}
