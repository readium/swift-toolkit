//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
@testable import ReadiumStreamer
import Testing

@Suite enum SMILParserTests {
    static let fixtures = Fixtures(path: "SMIL")

    /// Returns the parsed document for the given SMIL fixture filename.
    ///
    /// The SMIL file is assumed to be at `OEBPS/chapter01.smil` so that
    /// relative HREFs like `chapter01.xhtml` resolve against `OEBPS/`.
    static func parse(_ name: String) throws -> GuidedNavigationDocument? {
        let data = fixtures.data(at: name)
        let url = AnyURL(string: "OEBPS/chapter01.smil")!
        return try SMILParser.parseGuidedNavigationDocument(smilData: data, at: url)
    }

    // MARK: - par parsing

    @Suite("par parsing") struct ParParsing {
        @Test func basicParWithTextAndAudio() throws {
            let doc = try SMILParserTests.parse("basic.smil")
            #expect(doc != nil)

            // First top-level object is the chapter seq
            let chapter = doc?.guided.first
            // First child of the chapter seq is p1
            let p1 = chapter?.children.first
            #expect(p1?.id == "p1")
            #expect(p1?.refs?.text == AnyURL(string: "OEBPS/chapter01.xhtml#id_p1"))
            #expect(p1?.refs?.audio == AnyURL(string: "OEBPS/chapter01.mp3#t=0,5.123"))
            #expect(p1?.roles == [.term])
        }

        @Test func parWithImage() throws {
            let doc = try SMILParserTests.parse("par-image.smil")
            let p1 = doc?.guided.first?.children.first
            #expect(p1?.id == "p1")
            #expect(p1?.refs?.text == AnyURL(string: "OEBPS/chapter01.xhtml#id1"))
            #expect(p1?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3#t=0,5"))
            #expect(p1?.refs?.img == AnyURL(string: "OEBPS/figure1.jpg"))
        }

        @Test func audioWithBothClipTimes() throws {
            let doc = try SMILParserTests.parse("audio-clip-times.smil")
            // s1/p1: clipBegin=0:00:00.000, clipEnd=0:00:05.123
            let p1 = doc?.guided.first?.children[0]
            #expect(p1?.id == "p1")
            #expect(p1?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3#t=0,5.123"))
        }

        @Test func audioWithOnlyClipBegin() throws {
            let doc = try SMILParserTests.parse("audio-clip-times.smil")
            // s1/p2: clipBegin=0:01:30.000
            let p2 = doc?.guided.first?.children[1]
            #expect(p2?.id == "p2")
            #expect(p2?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3#t=90,"))
        }

        @Test func audioWithOnlyClipEnd() throws {
            let doc = try SMILParserTests.parse("audio-clip-times.smil")
            // s1/p3: clipEnd=0:00:11.000
            let p3 = doc?.guided.first?.children[2]
            #expect(p3?.id == "p3")
            #expect(p3?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3#t=,11"))
        }

        @Test func audioWithoutClipTimes() throws {
            let doc = try SMILParserTests.parse("audio-clip-times.smil")
            // s1/p4: no clip attributes → plain URL
            let p4 = doc?.guided.first?.children[3]
            #expect(p4?.id == "p4")
            #expect(p4?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3"))
        }

        @Test func audioClipEndTrailingZerosStripped() throws {
            let doc = try SMILParserTests.parse("audio-clip-times.smil")
            // s1/p5: clipEnd=0:00:05.100 → "5.100" formatted, trailing zeros stripped → "5.1"
            let p5 = doc?.guided.first?.children[4]
            #expect(p5?.id == "p5")
            #expect(p5?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3#t=,5.1"))
        }

        @Test func audioClipEndPartialTrailingZeroStripped() throws {
            let doc = try SMILParserTests.parse("audio-clip-times.smil")
            // s1/p6: clipEnd=0:00:05.120 → "5.120" formatted, one trailing zero stripped → "5.12"
            let p6 = doc?.guided.first?.children[5]
            #expect(p6?.id == "p6")
            #expect(p6?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3#t=,5.12"))
        }

        @Test func videoWithBothClipTimes() throws {
            let doc = try SMILParserTests.parse("video-clip-times.smil")
            // s1/p1: clipBegin=0:00:00.000, clipEnd=0:00:05.123
            let p1 = doc?.guided.first?.children[0]
            #expect(p1?.id == "p1")
            #expect(p1?.refs?.video == AnyURL(string: "OEBPS/video.mp4#t=0,5.123"))
        }

        @Test func videoWithOnlyClipBegin() throws {
            let doc = try SMILParserTests.parse("video-clip-times.smil")
            // s1/p2: clipBegin=0:01:30.000
            let p2 = doc?.guided.first?.children[1]
            #expect(p2?.id == "p2")
            #expect(p2?.refs?.video == AnyURL(string: "OEBPS/video.mp4#t=90,"))
        }

        @Test func videoWithOnlyClipEnd() throws {
            let doc = try SMILParserTests.parse("video-clip-times.smil")
            // s1/p3: clipEnd=0:00:11.000
            let p3 = doc?.guided.first?.children[2]
            #expect(p3?.id == "p3")
            #expect(p3?.refs?.video == AnyURL(string: "OEBPS/video.mp4#t=,11"))
        }

