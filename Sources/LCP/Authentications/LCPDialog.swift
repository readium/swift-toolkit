//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

/// A SwiftUI dialog used to prompt the user for its LCP passphrase.
///
/// You can use ``LCPDialog`` with an ``LCPObservableAuthentication`` to
/// implement the whole LCP authentication flow in SwiftUI.
///
/// ```
/// import ReadiumLCP
///
/// @main
/// struct MyApp: App {
///     private let lcpService: LCPService
///     private let publicationOpener: PublicationOpener
///
///     @StateObject private var lcpAuthentication: LCPObservableAuthentication
///
///     init() {
///         let lcpAuthentication = LCPObservableAuthentication()
///         _lcpAuthentication = StateObject(wrappedValue: lcpAuthentication)
///
///         lcpService = LCPService(...)
///
///         publicationOpener = PublicationOpener(
///            ...,
///            contentProtections: [
///                lcpService.contentProtection(with: lcpAuthentication)
///            ]
///         )
///     }
///
///    var body: some Scene {
///        WindowGroup {
///            ContentView()
///                .sheet(item: $lcpAuthentication.request) {
///                    LCPDialog(request: $0)
///                }
///            }
///        }
///    }
/// }
/// ```
@available(iOS 16.0, *)
public struct LCPDialog: View {
    public enum ErrorMessage {
        case incorrectPassphrase

        var string: String {
            switch self {
            case .incorrectPassphrase:
                ReadiumLCPLocalizedString("dialog.error.incorrectPassphrase")
            }
        }
    }

    public var id: LCPDialog { self }

    private let hint: String?
    private let errorMessage: ErrorMessage?
    private let onSubmit: (String) -> Void
    private let onForgotPassphrase: (() -> Void)?

    private let openButtonId = "open"

    public init(
        hint: String?,
        errorMessage: ErrorMessage?,
        onSubmit: @escaping (String) -> Void,
        onForgotPassphrase: (() -> Void)?
    ) {
        self.hint = hint
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
        self.onForgotPassphrase = onForgotPassphrase
    }

    public init(
        request: LCPObservableAuthentication.Request
    ) {
        self.init(
            hint: request.license.hint.orNilIfBlank(),
            errorMessage: request.reason == .invalidPassphrase ? .incorrectPassphrase : nil,
            onSubmit: { passphrase in
                request.submit(passphrase)
            },
            onForgotPassphrase: request.license.hintLink?.url().map { url in
                { UIApplication.shared.open(url.url) }
            }
        )
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused
    @State private var passphrase: String = ""

    public var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                Form {
                    header
                    input
                    buttons
                }
                .onAppear {
                    isFieldFocused = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    // Wait for the @StateFocus animation to settle before
                    // scrolling, otherwise it won't work.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            scrollProxy.scrollTo(openButtonId, anchor: .bottom)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(ReadiumLCPLocalizedStringKey("dialog.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ReadiumLCPLocalizedStringKey("dialog.cancel"), role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder private var header: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "lock.document.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 70))

                    Text(ReadiumLCPLocalizedStringKey("dialog.header"))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                }
                Spacer()
            }

            DisclosureGroup(ReadiumLCPLocalizedStringKey("dialog.details.title")) {
                VStack {
                    Text(ReadiumLCPLocalizedStringKey("dialog.details.body"))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("[\(ReadiumLCPLocalizedString("dialog.details.more"))](https://www.edrlab.org/readium-lcp/)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in
            0
        }
        .font(.callout)
    }

    @ViewBuilder private var input: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField(text: $passphrase) {
                    Text(ReadiumLCPLocalizedStringKey("dialog.passphrase.placeholder"))
                }
                .textInputAutocapitalization(.never)
                .focused($isFieldFocused)
                .submitLabel(.continue)
                .onSubmit {
                    submit()
                }

                if let errorMessage = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                        Text(errorMessage.string)
                    }
                    .foregroundStyle(.red)
                    .font(.callout)
                }
            }
        }
        .listRowSeparator(.hidden)
    }

    @ViewBuilder private var buttons: some View {
        Section {
            Button(ReadiumLCPLocalizedStringKey("dialog.continue")) {
                submit()
            }
            .bold()
            .id(openButtonId)
            .disabled(passphrase.isEmpty)
            .frame(maxWidth: .infinity, alignment: .center)
        }

        if let onForgotPassphrase = onForgotPassphrase {
            Section {
                Button(ReadiumLCPLocalizedStringKey("dialog.forgotYourPassphrase"), role: .destructive) {
                    onForgotPassphrase()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } footer: {
                if let hint = hint {
                    Text(ReadiumLCPLocalizedStringKey("dialog.hint", hint))
                }
            }
        }
    }

    private func submit() {
        guard !passphrase.isEmpty else {
            return
        }

        onSubmit(passphrase)
        dismiss()
    }
}

#Preview {
    if #available(iOS 18.0, *) {
        Spacer().sheet(isPresented: .constant(true)) {
            LCPDialog(
                hint: "Visit your library to know your password",
                errorMessage: .incorrectPassphrase,
                onSubmit: { _ in },
                onForgotPassphrase: {}
            )
        }
    }
}
