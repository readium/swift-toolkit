//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
@testable import ReadiumStreamer
import Testing

enum AudioManifestBuilderTests {
    struct Package {
        /// `nil` stands for files which were not read.
        @Test(arguments: [AudioMetadata(), nil])
        func onlyHasBareLinksWithoutTags(metadata: AudioMetadata?) {
            #expect(build(metadata, metadata) == Manifest(
                metadata: Metadata(conformsTo: [.audiobook]),
                readingOrder: [
                    Link(href: "1.mp3", mediaType: .mp3),
                    Link(href: "2.mp3", mediaType: .mp3),
                ]
            ))
        }

        @Test func isEmptyWithoutFiles() {
            #expect(build() == Manifest(metadata: Metadata(conformsTo: [.audiobook])))
        }
    }

    struct BookMetadata {
        @Test(arguments: [
            (
                "title prefers the album of any file",
                [AudioMetadata(title: "Part 1"), AudioMetadata(album: "The Book")],
                Metadata(conformsTo: [.audiobook], title: "The Book")
            ),
            (
                "title falls back to the first title",
                [AudioMetadata(), AudioMetadata(title: "Part 1"), AudioMetadata(title: "Part 2")],
                Metadata(conformsTo: [.audiobook], title: "Part 1")
            ),
            (
                "title is the first album",
                [AudioMetadata(album: "The Book"), AudioMetadata(album: "Another Book")],
                Metadata(conformsTo: [.audiobook], title: "The Book")
            ),
            (
                "title ignores blank values",
                [AudioMetadata(title: "Part 1", album: " \n"), AudioMetadata(title: "Part 2", album: "")],
                Metadata(conformsTo: [.audiobook], title: "Part 1")
            ),
            (
                "subtitle is the first value",
                [AudioMetadata(subtitle: " "), AudioMetadata(subtitle: "A Subtitle"), AudioMetadata(subtitle: "Another")],
                Metadata(conformsTo: [.audiobook], subtitle: "A Subtitle")
            ),
            (
                "sortAs prefers the sort album of any file",
                [AudioMetadata(sortTitle: "Part 1"), AudioMetadata(sortAlbum: "Book, The")],
                Metadata(conformsTo: [.audiobook], sortAs: "Book, The")
            ),
            (
                "sortAs falls back to the first sort title",
                [AudioMetadata(sortTitle: "Part 1"), AudioMetadata(sortTitle: "Part 2")],
                Metadata(conformsTo: [.audiobook], sortAs: "Part 1")
            ),
            (
                "description prefers the description of any file",
                [AudioMetadata(summary: "Summary", comment: "Comment"), AudioMetadata(description: "Description")],
                Metadata(conformsTo: [.audiobook], description: "Description")
            ),
            (
                "description prefers the summary over the comment",
                [AudioMetadata(comment: "Comment"), AudioMetadata(summary: "Summary")],
                Metadata(conformsTo: [.audiobook], description: "Summary")
            ),
            (
                "description falls back to the first comment",
                [AudioMetadata(comment: "Comment"), AudioMetadata(comment: "Another")],
                Metadata(conformsTo: [.audiobook], description: "Comment")
            ),
            (
                "published prefers the first release date of any file",
                [
                    AudioMetadata(date: date("2020-01-01")),
                    AudioMetadata(releaseDate: date("2021-03-04")),
                    AudioMetadata(releaseDate: date("2022-05-06")),
                ],
                Metadata(conformsTo: [.audiobook], published: date("2021-03-04"))
            ),
            (
                "published falls back to the first date",
                [AudioMetadata(), AudioMetadata(date: date("2020-01-01")), AudioMetadata(date: date("2021-03-04"))],
                Metadata(conformsTo: [.audiobook], published: date("2020-01-01"))
            ),
        ] as [MetadataRule])
        func usesTheFirstValueOfTheBestSource(rule: String, files: [AudioMetadata], expected: Metadata) {
            #expect(build(files).metadata == expected)
        }

        @Test(arguments: [
            (
                "authors prefer the album artists of any file",
                [AudioMetadata(albumArtists: ["Jane"]), AudioMetadata(artists: ["Jane, Nora"])],
                Metadata(conformsTo: [.audiobook], authors: [Contributor(name: "Jane")])
            ),
            (
                "authors fall back to the artists",
                [AudioMetadata(artists: ["Jane"]), AudioMetadata(artists: ["John"])],
                Metadata(conformsTo: [.audiobook], authors: [Contributor(name: "Jane"), Contributor(name: "John")])
            ),
            (
                "narrators prefer the narrators of any file",
                [AudioMetadata(composers: ["Carl Composer"]), AudioMetadata(narrators: ["Nora Narrator"])],
                Metadata(conformsTo: [.audiobook], narrators: [Contributor(name: "Nora Narrator")])
            ),
            (
                "narrators fall back to the composers",
                [AudioMetadata(composers: ["Nora"]), AudioMetadata(composers: ["Ned"])],
                Metadata(conformsTo: [.audiobook], narrators: [Contributor(name: "Nora"), Contributor(name: "Ned")])
            ),
            (
                "publishers are combined",
                [AudioMetadata(publishers: ["Acme Audio"]), AudioMetadata(publishers: ["Other Audio"])],
                Metadata(conformsTo: [.audiobook], publishers: [Contributor(name: "Acme Audio"), Contributor(name: "Other Audio")])
            ),
            (
                "subjects are combined",
                [AudioMetadata(genres: ["Fantasy", "Adventure"]), AudioMetadata(genres: ["Fiction"])],
                Metadata(conformsTo: [.audiobook], subjects: [Subject(name: "Fantasy"), Subject(name: "Adventure"), Subject(name: "Fiction")])
            ),
            (
                "languages are combined",
                [AudioMetadata(languages: ["fr"]), AudioMetadata(languages: ["en", "fr-CA"])],
                Metadata(conformsTo: [.audiobook], languages: ["fr", "en", "fr-CA"])
            ),
            (
                "duplicates are removed following the reading order",
                [AudioMetadata(albumArtists: ["Jane", "John"]), AudioMetadata(albumArtists: ["John", "Jane", "Jack"])],
                Metadata(conformsTo: [.audiobook], authors: [Contributor(name: "Jane"), Contributor(name: "John"), Contributor(name: "Jack")])
            ),
            (
                "blank values are ignored",
                [AudioMetadata(albumArtists: ["", " "], artists: ["Jane", "\t"])],
                Metadata(conformsTo: [.audiobook], authors: [Contributor(name: "Jane")])
            ),
        ] as [MetadataRule])
        func combinesTheDistinctValuesOfTheBestSource(rule: String, files: [AudioMetadata], expected: Metadata) {
            #expect(build(files).metadata == expected)
        }

        @Test(arguments: [
            (
                "names prefer the movement name of any file",
                [AudioMetadata(series: "Series"), AudioMetadata(movementName: "Movement")],
                Metadata(conformsTo: [.audiobook], belongsToSeries: [Contributor(name: "Movement")])
            ),
            (
                "names fall back to the series",
                [AudioMetadata(series: "The Saga", seriesPosition: 2.5)],
                Metadata(conformsTo: [.audiobook], belongsToSeries: [Contributor(name: "The Saga", position: 2.5)])
            ),
            (
                "position prefers the movement index of any file carrying the name",
                [
                    AudioMetadata(movementName: "The Saga", series: "The Saga", seriesPosition: 3),
                    AudioMetadata(movementName: "The Saga", movementIndex: 2),
                ],
                Metadata(conformsTo: [.audiobook], belongsToSeries: [Contributor(name: "The Saga", position: 2)])
            ),
            (
                "position falls back to the first series position",
                [
                    AudioMetadata(movementName: "The Saga"),
                    AudioMetadata(movementName: "The Saga", seriesPosition: 3),
                    AudioMetadata(movementName: "The Saga", seriesPosition: 4),
                ],
                Metadata(conformsTo: [.audiobook], belongsToSeries: [Contributor(name: "The Saga", position: 3)])
            ),
            (
                "position comes from the files carrying the name only, and is optional",
                [
                    AudioMetadata(movementName: "First", movementIndex: 1),
                    AudioMetadata(movementName: "Second"),
                    AudioMetadata(movementName: "Third", movementIndex: 3),
                    AudioMetadata(movementName: "First", movementIndex: 9),
                ],
                Metadata(conformsTo: [.audiobook], belongsToSeries: [
                    Contributor(name: "First", position: 1),
                    Contributor(name: "Second"),
                    Contributor(name: "Third", position: 3),
                ])
            ),
            (
                "a file carries the name with either tag",
                [
                    AudioMetadata(movementName: "The Saga"),
                    AudioMetadata(series: "The Saga", seriesPosition: 2),
                ],
                Metadata(conformsTo: [.audiobook], belongsToSeries: [Contributor(name: "The Saga", position: 2)])
            ),
            (
                "a position is not tied to the name tag of its own source",
                [AudioMetadata(movementName: "The Saga", series: "Other", seriesPosition: 5)],
                Metadata(conformsTo: [.audiobook], belongsToSeries: [Contributor(name: "The Saga", position: 5)])
            ),
        ] as [MetadataRule])
        func series(rule: String, files: [AudioMetadata], expected: Metadata) {
            #expect(build(files).metadata == expected)
        }

        @Test(arguments: [
            ("is the URN of the ISBN", ["978-1-234-56789-7"], "urn:isbn:9781234567897", []),
            ("is the first valid ISBN", ["0306406152", "9781234567897"], "urn:isbn:0306406152", []),
            (
                "skips an invalid ISBN",
                ["9781234567890", "9781234567897"],
                "urn:isbn:9781234567897",
                [.invalidISBN(href: url("1.mp3"), isbn: "9781234567890")]
            ),
            (
                "is nil for an invalid ISBN",
                ["B00JCDK5ME"],
                nil,
                [.invalidISBN(href: url("1.mp3"), isbn: "B00JCDK5ME")]
            ),
            (
                "warns about an invalid ISBN after a valid one",
                ["9781234567897", "invalid"],
                "urn:isbn:9781234567897",
                [.invalidISBN(href: url("2.mp3"), isbn: "invalid")]
            ),
            (
                "warns once for the same invalid ISBN",
                ["invalid", "invalid"],
                nil,
                [.invalidISBN(href: url("1.mp3"), isbn: "invalid")]
            ),
            ("ignores a blank ISBN", [" "], nil, []),
        ] as [(String, [String], String?, [AudioMetadataWarning])])
        func identifier(rule: String, isbns: [String], expected: String?, expectedWarnings: [AudioMetadataWarning]) {
            let warnings = ListWarningLogger()
            let manifest = build(isbns.map { AudioMetadata(isbn: $0) }, warnings: warnings)

            #expect(manifest.metadata.identifier == expected)
            #expect(warnings.audioMetadataWarnings == expectedWarnings)
        }

        @Test func durationIsTheSumOfTheFileDurations() {
            let manifest = build(AudioMetadata(duration: 3600), AudioMetadata(duration: 1800.5))
            #expect(manifest.metadata.duration == 5400.5)
        }

        /// `nil` stands for a file which was not read.
        @Test(arguments: [
            nil,
            AudioMetadata(),
            AudioMetadata(duration: 0),
            AudioMetadata(duration: -1),
            AudioMetadata(duration: .nan),
            AudioMetadata(duration: .infinity),
        ])
        func durationIsNilWhenTheDurationOfAFileIsUnknown(file: AudioMetadata?) {
            let manifest = build(AudioMetadata(duration: 3600), file)
            #expect(manifest.metadata.duration == nil)
        }
    }

    struct ReadingOrder {
        @Test func hasOneLinkPerFileInTheGivenOrder() {
            let manifest = AudioManifestBuilder().build(
                entries: [
                    entry("10.m4b", .mp4, AudioMetadata(title: "Part One", duration: 3600, bitrate: 64)),
                    entry("2.mp3", .mp3, AudioMetadata(title: "Part 2", duration: 1800.5, bitrate: 127.9)),
                ],
                warnings: nil
            )

            #expect(manifest.readingOrder == [
                Link(href: "10.m4b", mediaType: .mp4, title: "Part One", bitrate: 64, duration: 3600),
                Link(href: "2.mp3", mediaType: .mp3, title: "Part 2", bitrate: 127.9, duration: 1800.5),
            ])
        }

        @Test(arguments: [
            AudioMetadata(title: " ", album: "The Book"),
            AudioMetadata(bitrate: 0),
            AudioMetadata(bitrate: -1),
            AudioMetadata(bitrate: .nan),
            AudioMetadata(bitrate: .infinity),
            AudioMetadata(duration: 0),
            AudioMetadata(duration: -1),
            AudioMetadata(duration: .nan),
            AudioMetadata(duration: .infinity),
        ])
        func omitsABlankTitleAndAnUnknownBitrateOrDuration(file: AudioMetadata) {
            #expect(build(file).readingOrder == [Link(href: "1.mp3", mediaType: .mp3)])
        }
    }

    struct TableOfContents {
        @Test func chapterLinkHasAFragmentATitleAndADuration() {
            let manifest = build(AudioMetadata(chapters: [
                .init(title: "Opening Credits", start: 0, duration: 71.5),
                .init(title: "Chapter 1", start: 71.5, duration: 3528.5),
            ]))

            #expect(manifest.tableOfContents == [
                Link(href: "1.mp3#t=0", title: "Opening Credits", duration: 71.5),
                Link(href: "1.mp3#t=71.5", title: "Chapter 1", duration: 3528.5),
            ])
        }

        @Test func chapterStartIsRoundedToMilliseconds() {
            let manifest = build(AudioMetadata(chapters: [
                .init(title: "Chapter 1", start: 12.34567),
                .init(title: "Chapter 2", start: 0.1 + 0.2),
            ]))

            #expect(manifest.tableOfContents.map(\.href) == ["1.mp3#t=12.346", "1.mp3#t=0.3"])
        }

        @Test func chapterHREFKeepsThePercentEncodingOfTheFile() {
            let manifest = AudioManifestBuilder().build(
                entries: [
                    entry("Test%20Audiobook/part%231.mp3", .mp3, AudioMetadata(chapters: [
                        .init(title: "Chapter 1", start: 10),
                    ])),
                ],
                warnings: nil
            )

            #expect(manifest.tableOfContents.map(\.href) == ["Test%20Audiobook/part%231.mp3#t=10"])
        }

        @Test func chapterWithoutAValidDurationHasNone() {
            let manifest = build(AudioMetadata(chapters: [
                .init(title: "Chapter 1", start: 10),
                .init(title: "Chapter 2", start: 20, duration: 0),
            ]))

            #expect(manifest.tableOfContents == [
                Link(href: "1.mp3#t=10", title: "Chapter 1"),
                Link(href: "1.mp3#t=20", title: "Chapter 2"),
            ])
        }

        @Test func keepsTheGivenOrderOfTheChapters() {
            let manifest = build(AudioMetadata(chapters: [
                .init(title: "Chapter 2", start: 20),
                .init(title: "Chapter 1", start: 10),
            ]))

            #expect(manifest.tableOfContents.map(\.title) == ["Chapter 2", "Chapter 1"])
        }

        @Test func leavesOutChaptersWithoutATitleWithoutWarning() {
            let warnings = ListWarningLogger()
            let manifest = build(
                AudioMetadata(chapters: [
                    .init(start: 0),
                    .init(title: "Chapter 1", start: 10),
                    .init(title: " \n", start: 20),
                    .init(title: "", start: 30),
                    .init(start: -1),
                ]),
                warnings: warnings
            )

            #expect(manifest.tableOfContents == [Link(href: "1.mp3#t=10", title: "Chapter 1")])
            #expect(warnings.warnings.isEmpty)
        }

        @Test(arguments: [
            ("no chapters", []),
            ("untitled chapters", [.init(start: 0), .init(title: " ", start: 10)]),
            ("titled chapters with an invalid start time", [.init(title: "Chapter 1", start: -1)]),
        ] as [(String, [AudioMetadata.Chapter])])
        func isNotProducedWithoutAValidTitledChapter(rule: String, chapters: [AudioMetadata.Chapter]) {
            let manifest = build(
                AudioMetadata(title: "Part 1", duration: 10, chapters: chapters),
                AudioMetadata(title: "Part 2", duration: 20)
            )

            #expect(manifest.tableOfContents.isEmpty)
            #expect(manifest.subcollections.isEmpty)
        }

        @Test func concatenatesTheChaptersOfEachFileFollowingTheReadingOrder() {
            let manifest = build(
                AudioMetadata(chapters: [
                    .init(title: "Chapter 1", start: 0),
                    .init(title: "Chapter 2", start: 10),
                ]),
                AudioMetadata(chapters: [
                    .init(title: "Chapter 3", start: 0),
                ])
            )

            #expect(manifest.tableOfContents == [
                Link(href: "1.mp3#t=0", title: "Chapter 1"),
                Link(href: "1.mp3#t=10", title: "Chapter 2"),
                Link(href: "2.mp3#t=0", title: "Chapter 3"),
            ])
        }

        @Test func fileWithoutValidTitledChapterContributesOneLink() {
            let manifest = build(
                AudioMetadata(title: "Part 1", duration: 100, chapters: [.init(start: 0)]),
                AudioMetadata(title: "Part 2", duration: 200, chapters: [.init(title: "Chapter 1", start: 0)]),
                AudioMetadata(title: "Part 3", duration: 300),
                AudioMetadata(title: "Part 4"),
                AudioMetadata(title: "Part 5", chapters: [.init(title: "Chapter 2", start: -1)])
            )

            #expect(manifest.tableOfContents == [
                Link(href: "1.mp3", title: "Part 1", duration: 100),
                Link(href: "2.mp3#t=0", title: "Chapter 1"),
                Link(href: "3.mp3", title: "Part 3", duration: 300),
                Link(href: "4.mp3", title: "Part 4"),
                Link(href: "5.mp3", title: "Part 5"),
            ])
        }

        @Test func fileWithoutTitledChapterNorTitleContributesNoLink() {
            let manifest = build(
                AudioMetadata(duration: 100),
                AudioMetadata(title: " ", duration: 100),
                nil,
                AudioMetadata(chapters: [.init(title: "Chapter 1", start: 0)])
            )

            #expect(manifest.tableOfContents == [Link(href: "4.mp3#t=0", title: "Chapter 1")])
        }

        @Test(arguments: [-1, TimeInterval.nan, TimeInterval.infinity, -TimeInterval.infinity])
        func leavesOutAChapterWithAnInvalidStartTimeWithAWarning(start: TimeInterval) {
            let warnings = ListWarningLogger()
            let manifest = build(
                AudioMetadata(chapters: [
                    .init(title: "Chapter 1", start: 0),
                    .init(title: "Chapter 2", start: start),
                ]),
                warnings: warnings
            )

            #expect(manifest.tableOfContents == [Link(href: "1.mp3#t=0", title: "Chapter 1")])
            #expect(warnings.audioMetadataWarnings == [.invalidChapterStart(href: url("1.mp3"), title: "Chapter 2")])
        }

        struct NestedChapters {
            @Test func becomeNestedLinks() {
                let manifest = build(AudioMetadata(chapters: [
                    .init(title: "Part 1", start: 0, duration: 30, children: [
                        .init(title: "Chapter 1", start: 0, duration: 10),
                        .init(start: 5),
                        .init(title: "Chapter 2", start: 10, duration: 20),
                    ]),
                    .init(title: "Part 2", start: 30, duration: 5, children: [
                        .init(title: "Chapter 3", start: 30, duration: 5),
                    ]),
                ]))

                #expect(manifest.tableOfContents == [
                    Link(href: "1.mp3#t=0", title: "Part 1", duration: 30, children: [
                        Link(href: "1.mp3#t=0", title: "Chapter 1", duration: 10),
                        Link(href: "1.mp3#t=10", title: "Chapter 2", duration: 20),
                    ]),
                    Link(href: "1.mp3#t=30", title: "Part 2", duration: 5, children: [
                        Link(href: "1.mp3#t=30", title: "Chapter 3", duration: 5),
                    ]),
                ])
            }

            @Test func untitledParentIsReplacedByItsChildren() {
                let manifest = build(AudioMetadata(chapters: [
                    .init(title: "Prologue", start: 0),
                    .init(start: 10, children: [
                        .init(title: "Chapter 1", start: 10),
                        .init(title: " ", start: 20, children: [
                            .init(title: "Chapter 2", start: 20),
                        ]),
                    ]),
                    .init(title: "Epilogue", start: 30),
                ]))

                #expect(manifest.tableOfContents == [
                    Link(href: "1.mp3#t=0", title: "Prologue"),
                    Link(href: "1.mp3#t=10", title: "Chapter 1"),
                    Link(href: "1.mp3#t=20", title: "Chapter 2"),
                    Link(href: "1.mp3#t=30", title: "Epilogue"),
                ])
            }

            @Test func fileWhoseOnlyTitledChapterIsNestedProducesATableOfContents() {
                let manifest = build(
                    AudioMetadata(title: "Part 1"),
                    AudioMetadata(title: "Part 2", chapters: [
                        .init(start: 0, children: [
                            .init(start: 0, children: [
                                .init(title: "Chapter 1", start: 5),
                            ]),
                        ]),
                    ])
                )

                #expect(manifest.tableOfContents == [
                    Link(href: "1.mp3", title: "Part 1"),
                    Link(href: "2.mp3#t=5", title: "Chapter 1"),
                ])
            }

            @Test func invalidStartTimeInAChildLogsAWarning() {
                let warnings = ListWarningLogger()
                let manifest = build(
                    AudioMetadata(chapters: [
                        .init(title: "Part 1", start: 0, children: [
                            .init(title: "Chapter 1", start: -5),
                            .init(title: "Chapter 2", start: 10),
                        ]),
                    ]),
                    warnings: warnings
                )

                #expect(manifest.tableOfContents == [
                    Link(href: "1.mp3#t=0", title: "Part 1", children: [
                        Link(href: "1.mp3#t=10", title: "Chapter 2"),
                    ]),
                ])
                #expect(warnings.audioMetadataWarnings == [.invalidChapterStart(href: url("1.mp3"), title: "Chapter 1")])
            }

            @Test func parentWithAnInvalidStartTimeIsReplacedByItsChildren() {
                let warnings = ListWarningLogger()
                let manifest = build(
                    AudioMetadata(chapters: [
                        .init(title: "Part 1", start: -1, children: [
                            .init(title: "Chapter 1", start: 0),
                        ]),
                    ]),
                    warnings: warnings
                )

                #expect(manifest.tableOfContents == [Link(href: "1.mp3#t=0", title: "Chapter 1")])
                #expect(warnings.audioMetadataWarnings == [.invalidChapterStart(href: url("1.mp3"), title: "Part 1")])
            }
        }
    }

    struct ReferenceExample {
        /// Example of the reference, at the commit 1d9c7f4 of
        /// https://github.com/readium/architecture/pull/199
        ///
        /// The manifests are compared once parsed, as `published` is a date
        /// only and `author` a bare string in the example.
        @Test func buildsTheManifestOfTheReference() throws {
            let expected = try Manifest(jsonString: """
            {
              "metadata": {
                "conformsTo": "https://readium.org/webpub-manifest/profiles/audiobook",
                "title": "The Book",
                "subtitle": "A Subtitle",
                "author": "Jane Author",
                "narrator": "Nora Narrator",
                "publisher": "Acme Audio",
                "published": "2021-03-04",
                "language": "fr",
                "identifier": "urn:isbn:9781234567897",
                "subject": ["Fantasy"],
                "belongsTo": {
                  "series": [{"name": "The Saga", "position": 2}]
                },
                "duration": 5400
              },
              "readingOrder": [
                {"href": "part1.m4b", "type": "audio/mp4", "title": "Part One", "duration": 3600, "bitrate": 64},
                {"href": "part2.mp3", "type": "audio/mpeg", "title": "Part 2", "duration": 1800, "bitrate": 64}
              ],
              "toc": [
                {"href": "part1.m4b#t=0", "title": "Opening Credits", "duration": 71.5},
                {"href": "part1.m4b#t=71.5", "title": "Chapter 1", "duration": 3528.5},
                {"href": "part2.mp3", "title": "Part 2", "duration": 1800}
              ]
            }
            """)

            let warnings = ListWarningLogger()
            let manifest = AudioManifestBuilder().build(
                entries: [
                    entry("part1.m4b", .mp4, AudioMetadata(
                        title: "Part One",
                        album: "The Book",
                        subtitle: "A Subtitle",
                        albumArtists: ["Jane Author"],
                        artists: ["Jane Author, Nora Narrator"],
                        narrators: ["Nora Narrator"],
                        movementName: "The Saga",
                        movementIndex: 2,
                        series: "The Saga",
                        seriesPosition: 2,
                        publishers: ["Acme Audio"],
                        date: date("2021-03-04"),
                        genres: ["Fantasy"],
                        languages: ["fr"],
                        isbn: "978-1-234-56789-7",
                        duration: 3600,
                        bitrate: 64,
                        chapters: [
                            .init(title: "Opening Credits", start: 0, duration: 71.5),
                            .init(title: "Chapter 1", start: 71.5, duration: 3528.5),
                        ]
                    )),
                    entry("part2.mp3", .mp3, AudioMetadata(
                        title: "Part 2",
                        album: "The Book",
                        albumArtists: ["Jane Author"],
                        duration: 1800,
                        bitrate: 64
                    )),
                ],
                warnings: warnings
            )

            #expect(manifest == expected)
            #expect(warnings.warnings.isEmpty)
        }
    }
}