        @Test func videoWithoutClipTimes() throws {
            let doc = try SMILParserTests.parse("video-clip-times.smil")
            // s1/p4: no clip attributes → plain URL
            let p4 = doc?.guided.first?.children[3]
            #expect(p4?.id == "p4")
            #expect(p4?.refs?.video == AnyURL(string: "OEBPS/video.mp4"))
        }

        @Test func parWithBothAudioAndVideo() throws {
            let doc = try SMILParserTests.parse("par-audio-video.smil")
            let p1 = doc?.guided.first?.children.first
            #expect(p1?.id == "p1")
            #expect(p1?.refs?.audio == AnyURL(string: "OEBPS/audio.mp3#t=0,5"))
            #expect(p1?.refs?.video == AnyURL(string: "OEBPS/video.mp4#t=0,5"))
        }

        @Test func parWithoutTextIsSkipped() throws {
            let doc = try SMILParserTests.parse("par-without-text.smil")
            let children = doc?.guided.first?.children
            // Only the valid par survives — the no-text par is dropped.
            #expect(children?.count == 1)
            #expect(children?.first?.id == "p-valid")
        }
    }

    // MARK: - seq parsing

    @Suite("seq parsing") struct SeqParsing {
        @Test func seqWithNoTypeGetsSequenceRole() throws {
            let doc = try SMILParserTests.parse("seq-types.smil")
            let noType = doc?.guided.first { $0.id == "s-no-type" }
            #expect(noType?.roles == [.sequence])
        }

        @Test func seqWithKnownTypeGetsCorrectRole() throws {
            let doc = try SMILParserTests.parse("seq-types.smil")
            let chapter = doc?.guided.first { $0.id == "s-chapter" }
            #expect(chapter?.roles == [.sequence, .chapter])
        }

        @Test func seqWithMultipleTypesGetsMultipleRoles() throws {
            let doc = try SMILParserTests.parse("seq-types.smil")
            let multi = doc?.guided.first { $0.id == "s-multi" }
            #expect(multi?.roles == [.sequence, .chapter, .part])
        }

        @Test func seqWithTextref() throws {
            let doc = try SMILParserTests.parse("seq-textref.smil")
            // s1: textref without fragment
            let s1 = doc?.guided.first { $0.id == "s1" }
            #expect(s1?.refs?.text == AnyURL(string: "OEBPS/chapter01.xhtml"))
            // s2: textref with fragment
            let s2 = doc?.guided.first { $0.id == "s2" }
            #expect(s2?.refs?.text == AnyURL(string: "OEBPS/chapter01.xhtml#sec1"))
        }

        @Test func emptySeqIsSkipped() throws {
            let doc = try SMILParserTests.parse("empty-seq.smil")
            // The empty seq must be dropped; only s-valid survives.
            #expect(doc?.guided.count == 1)
            #expect(doc?.guided.first?.id == "s-valid")
        }

        @Test func nestedSeq() throws {
            let doc = try SMILParserTests.parse("nested.smil")
            let s1 = doc?.guided.first
            #expect(s1?.roles == [.sequence, .part])
            let s2 = s1?.children.first
            #expect(s2?.roles == [.sequence, .chapter])
            let s3 = s2?.children.first
            #expect(s3?.roles == [.sequence, .table])
            let p1 = s3?.children.first
            #expect(p1?.refs?.text != nil)
        }

        @Test func basicSeqChildrenFromBasicFixture() throws {
            let doc = try SMILParserTests.parse("basic.smil")
            let chapter = doc?.guided.first
            #expect(chapter?.id == "s1")
            #expect(chapter?.roles == [.sequence, .chapter])
            #expect(chapter?.refs?.text == AnyURL(string: "OEBPS/chapter01.xhtml"))
            // Two children: p1 and s2
            #expect(chapter?.children.count == 2)
            let s2 = chapter?.children[1]
            #expect(s2?.id == "s2")
            #expect(s2?.roles == [.sequence, .table])
            #expect(s2?.refs?.text == AnyURL(string: "OEBPS/chapter01.xhtml#sec1"))
        }
    }

    // MARK: - epub:type mapping

    @Suite("epub:type mapping") struct EpubTypeMapping {
        @Test func pageListSpecialCase() throws {
            let doc = try SMILParserTests.parse("seq-types.smil")
            let pagelist = doc?.guided.first { $0.id == "s-pagelist" }
            #expect(pagelist?.roles == [.sequence, .pagelist])
        }

        @Test func listItemSpecialCase() throws {
            let doc = try SMILParserTests.parse("seq-types.smil")
            let listitem = doc?.guided.first { $0.id == "s-listitem" }
            #expect(listitem?.roles == [.sequence, .listItem])
        }

        @Test func unknownTypeGetsURIRole() throws {
            let doc = try SMILParserTests.parse("seq-types.smil")
            let unknown = doc?.guided.first { $0.id == "s-unknown" }
            #expect(unknown?.roles == [.sequence, GuidedNavigationObject.Role("http://www.idpf.org/2007/ops/type#preamble")])
        }
    }

