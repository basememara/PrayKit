//
//  CalculationMethod.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public enum CalculationMethod: String, Equatable, CaseIterable, Codable {
    case muslimWorldLeague = "MWL"
    case northAmerica = "ISNA"
    case moonsightingCommittee = "Moon"
    case egyptian = "Egypt"
    case algerian = "Algerian"
    case tunisian = "Tunisian"
    case london = "London"
    case ummAlQura = "Makkah"
    case ummAlQuraRamadan = "MakkahRamadan"
    case dubai = "Dubai"
    case kuwait = "Kuwait"
    case qatar = "Qatar"
    case karachi = "Karachi"
    case singapore = "Singapore"
    case jakim = "JAKIM"
    case indonesia = "Indonesia"
    case turkey = "Turkey"
    case morocco = "Morocco"
    case uiof = "UIOF"
    case france15 = "France15"
    case france18 = "France18"
    case russia = "Russia"
    case tehran = "Tehran"
    case shia = "Shia"
    case custom = "Custom"
}

// MARK: - Conformances

extension CalculationMethod: Identifiable {
    public var id: String { rawValue }
}
