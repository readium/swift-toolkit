//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
public struct LCPDialog: View {
    public enum ErrorMessage {
        case incorrectPassphrase

        var string: String {
            switch self {
            case .incorrectPassphrase:
                ReadiumLCPLocalizedString("dialog.errors.incorrectPassphrase")
            }
        }
    }

    public var id: LCPDialog { self }

    private let hint: String?
    private let errorMessage: ErrorMessage?
    private let onSubmit: (String) -> Void
    private let onForgotPassphrase: (() -> Void)?
    private let onCancel: (() -> Void)?

    private let openButtonId = "open"

    public init(
        hint: String?,
        errorMessage: ErrorMessage?,
        onSubmit: @escaping (String) -> Void,
        onForgotPassphrase: (() -> Void)?,
        onCancel: (() -> Void)? = nil
    ) {
        self.hint = hint
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
        self.onForgotPassphrase = onForgotPassphrase
        self.onCancel = onCancel
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
        NavigationView {
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
            .scrollDismissesKeyboardIfAvailable()
            .navigationTitle(ReadiumLCPLocalizedStringKey("dialog.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ReadiumLCPLocalizedStringKey("dialog.actions.cancel"), role: .cancel) {
                        onCancel?()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder private var header: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "lock.document.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 70))

                    Text(ReadiumLCPLocalizedStringKey("dialog.message"))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                }
                Spacer()
            }

            DisclosureGroup(ReadiumLCPLocalizedStringKey("dialog.info.title")) {
                VStack {
                    Text(ReadiumLCPLocalizedStringKey("dialog.info.body"))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("[\(ReadiumLCPLocalizedString("dialog.info.more"))](https://www.edrlab.org/readium-lcp/)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .alignListRowSeparatorLeading()
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
        } footer: {
            if let hint = hint {
                Text(ReadiumLCPLocalizedStringKey("dialog.passphrase.hint", hint))
            }
        }
        .listRowSeparator(.hidden)
    }

    @ViewBuilder private var buttons: some View {
        Section {
            Button(ReadiumLCPLocalizedStringKey("dialog.actions.continue")) {
                submit()
            }
            .boldIfAvailable()
            .id(openButtonId)
            .disabled(passphrase.isEmpty)
            .frame(maxWidth: .infinity, alignment: .center)
        }

        if let onForgotPassphrase = onForgotPassphrase {
            Section {
                Button(ReadiumLCPLocalizedStringKey("dialog.actions.recoverPassphrase"), role: .destructive) {
                    onForgotPassphrase()
                }
                .frame(maxWidth: .infinity, alignment: .center)
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

private extension View {
    @ViewBuilder
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }

    @ViewBuilder
    func alignListRowSeparatorLeading() -> some View {
        if #available(iOS 16.0, *) {
            alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        } else {
            self
        }
    }

    @ViewBuilder
    func boldIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            bold()
        } else {
            self
        }
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
