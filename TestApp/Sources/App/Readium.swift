//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer

#if LCP
    import R2LCPClient
    import ReadiumAdapterLCPSQLite
    import ReadiumLCP
#endif

final class Readium {
    lazy var httpClient: HTTPClient = DefaultHTTPClient()

    lazy var formatSniffer: FormatSniffer = DefaultFormatSniffer()

    lazy var assetRetriever = AssetRetriever(
        httpClient: httpClient
    )

    lazy var publicationOpener = PublicationOpener(
        parser: DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever
        ),
        contentProtections: contentProtections
    )

    #if !LCP
        let contentProtections: [ContentProtection] = []

    #else
        lazy var contentProtections: [ContentProtection] = [
            lcpService.contentProtection(with: lcpAuthentication),
        ]

        lazy var lcpService = LCPService(
            client: LCPClient(),
            licenseRepository: LCPSQLiteLicenseRepository(),
            passphraseRepository: LCPSQLitePassphraseRepository(),
            assetRetriever: assetRetriever,
            httpClient: httpClient
        )

        lazy var lcpAuthentication: LCPAuthenticating = LCPDialogAuthentication()

        /// Facade to the private R2LCPClient.framework.
        class LCPClient: ReadiumLCP.LCPClient {
            func createContext(jsonLicense: String, hashedPassphrase: LCPPassphraseHash, pemCrl: String) throws -> LCPClientContext {
                try R2LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: hashedPassphrase, pemCrl: pemCrl)
            }

            func decrypt(data: Data, using context: LCPClientContext) -> Data? {
                R2LCPClient.decrypt(data: data, using: context as! DRMContext)
            }

            func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [LCPPassphraseHash]) -> LCPPassphraseHash? {
                R2LCPClient.findOneValidPassphrase(jsonLicense: jsonLicense, hashedPassphrases: hashedPassphrases)
            }
        }
    #endif
}