// MARK: - Helpers

/// A rule of the aggregation: its name, the metadata of the files, and the
/// metadata expected in the manifest.
private typealias MetadataRule = (String, [AudioMetadata], Metadata)

/// Builds the manifest of the given files, named `1.mp3`, `2.mp3` and so on.
///
/// A nil value is a file whose metadata was not read.
private func build(_ files: AudioMetadata?..., warnings: WarningLogger? = nil) -> Manifest {
    build(files, warnings: warnings)
}

private func build(_ files: [AudioMetadata?], warnings: WarningLogger? = nil) -> Manifest {
    AudioManifestBuilder().build(
        entries: files.enumerated().map { index, metadata in
            entry("\(index + 1).mp3", .mp3, metadata)
        },
        warnings: warnings
    )
}

private func entry(_ href: String, _ mediaType: MediaType, _ metadata: AudioMetadata?) -> AudioManifestBuilder.Entry {
    AudioManifestBuilder.Entry(
        url: url(href),
        format: Format(mediaType: mediaType),
        metadata: metadata
    )
}

private func url(_ string: String) -> AnyURL {
    AnyURL(string: string)!
}

private func date(_ string: String) -> Date {
    string.dateFromISO8601!
}

private extension ListWarningLogger {
    var audioMetadataWarnings: [AudioMetadataWarning] {
        warnings.map { $0 as! AudioMetadataWarning }
    }
}
