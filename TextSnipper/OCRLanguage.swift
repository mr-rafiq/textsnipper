// OCRLanguage.swift
// Defines the automatic OCR language set used by the OCR pipeline.

import Foundation
import Vision

struct OCRLanguage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let nativeName: String
    let flag: String
    let tesseractCode: String?

    var displayName: String {
        nativeName.isEmpty || nativeName == name ? name : "\(name) (\(nativeName))"
    }
}

struct OCRLanguageSection: Identifiable, Sendable {
    let id: String
    let title: String
    let languages: [OCRLanguage]
}

struct OCRRecognitionOptions: Equatable, Sendable {
    var languageIDs: [String]
    var usesAccurateRecognition: Bool

    nonisolated static let `default` = OCRRecognitionOptions(
        languageIDs: OCRLanguageCatalog.defaultLanguageIDs,
        usesAccurateRecognition: true
    )
}

enum OCRLanguageCatalog {
    nonisolated static let visionFallbackLanguageIDs = ["en-US"]

    nonisolated static let sections: [OCRLanguageSection] = [
        OCRLanguageSection(id: "common", title: "Common Languages", languages: [
            OCRLanguage(id: "en-US", name: "English", nativeName: "English", flag: "🇺🇸", tesseractCode: "eng"),
            OCRLanguage(id: "es-ES", name: "Spanish", nativeName: "Español", flag: "🇪🇸", tesseractCode: "spa"),
            OCRLanguage(id: "fr-FR", name: "French", nativeName: "Français", flag: "🇫🇷", tesseractCode: "fra"),
            OCRLanguage(id: "de-DE", name: "German", nativeName: "Deutsch", flag: "🇩🇪", tesseractCode: "deu"),
            OCRLanguage(id: "pt-BR", name: "Portuguese", nativeName: "Português", flag: "🇵🇹", tesseractCode: "por"),
            OCRLanguage(id: "it-IT", name: "Italian", nativeName: "Italiano", flag: "🇮🇹", tesseractCode: "ita"),
            OCRLanguage(id: "zh-Hans", name: "Chinese", nativeName: "简体中文", flag: "🇨🇳", tesseractCode: "chi_sim"),
            OCRLanguage(id: "ja-JP", name: "Japanese", nativeName: "日本語", flag: "🇯🇵", tesseractCode: "jpn"),
            OCRLanguage(id: "ko-KR", name: "Korean", nativeName: "한국어", flag: "🇰🇷", tesseractCode: "kor"),
            OCRLanguage(id: "ru-RU", name: "Russian", nativeName: "Русский", flag: "🇷🇺", tesseractCode: "rus"),
            OCRLanguage(id: "vi-VT", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳", tesseractCode: "vie"),
            OCRLanguage(id: "th-TH", name: "Thai", nativeName: "ไทย", flag: "🇹🇭", tesseractCode: "tha"),
            OCRLanguage(id: "uk-UA", name: "Ukrainian", nativeName: "Українська", flag: "🇺🇦", tesseractCode: "ukr"),
            OCRLanguage(id: "ar-SA", name: "Arabic", nativeName: "العربية", flag: "🇸🇦", tesseractCode: "ara"),
            OCRLanguage(id: "ro-RO", name: "Romanian", nativeName: "Română", flag: "🇷🇴", tesseractCode: "ron"),
            OCRLanguage(id: "ms-MY", name: "Malay", nativeName: "Bahasa Melayu", flag: "🇲🇾", tesseractCode: "msa"),
            OCRLanguage(id: "tr-TR", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷", tesseractCode: "tur"),
            OCRLanguage(id: "id-ID", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩", tesseractCode: "ind"),
            OCRLanguage(id: "cs-CZ", name: "Czech", nativeName: "Čeština", flag: "🇨🇿", tesseractCode: "ces"),
            OCRLanguage(id: "da-DK", name: "Danish", nativeName: "Dansk", flag: "🇩🇰", tesseractCode: "dan"),
            OCRLanguage(id: "nl-NL", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱", tesseractCode: "nld"),
            OCRLanguage(id: "nb-NO", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴", tesseractCode: "nor"),
            OCRLanguage(id: "pl-PL", name: "Polish", nativeName: "Polski", flag: "🇵🇱", tesseractCode: "pol"),
            OCRLanguage(id: "sv-SE", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪", tesseractCode: "swe")
        ]),
        OCRLanguageSection(id: "indian", title: "Indian Languages", languages: [
            OCRLanguage(id: "hi-IN", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳", tesseractCode: "hin"),
            OCRLanguage(id: "ta-IN", name: "Tamil", nativeName: "தமிழ்", flag: "🇮🇳", tesseractCode: "tam"),
            OCRLanguage(id: "te-IN", name: "Telugu", nativeName: "తెలుగు", flag: "🇮🇳", tesseractCode: "tel"),
            OCRLanguage(id: "kn-IN", name: "Kannada", nativeName: "ಕನ್ನಡ", flag: "🇮🇳", tesseractCode: "kan"),
            OCRLanguage(id: "ml-IN", name: "Malayalam", nativeName: "മലയാളം", flag: "🇮🇳", tesseractCode: "mal"),
            OCRLanguage(id: "bn-IN", name: "Bengali", nativeName: "বাংলা", flag: "🇮🇳", tesseractCode: "ben"),
            OCRLanguage(id: "mr-IN", name: "Marathi", nativeName: "मराठी", flag: "🇮🇳", tesseractCode: "mar"),
            OCRLanguage(id: "gu-IN", name: "Gujarati", nativeName: "ગુજરાતી", flag: "🇮🇳", tesseractCode: "guj"),
            OCRLanguage(id: "pa-IN", name: "Punjabi", nativeName: "ਪੰਜਾਬੀ", flag: "🇮🇳", tesseractCode: "pan"),
            OCRLanguage(id: "ur-IN", name: "Urdu", nativeName: "اردو", flag: "🇮🇳", tesseractCode: "urd")
        ])
    ]

    nonisolated static var allLanguages: [OCRLanguage] {
        sections.flatMap(\.languages)
    }

    nonisolated static var defaultLanguageIDs: [String] {
        allLanguages.map(\.id)
    }

    nonisolated static func supportedVisionLanguageIDs(usesAccurateRecognition: Bool) -> Set<String> {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = usesAccurateRecognition ? .accurate : .fast
        return Set((try? request.supportedRecognitionLanguages()) ?? visionFallbackLanguageIDs)
    }

    nonisolated static func visionLanguageIDs(from selectedIDs: [String], usesAccurateRecognition: Bool) -> [String] {
        let supported = supportedVisionLanguageIDs(usesAccurateRecognition: usesAccurateRecognition)
        let selectedSupported = selectedIDs.filter { supported.contains($0) }
        return selectedSupported.isEmpty ? visionFallbackLanguageIDs : selectedSupported
    }

    nonisolated static func selectedLanguages(from ids: [String]) -> [OCRLanguage] {
        ids.compactMap { id in
            allLanguages.first { $0.id == id }
        }
    }
}
