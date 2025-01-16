//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumOPDS
import ReadiumShared

extension Feed {
    static var preview: Feed {
        try! OPDS2Parser.parse(
            jsonData: .preview,
            url: URL(string: "http://opds-spec.org/opds.json")!,
            response: URLResponse()
        ).feed!
    }
}

private extension Data {
    static var preview: Data {
        let jsonString = """
        {
            "@context": "http://opds-spec.org/opds.json",
            "metadata": {
                "title": "Example Library",
                "modified": "2024-11-05T12:00:00Z",
                "numberOfItems": 5000,
                "itemsPerPage": 30
            },
            "links": [
                {
                    "rel": "self",
                    "href": "/opds",
                    "type": "application/opds+json"
                }
            ],
            "facets": [
                {
                    "metadata": {
                        "title": "Genre"
                    },
                    "links": [
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?genre=fiction",
                            "title": "Fiction",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 1250
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?genre=mystery",
                            "title": "Mystery & Detective",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 850
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?genre=scifi",
                            "title": "Science Fiction",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 725
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?genre=non-fiction",
                            "title": "Non-Fiction",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 2175
                            }
                        }
                    ]
                },
                {
                    "metadata": {
                        "title": "Language"
                    },
                    "links": [
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?language=en",
                            "title": "English",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 3000
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?language=es",
                            "title": "Spanish",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 1000
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?language=ru",
                            "title": "Russian",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 800
                            }
                        }
                    ]
                },
                {
                    "metadata": {
                        "title": "Availability"
                    },
                    "links": [
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?availability=free",
                            "title": "Free",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 1500
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?availability=subscription",
                            "title": "Subscription",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 2500
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?availability=buy",
                            "title": "Purchase Required",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 1000
                            }
                        }
                    ]
                },
                {
                    "metadata": {
                        "title": "Reading Age"
                    },
                    "links": [
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?age=children",
                            "title": "Children (0-11)",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 800
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?age=teen",
                            "title": "Teen (12-18)",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 1200
                            }
                        },
                        {
                            "rel": "http://opds-spec.org/facet",
                            "href": "/opds/books/new?age=adult",
                            "title": "Adult (18+)",
                            "type": "application/opds+json",
                            "properties": {
                                "numberOfItems": 3000
                            }
                        }
                    ]
                }
            ],
            "publications": [
                {
                    "metadata": {
                        "title": "Sample Book",
                        "identifier": "urn:uuid:6409a00b-7bf2-405e-826c-3fdff0fd0734",
                        "modified": "2024-11-05T12:00:00Z",
                        "language": ["en"],
                        "published": "2024",
                        "author": [
                            {
                                "name": "Sample Author"
                            }
                        ],
                        "subject": [
                            {
                                "name": "Fiction",
                                "code": "fiction"
                            }
                        ]
                    },
                    "links": [
                        {
                            "rel": "http://opds-spec.org/acquisition",
                            "href": "/books/sample.epub",
                            "type": "application/epub+zip"
                        }
                    ]
                }
            ]
        }
        """
        guard let data = jsonString.data(using: .utf8) else {
            return Data()
        }
        return data
    }
}
