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
    static func recognize(image: NSImage, includeAdditionalScripts: Bool = false) async -> OCRPipelineResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .noTextRecognized }
        let options = OCRRecognitionOptions.automatic(includeAdditionalScripts: includeAdditionalScripts)
        return await Task.detached(priority: .userInitiated) {
            recognize(cgImage: cgImage, options: options)
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

        if options.usesAdditionalOCRSupport,
           options.languageIDs.contains(where: { !visionSupportedIDs.contains($0) }),
           case .success(let tesseractOutput) = recognizeTextWithTesseract(cgImage: cgImage, options: options),
           !tesseractOutput.isEmpty,
           !recognizedOutputs.contains(tesseractOutput) {
            recognizedOutputs.insert(tesseractOutput, at: 0)
        }

        let output = mergedLineOutput(from: recognizedOutputs) ?? ""

        if !output.isEmpty {
            return .recognized(output)
        }

        guard options.usesAdditionalOCRSupport else {
            return .noTextRecognized
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

    nonisolated private struct TesseractCandidate {
        let text: String
        let languageArgument: String
        let pageSegmentationMode: String
        let averageConfidence: Double
        let wordCount: Int
        let expectedScriptScalarCount: Int
        let unexpectedIndicScalarCount: Int
        let digitScalarCount: Int
        let letterScalarCount: Int
        let scriptScalarCounts: [OCRScript: Int]
        let lineCount: Int
        let shortLineCount: Int

        var score: Double {
            let wordBonus = min(Double(wordCount) * 1.4, 18)
            let scriptBonus = min(Double(expectedScriptScalarCount) * 1.2, 34)
            let unexpectedPenalty = Double(unexpectedIndicScalarCount) * 4.5
            let digitRatio = letterScalarCount == 0 ? 0 : Double(digitScalarCount) / Double(letterScalarCount)
            let digitPenalty = digitRatio > 0.18 ? digitRatio * 36 : 0
            let languagePenalty = Double(max(0, languageArgument.split(separator: "+").count - 2)) * 3
            let fragmentedLinePenalty = lineCount >= 8 ? Double(shortLineCount) * 2 : 0
            let pageSegmentationPenalty = pageSegmentationMode == "11" ? 16 : 0

            let bonus = wordBonus + scriptBonus
            let penalty = unexpectedPenalty + digitPenalty + languagePenalty + fragmentedLinePenalty + Double(pageSegmentationPenalty)
            return averageConfidence + bonus - penalty
        }

        func scriptScalarCount(for languageCode: String) -> Int {
            guard let expectedScript = OCRScript.languageScript(for: languageCode) else { return 0 }
            return text.unicodeScalars.filter { OCRScript.script(for: $0) == expectedScript }.count
        }
    }

    nonisolated private enum OCRScript: Hashable {
        case arabic
        case bengali
        case devanagari
        case gujarati
        case gurmukhi
        case kannada
        case latin
        case malayalam
        case tamil
        case telugu

        static func languageScript(for languageCode: String) -> OCRScript? {
            switch languageCode {
            case "ben": return .bengali
            case "eng": return .latin
            case "guj": return .gujarati
            case "hin", "mar": return .devanagari
            case "kan": return .kannada
            case "mal": return .malayalam
            case "pan": return .gurmukhi
            case "tam": return .tamil
            case "tel": return .telugu
            case "urd": return .arabic
            case "script/Arabic": return .arabic
            case "script/Bengali": return .bengali
            case "script/Devanagari": return .devanagari
            case "script/Gujarati": return .gujarati
            case "script/Gurmukhi": return .gurmukhi
            case "script/Kannada": return .kannada
            case "script/Latin": return .latin
            case "script/Malayalam": return .malayalam
            case "script/Tamil": return .tamil
            case "script/Telugu": return .telugu
            default: return nil
            }
        }

        var tesseractScriptModel: String {
            switch self {
            case .arabic: return "script/Arabic"
            case .bengali: return "script/Bengali"
            case .devanagari: return "script/Devanagari"
            case .gujarati: return "script/Gujarati"
            case .gurmukhi: return "script/Gurmukhi"
            case .kannada: return "script/Kannada"
            case .latin: return "script/Latin"
            case .malayalam: return "script/Malayalam"
            case .tamil: return "script/Tamil"
            case .telugu: return "script/Telugu"
            }
        }

        static func script(for scalar: UnicodeScalar) -> OCRScript? {
            switch scalar.value {
            case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F:
                return .latin
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF:
                return .arabic
            case 0x0900...0x097F:
                return .devanagari
            case 0x0980...0x09FF:
                return .bengali
            case 0x0A00...0x0A7F:
                return .gurmukhi
            case 0x0A80...0x0AFF:
                return .gujarati
            case 0x0B80...0x0BFF:
                return .tamil
            case 0x0C00...0x0C7F:
                return .telugu
            case 0x0C80...0x0CFF:
                return .kannada
            case 0x0D00...0x0D7F:
                return .malayalam
            default:
                return nil
            }
        }
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

        let probeCandidates = tesseractProbeLanguageArguments(
            fallbackCodes: installedSelectedCodes,
            installedCodes: installedCodes
        ).flatMap { languageArgument in
            ["6"].compactMap { pageSegmentationMode in
                runTesseractCandidate(
                    executableURL: executableURL,
                    imageURL: imageURL,
                    languageArgument: languageArgument,
                    pageSegmentationMode: pageSegmentationMode
                )
            }
        }

        let primaryCodes = primaryTesseractCodesFromScripts(
            from: probeCandidates,
            fallbackCodes: installedSelectedCodes
        )
        let finalLanguageArguments = tesseractFinalLanguageArguments(
            primaryCodes: primaryCodes,
            installedCodes: installedCodes
        )
        let finalCandidates = finalLanguageArguments.flatMap { languageArgument in
            ["6", "4"].compactMap { pageSegmentationMode in
                runTesseractCandidate(
                    executableURL: executableURL,
                    imageURL: imageURL,
                    languageArgument: languageArgument,
                    pageSegmentationMode: pageSegmentationMode
                )
            }
        }
        let recoveryCandidates = finalCandidates.isEmpty ? finalLanguageArguments.compactMap { languageArgument in
            runTesseractCandidate(
                executableURL: executableURL,
                imageURL: imageURL,
                languageArgument: languageArgument,
                pageSegmentationMode: "11"
            )
        } : []

        let bestCandidate = (finalCandidates + recoveryCandidates + probeCandidates).max { lhs, rhs in
            lhs.score < rhs.score
        }
        guard let bestCandidate, !bestCandidate.text.isEmpty else {
            return .failed
        }

        return .success(bestCandidate.text)
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

    nonisolated private static func tesseractProbeLanguageArguments(
        fallbackCodes: [String],
        installedCodes: Set<String>
    ) -> [String] {
        let fallbackCodes = uniqueCodes(fallbackCodes)
        let scriptModels = uniqueCodes(
            fallbackCodes.compactMap { OCRScript.languageScript(for: $0)?.tesseractScriptModel }
        ).filter { installedCodes.contains($0) }
        let supplementalCodes = ["eng"].filter { installedCodes.contains($0) }

        var languageGroups = [[String]]()
        if !scriptModels.isEmpty {
            languageGroups.append(scriptModels)
        } else {
            languageGroups += fallbackCodes.map { uniqueCodes([$0] + supplementalCodes) }
            languageGroups += fallbackCodes.map { [$0] }
        }

        let arguments = languageGroups
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: "+") }

        var seen = Set<String>()
        return arguments.filter { seen.insert($0).inserted }
    }

    nonisolated private static func primaryTesseractCodesFromScripts(
        from candidates: [TesseractCandidate],
        fallbackCodes: [String]
    ) -> [String] {
        if let broadCandidate = candidates.max(by: { $0.score < $1.score }) {
            let rankedScripts = broadCandidate.scriptScalarCounts
                .filter { $0.key != .latin && $0.value > 0 }
                .sorted { $0.value > $1.value }

            if let topCount = rankedScripts.first?.value {
                let selectedScripts = rankedScripts
                    .filter { $0.value >= max(2, Int(Double(topCount) * 0.35)) }
                    .prefix(2)
                    .map(\.key)
                let selectedCodes = selectedScripts.compactMap { script in
                    fallbackCodes.first { OCRScript.languageScript(for: $0) == script }
                }

                if !selectedCodes.isEmpty {
                    return uniqueCodes(selectedCodes)
                }
            }
        }

        let ranked = uniqueCodes(fallbackCodes).compactMap { code -> (String, TesseractCandidate)? in
            let bestCandidate = candidates
                .filter { $0.languageArgument.split(separator: "+").map(String.init).contains(code) }
                .filter { $0.scriptScalarCount(for: code) > 0 }
                .max { lhs, rhs in lhs.score < rhs.score }

            guard let bestCandidate else { return nil }
            return (code, bestCandidate)
        }
        .sorted { lhs, rhs in lhs.1.score > rhs.1.score }

        guard let topScore = ranked.first?.1.score else {
            return Array(uniqueCodes(fallbackCodes).prefix(1))
        }

        let threshold = max(32, topScore * 0.86)
        let selectedCodes = ranked
            .filter { $0.1.score >= threshold }
            .prefix(2)
            .map(\.0)

        return selectedCodes.isEmpty ? Array(ranked.prefix(1).map(\.0)) : Array(selectedCodes)
    }

    nonisolated private static func tesseractFinalLanguageArguments(
        primaryCodes: [String],
        installedCodes: Set<String>
    ) -> [String] {
        let primaryCodes = uniqueCodes(primaryCodes)
        let scriptModels = uniqueCodes(
            primaryCodes.compactMap { OCRScript.languageScript(for: $0)?.tesseractScriptModel }
        ).filter { installedCodes.contains($0) }
        let supplementalCodes = ["eng"].filter { installedCodes.contains($0) }

        var languageGroups = [[String]]()
        if !scriptModels.isEmpty {
            languageGroups.append(scriptModels)
            languageGroups += scriptModels.map { [$0] }
        } else {
            languageGroups.append(uniqueCodes(primaryCodes + supplementalCodes))
            languageGroups += primaryCodes.map { uniqueCodes([$0] + supplementalCodes) }
        }

        let arguments = languageGroups
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: "+") }

        var seen = Set<String>()
        return arguments.filter { seen.insert($0).inserted }
    }

    nonisolated private static func mergedLineOutput(from outputs: [String]) -> String? {
        let lines = outputs.flatMap { output in
            output
                .split(whereSeparator: \.isNewline)
                .map { normalizedOCRLine(String($0)) }
                .filter { !$0.isEmpty }
        }

        var seen = Set<String>()
        let mergedLines = lines.filter { line in
            let key = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return seen.insert(key).inserted
        }

        guard !mergedLines.isEmpty else { return nil }
        return mergedLines.joined(separator: "\n")
    }

    nonisolated private static func normalizedOCRLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func uniqueCodes(_ codes: [String]) -> [String] {
        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
    }

    nonisolated private static func runTesseractCandidate(
        executableURL: URL,
        imageURL: URL,
        languageArgument: String,
        pageSegmentationMode: String
    ) -> TesseractCandidate? {
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            imageURL.path,
            "stdout",
            "-l",
            languageArgument,
            "--psm",
            pageSegmentationMode,
            "tsv"
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
        guard let tsv = String(data: data, encoding: .utf8) else { return nil }
        return tesseractCandidate(
            fromTSV: tsv,
            languageArgument: languageArgument,
            pageSegmentationMode: pageSegmentationMode
        )
    }

    nonisolated private static func tesseractCandidate(
        fromTSV tsv: String,
        languageArgument: String,
        pageSegmentationMode: String
    ) -> TesseractCandidate? {
        var orderedLineKeys = [String]()
        var wordsByLineKey = [String: [String]]()
        var confidences = [Double]()

        for row in tsv.split(whereSeparator: \.isNewline).dropFirst() {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 12,
                  let confidence = Double(columns[10]),
                  confidence >= 0 else {
                continue
            }

            let text = normalizedOCRLine(columns[11...].joined(separator: " "))
            guard !text.isEmpty else { continue }

            let lineKey = [columns[2], columns[3], columns[4]].joined(separator: ":")
            if wordsByLineKey[lineKey] == nil {
                orderedLineKeys.append(lineKey)
                wordsByLineKey[lineKey] = []
            }
            wordsByLineKey[lineKey]?.append(text)
            confidences.append(confidence)
        }

        let lines = orderedLineKeys.compactMap { key in
            normalizedOCRLine(wordsByLineKey[key]?.joined(separator: " ") ?? "")
        }
        .filter { !$0.isEmpty }

        let text = lines.joined(separator: "\n")
        guard !text.isEmpty, !confidences.isEmpty else { return nil }

        let expectedScripts = Set(
            languageArgument
                .split(separator: "+")
                .compactMap { OCRScript.languageScript(for: String($0)) }
        )
        var expectedScriptScalarCount = 0
        var unexpectedIndicScalarCount = 0
        var digitScalarCount = 0
        var letterScalarCount = 0
        var scriptScalarCounts = [OCRScript: Int]()

        for scalar in text.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                digitScalarCount += 1
            }
            if CharacterSet.letters.contains(scalar) {
                letterScalarCount += 1
            }
            guard let script = OCRScript.script(for: scalar), script != .latin else { continue }
            scriptScalarCounts[script, default: 0] += 1
            if expectedScripts.contains(script) {
                expectedScriptScalarCount += 1
            } else {
                unexpectedIndicScalarCount += 1
            }
        }

        return TesseractCandidate(
            text: text,
            languageArgument: languageArgument,
            pageSegmentationMode: pageSegmentationMode,
            averageConfidence: confidences.reduce(0, +) / Double(confidences.count),
            wordCount: confidences.count,
            expectedScriptScalarCount: expectedScriptScalarCount,
            unexpectedIndicScalarCount: unexpectedIndicScalarCount,
            digitScalarCount: digitScalarCount,
            letterScalarCount: letterScalarCount,
            scriptScalarCounts: scriptScalarCounts,
            lineCount: lines.count,
            shortLineCount: lines.filter { $0.count <= 2 }.count
        )
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
