//
//  AppearanceMode.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-10-01.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public enum AppearanceMode: String, Equatable, CaseIterable, Codable {
    case system
    case light
    case dark
}

extension AppearanceMode: Identifiable {
    public var id: String { rawValue }
}
