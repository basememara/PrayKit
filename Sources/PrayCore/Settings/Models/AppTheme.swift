//
//  AppTheme.swift
//  PrayCore
//
//  Created by Basem Emara on 2022-07-16.
//  Copyright © 2021 Zamzam Inc. All rights reserved.
//

public enum AppTheme: String, Equatable, CaseIterable, Codable {
    case `default`
    case web3
    case aqua
    case dawn
    case calm
    case indigo
}

extension AppTheme: Identifiable {
    public var id: String { rawValue }
}
