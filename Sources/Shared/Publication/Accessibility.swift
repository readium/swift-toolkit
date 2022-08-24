//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Holds the accessibility metadata of a Publication.
///
/// https://www.w3.org/2021/a11y-discov-vocab/latest/
/// https://readium.org/webpub-manifest/schema/a11y.schema.json
public struct Accessibility: Hashable {
    
    public let conformsTo: [String]
    public let certification: Certification?
    public let localizedSummary: LocalizedString?
    public var summary: String? { localizedSummary?.string }
    public let accessModes: [AccessMode]
    public let accessModesSufficient: [AccessModeSufficient]
    public let features: [Feature]
    public let hazards: [Hazard]

    public struct Certification: Hashable {
        public let certifiedBy: [String]
        public let credentials: [String]
        public let reports: [String]

        public init(certifiedBy: [String] = [], credentials: [String] = [], reports: [String] = []) {
            self.certifiedBy = certifiedBy
            self.credentials = credentials
            self.reports = reports
        }
    }

    public struct AccessMode: Hashable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        public static let auditory = AccessMode("auditory")
        public static let chartOnVisual = AccessMode("chartOnVisual")
        public static let chemOnVisual = AccessMode("chemOnVisual")
        public static let colorDependent = AccessMode("colorDependent")
        public static let mathOnVisual = AccessMode("mathOnVisual")
        public static let tactile = AccessMode("tactile")
        public static let textOnVisual = AccessMode("textOnVisual")
        public static let textual = AccessMode("textual")
        public static let visual = AccessMode("visual")
    }

    public enum AccessModeSufficient: String, Hashable {
        case auditory = "auditory"
        case tactile = "tactile"
        case textual = "textual"
        case visual = "visual"
    }

    public struct Feature: Hashable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        public static let annotations = Feature("annotations")
        public static let aria = Feature("ARIA")
        public static let bookmarks = Feature("bookmarks")
        public static let index = Feature("index")
        public static let printPageNumbers = Feature("printPageNumbers")
        public static let readingOrder = Feature("readingOrder")
        public static let structuralNavigation = Feature("structuralNavigation")
        public static let tableOfContents = Feature("tableOfContents")
        public static let taggedPDF = Feature("taggedPDF")
        public static let alternativeText = Feature("alternativeText")
        public static let audioDescription = Feature("audioDescription")
        public static let captions = Feature("captions")
        public static let describedMath = Feature("describedMath")
        public static let longDescription = Feature("longDescription")
        public static let rubyAnnotations = Feature("rubyAnnotations")
        public static let signLanguage = Feature("signLanguage")
        public static let transcript = Feature("transcript")
        public static let displayTransformability = Feature("displayTransformability")
        public static let synchronizedAudioText = Feature("synchronizedAudioText")
        public static let timingControl = Feature("timingControl")
        public static let unlocked = Feature("unlocked")
        public static let chemML = Feature("ChemML")
        public static let latex = Feature("latex")
        public static let mathML = Feature("MathML")
        public static let ttsMarkup = Feature("ttsMarkup")
        public static let highContrastAudio = Feature("highContrastAudio")
        public static let highContrastDisplay = Feature("highContrastDisplay")
        public static let largePrint = Feature("largePrint")
        public static let braille = Feature("braille")
        public static let tactileGraphic = Feature("tactileGraphic")
        public static let tactileObject = Feature("tactileObject")
        public static let none = Feature("none")
    }

    public struct Hazard: Hashable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        public static let flashing = Hazard("flashing")
        public static let noFlashingHazard = Hazard("noFlashingHazard")
        public static let motionSimulation = Hazard("motionSimulation")
        public static let noMotionSimulationHazard = Hazard("noMotionSimulationHazard")
        public static let sound = Hazard("sound")
        public static let noSoundHazard = Hazard("noSoundHazard")
        public static let unknown = Hazard("unknown")
        public static let none = Hazard("none")
    }

    public init(
        conformsTo: [String] = [],
        certification: Certification? = nil,
        localizedSummary: LocalizedString? = nil,
        accessModes: [AccessMode] = [],
        accessModesSufficient: [AccessModeSufficient] = [],
        features: [Feature] = [],
        hazards: [Hazard] = []
    ) {
        self.conformsTo = conformsTo
        self.certification = certification
        self.localizedSummary = localizedSummary
        self.accessModes = accessModes
        self.accessModesSufficient = accessModesSufficient
        self.features = features
        self.hazards = hazards
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        guard json != nil else {
            return nil
        }
        guard let json = json as? [String: Any] else {
            warnings?.log("Invalid Accessibility object", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            conformsTo: parseArray(json["conformsTo"], allowingSingle: true),
            certification: (json["certification"] as? [String: Any])
                .map {
                    Certification(
                        certifiedBy: parseArray($0["certifiedBy"], allowingSingle: true),
                        credentials: parseArray($0["credential"], allowingSingle: true),
                        reports: parseArray($0["report"], allowingSingle: true)
                    )
                },
            localizedSummary: try? LocalizedString(json: json["summary"], warnings: warnings),
            accessModes: parseArray(json["accessMode"]).map(AccessMode.init),
            accessModesSufficient: parseArray(json["accessModeSufficient"]).compactMap(AccessModeSufficient.init(rawValue:)),
            features: parseArray(json["feature"]).map(Feature.init),
            hazards: parseArray(json["hazard"]).map(Hazard.init)
        )
    }
    
    public var json: [String: Any] {
        makeJSON([
            "conformsTo": encodeIfNotEmpty(conformsTo),
            "certification": encodeIfNotEmpty(certification.map {
                makeJSON([
                    "certifiedBy": encodeIfNotEmpty($0.certifiedBy),
                    "credential": encodeIfNotEmpty($0.credentials),
                    "report": encodeIfNotEmpty($0.reports),
                ])
            }),
            "summary": encodeIfNotNil(localizedSummary?.json),
            "accessMode": encodeIfNotEmpty(accessModes.map(\.id)),
            "accessModeSufficient": encodeIfNotEmpty(accessModesSufficient.map(\.rawValue)),
            "feature": encodeIfNotEmpty(features.map(\.id)),
            "hazard": encodeIfNotEmpty(hazards.map(\.id)),
        ])
    }
}
