//
//  AdhanSound.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-29.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSURL

public enum AdhanSound: String, CaseIterable, Codable {
    case abdulBasit = "abdul.basit"
    case abdulGhaffar = "abdul.ghaffar"
    case abdulHakam = "abdul.hakam"
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
    case misharyAlAfasyFajr = "mishary.al.afasy.fajr"
    case mohammadRefaat = "mohammad.refaat"
    case mohammedAlBanna = "mohammed.al.banna"
    case morocco = "morocco"
    case mustaphaWaleed = "mustapha.waleed"
    case muzammilHasaballah = "muzammil.hasaballah"
    case naghshbandi
    case nasserAlQatami = "nasser.al.qatami"
    case oman
    case saber
    case sharifDoman = "sharif.doman"
    case shuffle
    case yusufIslam = "yusuf.islam"
}

// MARK: - Conformances

extension AdhanSound: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Types

public extension AdhanSound {
    enum Length: CaseIterable {
        case short
        case long
        case fajr
    }
}

// MARK: - Helpers

public extension AdhanSound {
    static var `default`: Self { .alAqsa }

    private var selectedCase: Self {
        var value = self

        if case .shuffle = self, let element = Self.allCases.randomElement() {
            value = element
        }

        return value
    }

    var hasFajr: Bool {
        [
            .alAqsa,
            .bakirBash,
            .cairo,
            .ibrahimJabar,
            .kuwait,
            .madina,
            .makkah,
            .mansourAlZahrani,
            .misharyAlAfasy,
            .misharyAlAfasyFajr
        ].contains(self)
    }

    func file(for length: Length) -> String {
        let value = selectedCase
        let name: String

        switch length {
        case .short:
            name = "\(value.rawValue)-short.m4a"
        case .long:
            name = "\(value.rawValue).mp3"
        case .fajr:
            name = hasFajr
                ? "\(value.rawValue)-fajr.mp3"
                : "\(value.rawValue).mp3"
        }

        return name
    }

    func fileURL(for length: Length) -> URL? {
        let value = selectedCase
        let file = value.file(for: length)

        return value == .default
            ? Bundle.main.url(forResource: file, withExtension: nil)
            : FileManager.default
                .urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Sounds")
                .appendingPathComponent(file)
    }
}
