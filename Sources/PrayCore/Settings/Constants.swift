//
//  ConstantsStaticService.swift
//  PrayCore
//
//  Created by Basem Emara on 2019-06-11.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation.NSURL
import ZamzamCore

public struct Constants: Distribution {
    public let isDebug: Bool
    public let itunesName: String
    public let itunesID: String
    public let email: String
    public let twitter: String
    public let instagram: String
    public let websiteURL: URL
    public let privacyURL: URL
    public let disclaimerURL: URL
    public let subscribeURL: URL
    public let logURL: URL
    public let calculationMethodHelpURL: URL
    public let bgRefreshTaskID: String
    public let bgProcessingTaskID: String
    public let iCloudContainerID: String
    public let stripePublishableKey: String
    public let stripeApplePayMerchantId: String
    public let donationApiUrl: URL
    public let donationPartnerUrl: URL
    public let preferredLocalizations: [String]
    public let language: String

    public init(
        isDebug: Bool,
        itunesName: String,
        itunesID: String,
        email: String,
        twitter: String,
        instagram: String,
        websiteURL: URL,
        privacyURL: URL,
        disclaimerURL: URL,
        subscribeURL: URL,
        logURL: URL,
        calculationMethodHelpURL: URL,
        bgRefreshTaskID: String,
        bgProcessingTaskID: String,
        iCloudContainerID: String,
        stripePublishableKey: String,
        stripeApplePayMerchantId: String,
        donationApiUrl: URL,
        donationPartnerUrl: URL,
        preferredLocalizations: [String]
    ) {
        self.isDebug = isDebug
        self.itunesName = itunesName
        self.itunesID = itunesID
        self.email = email
        self.twitter = twitter
        self.instagram = instagram
        self.websiteURL = websiteURL
        self.privacyURL = privacyURL
        self.disclaimerURL = disclaimerURL
        self.subscribeURL = subscribeURL
        self.logURL = logURL
        self.calculationMethodHelpURL = calculationMethodHelpURL
        self.bgRefreshTaskID = bgRefreshTaskID
        self.bgProcessingTaskID = bgProcessingTaskID
        self.iCloudContainerID = iCloudContainerID
        self.stripePublishableKey = stripePublishableKey
        self.stripeApplePayMerchantId = stripeApplePayMerchantId
        self.donationApiUrl = donationApiUrl
        self.donationPartnerUrl = donationPartnerUrl
        self.preferredLocalizations = preferredLocalizations

        self.language = (Bundle
            .preferredLocalizations(from: preferredLocalizations)
            .first ?? preferredLocalizations[0])?
            .components(separatedBy: CharacterSet(charactersIn: "-_"))
            .first ?? "en"
    }
}

public extension Constants {
    var itunesURL: URL { URL(safeString: "https://itunes.apple.com/app/id\(itunesID)") }
}
