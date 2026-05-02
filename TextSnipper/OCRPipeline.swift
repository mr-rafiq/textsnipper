// OCRPipeline.swift
// Runs OCR and QR detection, copies best result to clipboard.

import AppKit
import ImageIO
import UniformTypeIdentifiers
import Vision

enum OCRPipelineResult: Equatable, Sendable {
    case recognized(String)
    case missingTesseract
    case missingTesseractLanguages([String])
    case noTextRecognized

    var text: String? {
        guard case .recognized(let text) = self else { return nil }
        return text
    }
}

enum OCRPipeline {
    static func recognize(image: NSImage) async -> OCRPipelineResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .noTextRecognized }
        return await Task.detached(priority: .userInitiated) {
            recognize(cgImage: cgImage, options: .default)
        }.value
    }

    nonisolated private static func recognize(cgImage: CGImage, options: OCRRecognitionOptions) -> OCRPipelineResult {
        guard !Task.isCancelled else { return .noTextRecognized }

        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.qr]

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([barcodeRequest])
        } catch {
            return .noTextRecognized
        }

        if let payload = barcodeRequest.results?.first?.payloadStringValue, !payload.isEmpty {
            return .recognized(payload)
        }

        guard !Task.isCancelled else { return .noTextRecognized }

        var recognizedOutputs = [String]()
        let visionSupportedIDs = OCRLanguageCatalog.supportedVisionLanguageIDs(
            usesAccurateRecognition: options.usesAccurateRecognition
        )
        if let visionOutput = recognizeTextWithVision(cgImage: cgImage, options: options) {
            recognizedOutputs.append(visionOutput)
        }

        if options.languageIDs.contains(where: { !visionSupportedIDs.contains($0) }),
           case .success(let tesseractOutput) = recognizeTextWithTesseract(cgImage: cgImage, options: options),
           !tesseractOutput.isEmpty,
           !recognizedOutputs.contains(tesseractOutput) {
            recognizedOutputs.insert(tesseractOutput, at: 0)
        }

        let output = recognizedOutputs
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if !output.isEmpty {
            return .recognized(output)
        }

        let tesseractStatus = tesseractReadinessStatus(options: options, visionSupportedIDs: visionSupportedIDs)
        switch tesseractStatus {
        case .ready:
            return .noTextRecognized
        case .missingExecutable:
            return .missingTesseract
        case .missingLanguages(let languageNames):
            return .missingTesseractLanguages(languageNames)
        }
    }

    nonisolated private static func recognizeTextWithVision(cgImage: CGImage, options: OCRRecognitionOptions) -> String? {
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = options.usesAccurateRecognition ? .accurate : .fast
        textRequest.recognitionLanguages = OCRLanguageCatalog.visionLanguageIDs(
            from: options.languageIDs,
            usesAccurateRecognition: options.usesAccurateRecognition
        )
        textRequest.usesLanguageCorrection = true
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

    nonisolated private enum TesseractRecognitionResult {
        case success(String)
        case missingExecutable
        case missingLanguages([String])
        case failed
    }

    nonisolated private enum TesseractReadinessStatus {
        case ready
        case missingExecutable
        case missingLanguages([String])
    }

    nonisolated private static func recognizeTextWithTesseract(cgImage: CGImage, options: OCRRecognitionOptions) -> TesseractRecognitionResult {
        guard let executableURL = tesseractExecutableURL() else { return .missingExecutable }

        let visionSupportedIDs = OCRLanguageCatalog.supportedVisionLanguageIDs(
            usesAccurateRecognition: options.usesAccurateRecognition
        )
        let selectedLanguages = OCRLanguageCatalog
            .selectedLanguages(from: options.languageIDs)
            .filter { !visionSupportedIDs.contains($0.id) }
        let selectedCodesByName = selectedLanguages.compactMap { language -> (String, String)? in
            guard let code = language.tesseractCode else { return nil }
            return (code, language.name)
        }
        let installedCodes = installedTesseractLanguageCodes(executableURL: executableURL)
        let installedSelectedCodes = selectedCodesByName.map(\.0)
            .filter { installedCodes.contains($0) }

        guard !installedSelectedCodes.isEmpty else {
            return .missingLanguages(["Tamil", "Hindi"])
        }

        guard let imageURL = writeTemporaryPNG(cgImage: cgImage) else { return .failed }
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let languageArguments = tesseractLanguageArguments(from: installedSelectedCodes)
        let outputs = languageArguments.flatMap { languageArgument in
            ["6", "7", "8", "13"].compactMap { pageSegmentationMode in
                runTesseract(
                    executableURL: executableURL,
                    imageURL: imageURL,
                    languageArgument: languageArgument,
                    pageSegmentationMode: pageSegmentationMode
                )
            }
        }

        guard let bestOutput = outputs.max(by: { $0.count < $1.count }), !bestOutput.isEmpty else {
            return .failed
        }

        return .success(bestOutput)
    }

    nonisolated private static func tesseractReadinessStatus(options: OCRRecognitionOptions, visionSupportedIDs: Set<String>) -> TesseractReadinessStatus {
        guard let executableURL = tesseractExecutableURL() else { return .missingExecutable }

        let selectedLanguages = OCRLanguageCatalog
            .selectedLanguages(from: options.languageIDs)
            .filter { !visionSupportedIDs.contains($0.id) }
        let selectedCodesByName = selectedLanguages.compactMap { language -> (String, String)? in
            guard let code = language.tesseractCode else { return nil }
            return (code, language.name)
        }
        let installedCodes = installedTesseractLanguageCodes(executableURL: executableURL)
        let hasAnyFallbackLanguage = selectedCodesByName.contains { installedCodes.contains($0.0) }

        if hasAnyFallbackLanguage {
            return .ready
        }

        return .missingLanguages(["Tamil", "Hindi"])
    }

    nonisolated private static func tesseractLanguageArguments(from installedCodes: [String]) -> [String] {
        let preferredGroups = [
            ["tam"],
            ["hin"],
            ["tam", "eng"],
            ["hin", "eng"],
            ["tam", "hin", "eng"],
            ["tam", "hin", "tel", "kan", "mal", "ben", "mar", "guj", "pan", "urd"]
        ]

        var arguments = preferredGroups
            .map { group in group.filter { installedCodes.contains($0) } }
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: "+") }

        let installedArgument = installedCodes.joined(separator: "+")
        if !installedArgument.isEmpty {
            arguments.append(installedArgument)
        }

        var seen = Set<String>()
        return arguments.filter { seen.insert($0).inserted }
    }

    nonisolated private static func runTesseract(
        executableURL: URL,
        imageURL: URL,
        languageArgument: String,
        pageSegmentationMode: String
    ) -> String? {
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            imageURL.path,
            "stdout",
            "-l",
            languageArgument,
            "--psm",
            pageSegmentationMode
        ]
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        process.environment = tesseractEnvironment()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func tesseractExecutableURL() -> URL? {
        if let bundledURL = Bundle.main.url(forResource: "tesseract", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL
        }

        let environmentPath = ProcessInfo.processInfo.environment["TESSERACT_PATH"]
        let candidates = [
            environmentPath,
            "/opt/homebrew/bin/tesseract",
            "/usr/local/bin/tesseract",
            "/usr/bin/tesseract"
        ].compactMap { $0 }

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    nonisolated private static func tesseractEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment

        if environment["TESSDATA_PREFIX"] == nil,
           let tessdataURL = tessdataDirectoryURL() {
            environment["TESSDATA_PREFIX"] = tessdataURL.path
        }

        return environment
    }

    nonisolated private static func tessdataDirectoryURL() -> URL? {
        let candidateURLs = [
            Bundle.main.resourceURL?.appendingPathComponent("tessdata"),
            URL(fileURLWithPath: "/opt/homebrew/share/tessdata"),
            URL(fileURLWithPath: "/usr/local/share/tessdata"),
            URL(fileURLWithPath: "/usr/share/tessdata")
        ].compactMap { $0 }

        return candidateURLs.first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    nonisolated private static func installedTesseractLanguageCodes(executableURL: URL) -> Set<String> {
        var languageCodes = installedTessdataFileCodes()

        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--list-langs"]
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        process.environment = tesseractEnvironment()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return languageCodes
        }

        guard process.terminationStatus == 0 else { return languageCodes }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        languageCodes.formUnion(
            output
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("List of available languages") }
        )
        return languageCodes
    }

    nonisolated private static func installedTessdataFileCodes() -> Set<String> {
        let candidateURLs = [
            Bundle.main.resourceURL?.appendingPathComponent("tessdata"),
            URL(fileURLWithPath: "/opt/homebrew/share/tessdata"),
            URL(fileURLWithPath: "/usr/local/share/tessdata"),
            URL(fileURLWithPath: "/usr/share/tessdata")
        ].compactMap { $0 }

        return Set(
            candidateURLs.flatMap { tessdataURL in
                (try? FileManager.default.contentsOfDirectory(
                    at: tessdataURL,
                    includingPropertiesForKeys: nil
                )) ?? []
            }
            .filter { $0.pathExtension == "traineddata" }
            .map { $0.deletingPathExtension().lastPathComponent }
        )
    }

    nonisolated private static func writeTemporaryPNG(cgImage: CGImage) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextSnipper-\(UUID().uuidString)")
            .appendingPathExtension("png")

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return url
    }
}
