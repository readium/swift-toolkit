//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum HREFError: Error {
    /// Failed to resolve the given `url` to the `base` URL.
    case cannotResolveToBase(url: URL, base: URL)

    /// The URI `template` with given `parameters` produced an invalid URL.
    case invalidTemplate(template: String, parameters: [String: String])
}

/// An hypertext reference points to a resource in a `Publication`.
///
/// It is potentially templated, use `resolve` to get the actual URL.
public enum HREF: Equatable, Hashable {
    /// A static hypertext reference to a publication resource.
    case url(URL)

    /// A templated hypertext reference to a publication resource, as defined in
    /// RFC 6570.
    case template(String)

    /// Convenience helper to create a URL `HREF` from a raw string.
    public static func url(_ string: String) -> HREF? {
        guard let url = URL(string: string) else {
            return nil
        }
        return .url(url)
    }

    /// Returns the string representation for this `HREF`.
    public var string: String {
        switch self {
        case let .url(url):
            return url.absoluteString
        case let .template(template):
            return template
        }
    }

    /// Indicates whether this HREF is templated.
    public var isTemplated: Bool {
        switch self {
        case .url:
            return false
        case .template:
            return true
        }
    }

    /// List of URI template parameter keys, if the HREF is templated.
    public var parameters: Set<String>? {
        switch self {
        case .url:
            return nil
        case let .template(template):
            return URITemplate(template).parameters
        }
    }

    /// Returns the URL represented by this HREF, resolved to the given `base`
    /// URL.
    ///
    /// If the HREF is a template, the `parameters` are used to expand it
    /// according to RFC 6570.
    public func resolve(to base: URL? = nil, parameters: [String: String] = [:]) -> Result<URL, HREFError> {
        switch self {
        case let .url(url):
            if let base = base {
                guard let resolvedURL = URL(string: url.absoluteString, relativeTo: base) else {
                    return .failure(.cannotResolveToBase(url: url, base: base))
                }
                return .success(resolvedURL)
            } else {
                return .success(url)
            }

        case let .template(template):
            guard let url = URITemplate(template).expand(with: parameters) else {
                return .failure(.invalidTemplate(template: template, parameters: parameters))
            }
            return .success(url)
        }
    }
}

extension HREF: CustomStringConvertible {
    public var description: String { string }
}

/*
 /// Represents an HREF, optionally relative to another one.
  ///
  /// This is used to normalize the string representation.
  public struct HREF {
      private let href: String
      private let baseHREF: String

  public init(_ href: String, relativeTo baseHREF: String = "/") {
      let baseHREF = baseHREF.trimmingCharacters(in: .whitespacesAndNewlines)
      self.href = href.trimmingCharacters(in: .whitespacesAndNewlines)
      self.baseHREF = baseHREF.isEmpty ? "/" : baseHREF
  }

  /// Returns the normalized string representation for this HREF.
  public var string: String {
      // HREF is just an anchor inside the base.
      if href.isEmpty || href.hasPrefix("#") {
          return baseHREF + href
      }

  // HREF is already absolute.
  if let url = URL(string: href), url.scheme != nil {
      return href
  }

  let baseURL: URL = {
      if let url = URL(string: baseHREF), url.scheme != nil {
          return url
      } else {
          return URL(fileURLWithPath: baseHREF.removingPercentEncoding ?? baseHREF)
      }
  }()

  // Isolates the path from the anchor/query portion, which would be lost otherwise.
  let splitIndex = href.firstIndex(of: "?") ?? href.firstIndex(of: "#") ?? href.endIndex
  let path = String(href[..<splitIndex])
  let suffix = String(href[splitIndex...])

  guard
      let safePath = (path.removingPercentEncoding ?? path)
      .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
      let url = URL(string: safePath, relativeTo: baseURL)
  else {
      return baseHREF + "/" + href
  }

  return (url.isHTTP ? url.absoluteString : url.path) + suffix
 }
  */
