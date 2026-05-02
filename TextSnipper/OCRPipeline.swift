// OCRPipeline.swift
// Runs OCR and QR detection, copies best result to clipboard.

import AppKit
import Vision

enum OCRPipeline {
    static func recognize(image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            recognize(cgImage: cgImage)
        }.value
    }

    nonisolated private static func recognize(cgImage: CGImage) -> String? {
        guard !Task.isCancelled else { return nil }

        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.qr]

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([barcodeRequest])
        } catch {
            return nil
        }

        if let payload = barcodeRequest.results?.first?.payloadStringValue, !payload.isEmpty {
            return payload
        }

        guard !Task.isCancelled else { return nil }

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLanguages = ["en-US"]
        textRequest.recognitionLevel = .fast
        textRequest.usesLanguageCorrection = false
        textRequest.minimumTextHeight = 0.01

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([textRequest])
        } catch {
            return nil
        }

        let output = textRequest.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard let output, !output.isEmpty else { return nil }
        return output
    }
}
