//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            versionSection
            copyrightSection
            acknowledgementsSection
        }
        .padding(.horizontal, 16)
    }
    
    private var versionSection: some View {
        AboutSectionView(title: "Version") {
            VStack(spacing: 16) {
                HStack {
                    Text("app_version_caption")
                    Spacer()
                    Text(.appVersion ?? "")
                }
                
                HStack(spacing: 10) {
                    Text("build_version_caption").frame(width: 170.0, alignment: .leading)
                    Spacer()
                    Text(.buildVersion ?? "")
                }
            }
        }
    }
    
    private var copyrightSection: some View {
        AboutSectionView(title: "Copyright") {
            VStack(alignment: .leading, spacing: 16) {
                Link("© 2022 European Digital Reading Lab",
                     destination: URL(string: "https://www.edrlab.org/")!)
                Link("[BSD-3 License]",
                     destination: URL(string: "https://opensource.org/licenses/BSD-3-Clause")!)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var acknowledgementsSection: some View {
        AboutSectionView(title: "Acknowledgements") {
            VStack(alignment: .center, spacing: 16) {
                Text("R2 Reader wouldn't have been developed without the financial help of the French State.")
                    .multilineTextAlignment(.center)
                Image("rf")
            }
        }
    }
}

struct About_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}

private extension String {
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    static let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
}
