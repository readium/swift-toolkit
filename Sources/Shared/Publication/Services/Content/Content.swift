//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides an iterable list of `ContentElement`s.
public protocol Content {
    /// Creates a new fallible bidirectional iterator for this content.
    func iterator() -> ContentIterator
}

public extension Content {
    /// Returns a `Sequence` of all elements.
    func sequence() -> ContentSequence {
        ContentSequence(content: self)
    }

    /// Returns all the elements as a list.
    func elements() async -> [ContentElement] {
        await sequence().reduce(into: [ContentElement]()) { $0.append($1) }
    }

    /// Extracts the full raw text, or returns null if no text content can be found.
    ///
    /// - Parameter separator: Separator to use between individual elements. Defaults to newline.
    func text(separator: String = "\n") async -> String? {
        let text = await elements()
            .compactMap { ($0 as? TextualContentElement)?.text.takeIf { !$0.isEmpty } }
            .joined(separator: separator)

        guard !text.isEmpty else {
            return nil
        }

        return text
    }
}

/// Represents a single semantic content element part of a publication.
public protocol ContentElement: ContentAttributesHolder {
    /// Locator targeting this element in the Publication.
    var locator: Locator { get }

    /// Returns whether the receiver is equivalent to `other`.
    func isEqualTo(_ other: ContentElement) -> Bool
}

public extension ContentElement where Self: Equatable {
    func isEqualTo(_ other: ContentElement) -> Bool {
        guard let otherElement = other as? Self else { return false }
        return self == otherElement
    }
}

/// A type-erasing `ContentElement` object which implements `Equatable`.
public struct AnyEquatableContentElement: Equatable, ContentElement {
    private let element: ContentElement

    public init<E: ContentElement>(_ element: E) {
        self.element = element
    }

    public var locator: Locator { element.locator }

    public var attributes: [ContentAttribute] { element.attributes }

    public func isEqualTo(_ other: ContentElement) -> Bool {
        element.isEqualTo(other)
    }

    public static func == (lhs: AnyEquatableContentElement, rhs: AnyEquatableContentElement) -> Bool {
        lhs.element.isEqualTo(rhs.element)
    }
}

/// An element which can be represented as human-readable text.
///
/// The default implementation returns the first accessibility label associated to the element.
public protocol TextualContentElement: ContentElement {
    /// Human-readable text representation for this element.
    var text: String? { get }
}

public extension TextualContentElement {
    var text: String? { accessibilityLabel }
}

/// An element referencing an embedded external resource.
public protocol EmbeddedContentElement: ContentElement {
    /// Referenced resource in the publication.
    var embeddedLink: Link { get }
}

/// An audio clip.
public struct AudioContentElement: Hashable, EmbeddedContentElement, TextualContentElement {
    public var locator: Locator
    public var embeddedLink: Link
    public var attributes: [ContentAttribute]

    public init(locator: Locator, embeddedLink: Link, attributes: [ContentAttribute] = []) {
        self.locator = locator
        self.embeddedLink = embeddedLink
        self.attributes = attributes
    }
}

/// A video clip.
public struct VideoContentElement: Hashable, EmbeddedContentElement, TextualContentElement {
    public var locator: Locator
    public var embeddedLink: Link
    public var attributes: [ContentAttribute]

    public init(locator: Locator, embeddedLink: Link, attributes: [ContentAttribute] = []) {
        self.locator = locator
        self.embeddedLink = embeddedLink
        self.attributes = attributes
    }
}

/// A bitmap image.
public struct ImageContentElement: Hashable, EmbeddedContentElement, TextualContentElement {
    public var locator: Locator
    public var embeddedLink: Link

    /// Short piece of text associated with the image.
    public var caption: String?
    public var attributes: [ContentAttribute]

    public init(locator: Locator, embeddedLink: Link, caption: String? = nil, attributes: [ContentAttribute] = []) {
        self.locator = locator
        self.embeddedLink = embeddedLink
        self.caption = caption
        self.attributes = attributes
    }

    public var text: String? {
        // The caption might be a better text description than the accessibility label, when available.
        caption.takeIf { !$0.isEmpty } ?? accessibilityLabel
    }
}

