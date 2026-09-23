//
//  Madhab.swift
//  PrayCore
//
//  Created by Basem Emara on 2021-01-02.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public enum Madhab: String, CaseIterable, Equatable, Codable, Sendable {
    case standard = "Standard"
    case hanafi = "Hanafi"
}

// MARK: - Conformances

extension Madhab: Identifiable {
    public var id: String { rawValue }
}