    // MARK: - document-level

    @Suite("document") struct DocumentParsing {
        @Test func bodyChildrenBecomeTopLevelGuided() throws {
            let doc = try SMILParserTests.parse("basic.smil")
            // basic.smil has one top-level seq in the body
            #expect(doc?.links == [])
            #expect(doc?.guided.count == 1)
        }

        @Test func returnsNilForNonSMILXML() throws {
            // Fuzi parses leniently, so malformed/non-SMIL content produces no
            // <smil:body> and the parser returns nil rather than throwing.
            let badData = Data("not xml at all".utf8)
            let url = try #require(AnyURL(string: "OEBPS/chapter01.smil"))
            let doc = try SMILParser.parseGuidedNavigationDocument(smilData: badData, at: url)
            #expect(doc == nil)
        }

        @Test func returnsNilForEmptyBody() throws {
            let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <smil xmlns="http://www.w3.org/ns/SMIL" version="3.0">
              <body></body>
            </smil>
            """.data(using: .utf8)!
            let url = try #require(AnyURL(string: "OEBPS/chapter01.smil"))
            let doc = try SMILParser.parseGuidedNavigationDocument(smilData: xml, at: url)
            #expect(doc == nil)
        }
    }

    /// https://www.w3.org/TR/SMIL/smil-timing.html#Timing-ClockValueSyntax
    @Suite("parseClockValue") struct ParseClockValue {
        @Suite("full clock: hh:mm:ss[.fraction]") struct FullClock {
            @Test func basic() {
                #expect(SMILParser.parseClockValue("1:32:29") == 5549.0)
            }

            @Test func zero() {
                #expect(SMILParser.parseClockValue("0:00:00") == 0.0)
            }

            @Test func fractionalSeconds() {
                #expect(SMILParser.parseClockValue("0:01:30.5") == 90.5)
            }

            @Test func largeHours() {
                #expect(SMILParser.parseClockValue("100:00:00") == 360_000.0)
            }
        }

        @Suite("partial clock: mm:ss[.fraction]") struct PartialClock {
            @Test func basic() {
                #expect(SMILParser.parseClockValue("23:45") == 1425.0)
            }

            @Test func zero() {
                #expect(SMILParser.parseClockValue("0:00") == 0.0)
            }

            @Test func singleDigitMinutes() {
                #expect(SMILParser.parseClockValue("8:44") == 524.0)
            }

            @Test func fractionalSeconds() {
                #expect(SMILParser.parseClockValue("0:30.5") == 30.5)
            }
        }

        @Suite("timecount values") struct Timecount {
            @Test func hours() {
                #expect(SMILParser.parseClockValue("2h") == 7200.0)
            }

            @Test func fractionalHours() {
                #expect(SMILParser.parseClockValue("1.5h") == 5400.0)
            }

            @Test func minutes() {
                #expect(SMILParser.parseClockValue("30min") == 1800.0)
            }

            @Test func fractionalMinutes() {
                #expect(SMILParser.parseClockValue("0.5min") == 30.0)
            }

            @Test func seconds() {
                #expect(SMILParser.parseClockValue("45s") == 45.0)
            }

            @Test func fractionalSeconds() {
                #expect(SMILParser.parseClockValue("2.5s") == 2.5)
            }

            @Test func milliseconds() {
                #expect(SMILParser.parseClockValue("500ms") == 0.5)
            }

            @Test("milliseconds suffix takes priority over seconds suffix")
            func millisecondsPriority() {
                #expect(SMILParser.parseClockValue("1000ms") == 1.0)
            }

            @Test func plainNumber() {
                #expect(SMILParser.parseClockValue("120") == 120.0)
            }

            @Test func plainFractionalNumber() {
                #expect(SMILParser.parseClockValue("1.5") == 1.5)
            }
        }

        @Suite("whitespace handling") struct Whitespace {
            @Test func leadingAndTrailingSpaces() {
                #expect(SMILParser.parseClockValue("  30s  ") == 30.0)
            }

            @Test func leadingAndTrailingSpacesOnClock() {
                #expect(SMILParser.parseClockValue(" 1:30 ") == 90.0)
            }
        }

        @Suite("invalid input returns nil") struct Invalid {
            @Test func empty() {
                #expect(SMILParser.parseClockValue("") == nil)
            }

            @Test func whitespaceOnly() {
                #expect(SMILParser.parseClockValue("   ") == nil)
            }

            @Test func letters() {
                #expect(SMILParser.parseClockValue("abc") == nil)
            }

            @Test func unknownSuffix() {
                #expect(SMILParser.parseClockValue("1m") == nil)
            }

            @Test func nonNumericHours() {
                #expect(SMILParser.parseClockValue("x:00:00") == nil)
            }

            @Test func nonNumericMinutes() {
                #expect(SMILParser.parseClockValue("1:xx:00") == nil)
            }

            @Test func nonNumericSeconds() {
                #expect(SMILParser.parseClockValue("1:00:xx") == nil)
            }
        }
    }
}
