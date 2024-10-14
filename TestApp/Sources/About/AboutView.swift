//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AboutView: View {
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 20) {
                    versionSection
                    copyrightSection
                    acknowledgementsSection
                }
                .padding(.horizontal, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("About the Readium Swift Toolkit")
        }
    }
    
    private var versionSection: some View {
        AboutSectionView(title: "Version") {
            VStack(spacing: 16) {
                HStack {
                    Text("App Version:")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(.appVersion ?? "")
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 10) {
                    Text("Build Version:")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(.buildVersion ?? "")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var copyrightSection: some View {
        AboutSectionView(title: "Copyright") {
            VStack(alignment: .leading, spacing: 16) {
                Link(destination: URL(string: "https://www.edrlab.org/")!) {
                    Text("© 2022 European Digital Reading Lab")
                        .multilineTextAlignment(.leading)
                }
                
                Link(destination: URL(string: "https://opensource.org/licenses/BSD-3-Clause")!) {
                    Text("[BSD-3 License]")
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var acknowledgementsSection: some View {
        AboutSectionView(title: "Acknowledgements") {
            VStack(alignment: .center, spacing: 16) {
                Text("R2 Reader wouldn't have been developed without the financial help of the French State.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                Image("rf")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
