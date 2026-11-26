//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// The preferences editors are removed: the app owns the preference values,
// and the settings tell which ones take effect with `isEffective(_:)`.

@available(*, unavailable, message: "Build the settings with EPUBSettings(publication:readingOrder:preferences:defaults:) and check EPUBSettings.isEffective(_:), see the migration guide")
public final class EPUBPreferencesEditor {}

@available(*, unavailable, message: "Build the settings with PDFSettings(publication:preferences:defaults:) and check PDFSettings.isEffective(_:), see the migration guide")
public final class PDFPreferencesEditor {}

@available(*, unavailable, message: "Every audio setting is always effective, see the AudioPreferences documentation for the supported values")
public final class AudioPreferencesEditor {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol PreferencesEditor {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol Preference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol EnumPreference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol RangePreference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public protocol OptionalRangePreference {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public class AnyPreference<Value> {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public final class AnyEnumPreference<Value> {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public final class AnyRangePreference<Value> {}

@available(*, unavailable, message: "The preferences editors are removed, see the migration guide")
public final class AnyOptionalRangePreference<Bound> {}
