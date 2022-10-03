//
//  NotificationSound.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-06-14.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

import Foundation.NSURL

public enum NotificationSound: String, Equatable, CaseIterable, Codable {
    case adhan
    case adventureLong = "adventure-long"
    case adventure
    case alalhuYaRabbi = "alalhu.ya.rabbi"
    case alarmBeatsLong = "alarm.beats-long"
    case alarmBeats = "alarm.beats"
    case alert
    case allahsNames = "allahs.names"
    case allahuAkbar = "allahu.akbar"
    case allahuYaAllahLong = "allahu.ya.allah-long"
    case allahuYaAllah = "allahu.ya.allah"
    case beep
    case bismillah1
    case bismillah2
    case bismillahilladhi
    case chime
    case chimesLong = "chimes-long"
    case chimes
    case circles
    case drums
    case ertugrulLong = "ertugrul-long"
    case ertugrul
    case ertugrul2Flute = "ertugrul2.flute"
    case ertugrul2
    case ertugrul3
    case fajrLong = "fajr-long"
    case fajr
    case galaxy
    case hasbiAllah = "hasbi.allah"
    case highLong = "high-long"
    case high
    case kalima
    case labbaikAllah = "labbaik-allahuma"
    case march
    case message
    case morning
    case presto
    case ring
    case sciFiBeatLong = "sci.fi.beat-long"
    case sciFiBeat = "sci.fi.beat"
    case sciFi = "sci.fi"
    case shahada
    case sonarLong = "sonar-long"
    case sonar
    case subhanallah1
    case subhanallah2
    case takbeerEid = "takbeer-eid"
    case tone
    case tones
    case trickle
    case tweet
    case ufoLong = "ufo-long"
    case ufo
    case wakeUpLong = "wake.up-long"
    case wakeUp = "wake.up"
    case winds
    case xylophone
    case silent
    case off
}

// MARK: - Conformances

extension NotificationSound: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Helpers

public extension NotificationSound {
    static var `default`: Self { .tone }

    var file: String? {
        switch self {
        case .adhan, .silent, .off:
            return nil
        default:
            return "\(rawValue).m4a"
        }
    }

    var fileURL: URL? {
        guard let file else { return nil }
        return self == .default
            ? Bundle.main.url(forResource: file, withExtension: nil)
            : FileManager.default
                .urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Sounds")
                .appendingPathComponent(file)
    }
}

public extension NotificationSound {
    var icon: String {
        switch self {
        case .adhan:
            return "mic"
        case .adventureLong:
            return "photo"
        case .adventure:
            return "photo"
        case .alalhuYaRabbi:
            return "arrow.up.heart"
        case .alarmBeatsLong:
            return "music.quarternote.3"
        case .alarmBeats:
            return "music.quarternote.3"
        case .alert:
            return "bell"
        case .allahsNames:
            return "arrow.up.heart"
        case .allahuAkbar:
            return "arrow.up.heart"
        case .allahuYaAllahLong:
            return "arrow.up.heart"
        case .allahuYaAllah:
            return "arrow.up.heart"
        case .beep:
            return "speaker.wave.1"
        case .bismillah1:
            return "arrow.up.heart"
        case .bismillah2:
            return "arrow.up.heart"
        case .bismillahilladhi:
            return "arrow.up.heart"
        case .chime:
            return "phone.and.waveform"
        case .chimesLong:
            return "lines.measurement.horizontal"
        case .chimes:
            return "lines.measurement.horizontal"
        case .circles:
            return "circlebadge.2"
        case .drums:
            return "music.note"
        case .ertugrulLong:
            return "seal"
        case .ertugrul:
            return "seal"
        case .ertugrul2Flute:
            return "seal"
        case .ertugrul2:
            return "seal"
        case .ertugrul3:
            return "seal"
        case .fajrLong:
            return "sunrise"
        case .fajr:
            return "sunrise"
        case .galaxy:
            return "sparkles"
        case .hasbiAllah:
            return "arrow.up.heart"
        case .highLong:
            return "cloud"
        case .high:
            return "cloud"
        case .kalima:
            return "hand.point.up"
        case .labbaikAllah:
            return "person.2.wave.2"
        case .march:
            return "flag"
        case .message:
            return "message.and.waveform"
        case .morning:
            return "sun.and.horizon"
        case .presto:
            return "alarm"
        case .ring:
            return "circle.dotted"
        case .sciFiBeatLong:
            return "camera.filters"
        case .sciFiBeat:
            return "camera.filters"
        case .sciFi:
            return "camera.filters"
        case .shahada:
            return "hand.point.up"
        case .sonarLong:
            return "dot.radiowaves.left.and.right"
        case .sonar:
            return "dot.radiowaves.left.and.right"
        case .subhanallah1:
            return "arrow.up.heart"
        case .subhanallah2:
            return "arrow.up.heart"
        case .takbeerEid:
            return "moon.stars.fill"
        case .tone:
            return "speaker.wave.2"
        case .tones:
            return "speaker.wave.3"
        case .trickle:
            return "drop"
        case .tweet:
            return "music.quarternote.3"
        case .ufoLong:
            return "circle.dashed"
        case .ufo:
            return "circle.dashed"
        case .wakeUpLong:
            return "sun.max"
        case .wakeUp:
            return "sun.max"
        case .winds:
            return "wind"
        case .xylophone:
            return "music.note.list"
        case .silent:
            return "speaker.zzz"
        case .off:
            return "bell.slash"
        }
    }
}