/// A text element.
///
/// @param role Purpose of this element in the broader context of the document.
/// @param segments Ranged portions of text with associated attributes.
public struct TextContentElement: Hashable, TextualContentElement {
    public var locator: Locator
    public var role: Role
    public var segments: [Segment]
    public var attributes: [ContentAttribute]

    public init(locator: Locator, role: Role, segments: [Segment], attributes: [ContentAttribute] = []) {
        self.locator = locator
        self.role = role
        self.segments = segments
        self.attributes = attributes
    }

    public var text: String? {
        segments.map(\.text).joined()
    }

    /// Represents a purpose of an element in the broader context of the document.
    public enum Role: Hashable {
        /// Title of a section with its level (1 being the highest).
        case heading(level: Int)

        /// Normal body of content.
        case body

        /// A footnote at the bottom of a document.
        case footnote

        /// A quotation.
        case quote(referenceUrl: URL?, referenceTitle: String?)
    }

    /// Ranged portion of text with associated attributes.
    ///
    /// @param locator Locator to the segment of text.
    /// @param text Text in the segment.
    /// @param attributes Attributes associated with this segment, e.g. language.
    public struct Segment: Hashable, ContentAttributesHolder {
        public var locator: Locator
        public var text: String
        public var attributes: [ContentAttribute]

        public init(locator: Locator, text: String, attributes: [ContentAttribute] = []) {
            self.locator = locator
            self.text = text
            self.attributes = attributes
        }
    }
}

/// An attribute key identifies uniquely a type of attribute.
///
/// The `V` phantom type is there to perform static type checking when requesting an attribute.
public struct ContentAttributeKey<V>: Hashable {
    public static var accessibilityLabel: ContentAttributeKey<String> { .init("accessibilityLabel") }
    public static var language: ContentAttributeKey<Language> { .init("language") }

    public let key: String
    public init(_ key: String) {
        self.key = key
    }
}

public struct ContentAttribute: Hashable {
    public let key: String
    public let value: AnyHashable

    public init<T: Hashable>(key: ContentAttributeKey<T>, value: T) {
        self.key = key.key
        self.value = value
    }

    public init(key: String, value: AnyHashable) {
        self.key = key
        self.value = value
    }
}

/// Object associated with a list of attributes.
public protocol ContentAttributesHolder {
    /// Associated list of attributes.
    var attributes: [ContentAttribute] { get }
}

public extension ContentAttributesHolder {
    var language: Language? { self[.language] }
    var accessibilityLabel: String? { self[.accessibilityLabel] }

    /// Gets the first attribute with the given `key`.
    subscript<T>(_ key: ContentAttributeKey<T>) -> T? {
        attribute(key)
    }

    /// Gets the first attribute with the given `key`.
    func attribute<T>(_ key: ContentAttributeKey<T>) -> T? {
        attributes.first { attr in
            if attr.key == key.key, let value = attr.value as? T {
                return value
            } else {
                return nil
            }
        }
    }

    /// Gets all the attributes with the given `key`.
    func attributes<T>(_ key: ContentAttributeKey<T>) -> [T] {
        attributes.compactMap { attr in
            if attr.key == key.key, let value = attr.value as? T {
                return value
            } else {
                return nil
            }
        }
    }
}

/// Iterates through a list of `ContentElement` items.
public protocol ContentIterator: AnyObject {
    /// Retrieves the next element, or nil if we reached the end.
    func next() async throws -> ContentElement?

    /// Advances to the previous item and returns it, or null if we reached the beginning.
    func previous() async throws -> ContentElement?
}

/// Helper class to treat a `Content` as a `Sequence`.
public class ContentSequence: AsyncSequence {
    public typealias Element = ContentElement

    private let content: Content

    init(content: Content) {
        self.content = content
    }

    public func makeAsyncIterator() -> ContentSequence.Iterator {
        Iterator(iterator: content.iterator())
    }

    public class Iterator: AsyncIteratorProtocol, Loggable {
        private let iterator: ContentIterator

        public init(iterator: ContentIterator) {
            self.iterator = iterator
        }

        public func next() async -> ContentElement? {
            do {
                return try await iterator.next()
            } catch {
                log(.warning, error)
                return await next()
            }
        }
    }
}
