//
//  AdhanSound.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-29.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSFileManager
import Foundation.NSURL

public enum AdhanSound: String, CaseIterable, Codable, Sendable {
    case abdulBasit = "abdul.basit"
    case abdulGhaffar = "abdul.ghaffar"
    case abdulHakam = "abdul.hakam"
    case abdulNasirHarak = "abdul.nasir.harak"
    case abdulazizBinMajid = "abdulaziz.bin.majid"
    case abdulrahmanAlHindi = "abdulrahman.al.hindi"
    case ahmadAlBatal = "ahmad.al.batal"
    case ahmedAlNufais = "ahmed.al.nufais"
    case alAqsa = "al.aqsa"
    case alDaghreeri = "al.daghreeri"
    case alHosari = "al.hosari"
    case alHossaini = "al.hossaini"
    case alImadiQatar = "al.imadi.qatar"
    case alJazairi = "al.jazairi"
    case alMarooshMorocco = "al.maroosh.morocco"
    case alSurayhi = "al.surayhi"
    case aliBarraqTunis = "ali.barraq.tunis"
    case azzamDweik = "azzam.dweik"
    case bakirBash = "bakir.bash"
    case cairo
    case egypt
    case fatihSeferagic = "fatih.seferagic"
    case hafez
    case hafizMurad = "hafiz.murad"
    case halab
    case ibrahimJabar = "ibrahim.jabar"
    case kareemMansouryShia = "kareem.mansoury.shia"
    case kuwait
    case madina
    case makkah
    case mansourAlZahrani = "mansour.al.zahrani"
    case maroufAlShareef = "marouf.al.shareef"
    case menshawi
    case misharyAlAfasy = "mishary.al.afasy"
    case misharyAlAfasy2 = "mishary.al.afasy2"
    case mohammadRefaat = "mohammad.refaat"
    case mohammedAlBanna = "mohammed.al.banna"
    case muhammadQassas = "muhammad.qassas"
    case morocco = "morocco"
    case mustaphaWaleed = "mustapha.waleed"
    case muzammilHasaballah = "muzammil.hasaballah"
    case naghshbandi
    case nasserAlQatami = "nasser.al.qatami"
    case oman
    case saber
    case sharifDoman = "sharif.doman"
    case shuffle
    case turkiye
    case yusufIslam = "yusuf.islam"
}

// MARK: - Conformances

extension AdhanSound: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Types

public extension AdhanSound {
    enum Length: CaseIterable, Sendable {
        case short
        case long
        case fajr
    }
}

// MARK: - Helpers

public extension AdhanSound {
    static var `default`: Self { .alAqsa }

    /// The adhans a shuffle draws from: every one but the shuffle itself and the Shia adhan, which a user hears only
    /// by choosing it.
    static var shuffleChoices: [Self] { allCases.filter { ![.shuffle, .kareemMansouryShia].contains($0) } }

    var hasFajr: Bool {
        [
            .alAqsa,
            .alSurayhi,
            .bakirBash,
            .cairo,
            .ibrahimJabar,
            .kuwait,
            .madina,
            .makkah,
            .mansourAlZahrani,
            .misharyAlAfasy,
            .misharyAlAfasy2,
            .muhammadQassas
        ].contains(self)
    }

    func file(for length: Length) -> String {
        file(for: length) { FileManager.default.fileExists(atPath: URL.sound(named: $0).path) }
    }

    func fileURL(for length: Length) -> URL? {
        URL.sound(named: file(for: length))
    }
}

extension AdhanSound {
    /// A shuffle draws only from the adhans whose file in that length is already on the device, so it never downloads
    /// one and never names a file a notification would replace with the system sound. The length matters: a Mac ships
    /// every short adhan but downloads the full ones. A process that can't see the app's sounds, such as an extension
    /// that reschedules, finds none and takes the default adhan, the one that ships in the app.
    func file(for length: Length, isOnDevice: (String) -> Bool) -> String {
        guard case .shuffle = self else { return name(for: length) }

        // Shuffled first, so each adhan on the device is as likely as any other and the check stops at the first
        return Self.shuffleChoices
            .shuffled()
            .lazy
            .map { $0.name(for: length) }
            .first(where: isOnDevice) ?? Self.default.name(for: length)
    }
}

private extension AdhanSound {
    func name(for length: Length) -> String {
        switch length {
        case .short:
            "\(rawValue)-short.m4a"
        case .long:
            "\(rawValue).mp3"
        case .fajr:
            hasFajr ? "\(rawValue)-fajr.mp3" : "\(rawValue).mp3"
        }
    }
}
