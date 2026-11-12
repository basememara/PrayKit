//
//  ConstantsTests.swift
//  PrayKitTests
//
//  Created by Basem Emara on 2026-11-12.
//  Copyright © 2026 Zamzam Inc. All rights reserved.
//

import Foundation
import PrayCore
import Testing

struct ConstantsTests {
    @Test
    func theStoreAddressEndsInTheAppsID() throws {
        let address = try #require(URL(string: "https://example.com"))

        let constants = Constants(
            isDebug: true,
            itunesName: "example",
            itunesID: "989923828",
            email: "help@example.com",
            twitter: "example",
            instagram: "example",
            websiteURL: address,
            partnerUrl: address,
            privacyURL: address,
            disclaimerURL: address,
            subscribeURL: address,
            logURL: address,
            calculationMethodHelpURL: address,
            bgRefreshTaskID: "refresh",
            bgProcessingTaskID: "processing",
            bgActivityCleanupTaskID: "cleanup",
            iCloudContainerID: "container",
            stripePublishableKey: "key",
            stripeApplePayMerchantId: "merchant",
            donationApiUrl: address,
            preferredLocalizations: ["en"]
        )

        #expect(constants.itunesURL.absoluteString == "https://itunes.apple.com/app/id989923828")
    }
}
