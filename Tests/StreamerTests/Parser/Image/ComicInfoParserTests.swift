//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
@testable import ReadiumStreamer
import XCTest

class ComicInfoParserTests: XCTestCase {
    // MARK: - Basic Parsing

    func testParseMinimalComicInfo() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test Issue</Title>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Test Issue")
    }

    func testParseCompleteComicInfo() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>The Beginning</Title>
            <Series>Batman</Series>
            <Number>1</Number>
            <Summary>The Dark Knight returns...</Summary>
            <Year>2020</Year>
            <Month>3</Month>
            <Day>15</Day>
            <Writer>Frank Miller, Bob Kane</Writer>
            <Penciller>Jim Lee</Penciller>
            <Inker>Scott Williams</Inker>
            <Colorist>Alex Sinclair</Colorist>
            <Letterer>Richard Starkings</Letterer>
            <CoverArtist>Jim Lee</CoverArtist>
            <Editor>Bob Harras</Editor>
            <Translator>John Doe</Translator>
            <Publisher>DC Comics</Publisher>
            <Imprint>Vertigo</Imprint>
            <Genre>Superhero, Action</Genre>
            <LanguageISO>en</LanguageISO>
            <GTIN>978-1234567890</GTIN>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "The Beginning")
        XCTAssertEqual(result?.series, "Batman")
        XCTAssertEqual(result?.number, "1")
        XCTAssertEqual(result?.summary, "The Dark Knight returns...")
        XCTAssertEqual(result?.year, 2020)
        XCTAssertEqual(result?.month, 3)
        XCTAssertEqual(result?.day, 15)
        XCTAssertEqual(result?.writers, ["Frank Miller", "Bob Kane"])
        XCTAssertEqual(result?.pencillers, ["Jim Lee"])
        XCTAssertEqual(result?.inkers, ["Scott Williams"])
        XCTAssertEqual(result?.colorists, ["Alex Sinclair"])
        XCTAssertEqual(result?.letterers, ["Richard Starkings"])
        XCTAssertEqual(result?.coverArtists, ["Jim Lee"])
        XCTAssertEqual(result?.editors, ["Bob Harras"])
        XCTAssertEqual(result?.translators, ["John Doe"])
        XCTAssertEqual(result?.publisher, "DC Comics")
        XCTAssertEqual(result?.imprint, "Vertigo")
        XCTAssertEqual(result?.genres, ["Superhero", "Action"])
        XCTAssertEqual(result?.languageISO, "en")
        XCTAssertEqual(result?.gtin, "978-1234567890")
    }

    func testParseReturnsNilForInvalidXML() {
        let xml = "not valid xml"

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertNil(result)
    }

    func testParseReturnsNilForWrongRootElement() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <WrongRoot>
            <Title>Test</Title>
        </WrongRoot>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertNil(result)
    }

    // MARK: - Other Metadata

    func testOtherMetadataCollectsUnknownTags() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Volume>2</Volume>
            <Characters>Batman, Robin</Characters>
            <AgeRating>Teen</AgeRating>
            <CustomTag>Custom Value</CustomTag>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertEqual(result?.otherMetadata["Volume"], "2")
        XCTAssertEqual(result?.otherMetadata["Characters"], "Batman, Robin")
        XCTAssertEqual(result?.otherMetadata["AgeRating"], "Teen")
        XCTAssertEqual(result?.otherMetadata["CustomTag"], "Custom Value")
    }

    // MARK: - Cover Page Detection

    func testFirstPageWithTypeFrontCover() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Pages>
                <Page Image="0" Type="Story"/>
                <Page Image="1" Type="FrontCover"/>
                <Page Image="2" Type="Story"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertEqual(result?.firstPageWithType(.frontCover)?.image, 1)
    }

    func testFirstPageWithTypeReturnsNilWhenNoCover() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Pages>
                <Page Image="0" Type="Story"/>
                <Page Image="1" Type="Story"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertNil(result?.firstPageWithType(.frontCover))
    }

    func testFirstPageWithTypeReturnsNilWhenNoPagesElement() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertNil(result?.firstPageWithType(.frontCover))
    }

    // MARK: - PageType Parsing

    func testPageTypeCaseInsensitiveParsing() {
        XCTAssertEqual(ComicInfo.PageType(rawValue: "FrontCover"), .frontCover)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "frontcover"), .frontCover)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "FRONTCOVER"), .frontCover)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Story"), .story)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "BackCover"), .backCover)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "InnerCover"), .innerCover)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Roundup"), .roundup)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Advertisement"), .advertisement)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Editorial"), .editorial)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Letters"), .letters)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Preview"), .preview)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Other"), .other)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Deleted"), .deleted)
        XCTAssertEqual(ComicInfo.PageType(rawValue: "Delete"), .deleted)
    }

    func testPageTypeReturnsNilForUnknownValue() {
        XCTAssertNil(ComicInfo.PageType(rawValue: "UnknownType"))
        XCTAssertNil(ComicInfo.PageType(rawValue: ""))
    }

    // MARK: - PageInfo Parsing

    func testPageInfoParsesAllAttributes() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Pages>
                <Page Image="0" Type="FrontCover" DoublePage="false" ImageSize="150202" Key="cover" Bookmark="Cover" ImageWidth="800" ImageHeight="1200"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertEqual(result?.pages.count, 1)
        let page = result?.pages.first
        XCTAssertEqual(page?.image, 0)
        XCTAssertEqual(page?.type, .frontCover)
        XCTAssertEqual(page?.doublePage, false)
        XCTAssertEqual(page?.imageSize, 150_202)
        XCTAssertEqual(page?.key, "cover")
        XCTAssertEqual(page?.bookmark, "Cover")
        XCTAssertEqual(page?.imageWidth, 800)
        XCTAssertEqual(page?.imageHeight, 1200)
    }

    func testPageInfoRequiresImageAttribute() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Pages>
                <Page Type="Story"/>
                <Page Image="1" Type="Story"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        // Only the page with Image attribute should be parsed
        XCTAssertEqual(result?.pages.count, 1)
        XCTAssertEqual(result?.pages.first?.image, 1)
    }

    func testPageInfoWithMinimalAttributes() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Pages>
                <Page Image="0"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertEqual(result?.pages.count, 1)
        let page = result?.pages.first
        XCTAssertEqual(page?.image, 0)
        XCTAssertNil(page?.type)
        XCTAssertNil(page?.doublePage)
        XCTAssertNil(page?.imageSize)
        XCTAssertNil(page?.key)
        XCTAssertNil(page?.bookmark)
        XCTAssertNil(page?.imageWidth)
        XCTAssertNil(page?.imageHeight)
    }

    func testPageInfoDoublePageBooleanParsing() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Pages>
                <Page Image="0" DoublePage="true"/>
                <Page Image="1" DoublePage="True"/>
                <Page Image="2" DoublePage="1"/>
                <Page Image="3" DoublePage="false"/>
                <Page Image="4" DoublePage="0"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertEqual(result?.pages.count, 5)
        XCTAssertEqual(result?.pages[0].doublePage, true)
        XCTAssertEqual(result?.pages[1].doublePage, true)
        XCTAssertEqual(result?.pages[2].doublePage, true)
        XCTAssertEqual(result?.pages[3].doublePage, false)
        XCTAssertEqual(result?.pages[4].doublePage, false)
    }

    // MARK: - Story Start Detection

    func testFirstPageWithTypeStory() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Pages>
                <Page Image="0" Type="FrontCover"/>
                <Page Image="1" Type="InnerCover"/>
                <Page Image="2" Type="Story"/>
                <Page Image="3" Type="Story"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertEqual(result?.firstPageWithType(.frontCover)?.image, 0)
        XCTAssertEqual(result?.firstPageWithType(.story)?.image, 2)
    }

    func testFirstPageWithTypeStoryReturnsNilWhenNoStoryPages() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Pages>
                <Page Image="0" Type="FrontCover"/>
                <Page Image="1" Type="Advertisement"/>
            </Pages>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertEqual(result?.firstPageWithType(.frontCover)?.image, 0)
        XCTAssertNil(result?.firstPageWithType(.story))
    }

    func testFirstPageWithTypeStoryReturnsNilWhenNoPagesElement() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)

        XCTAssertNil(result?.firstPageWithType(.story))
    }

    // MARK: - Metadata Conversion

    func testToMetadataWithSeriesAndNumber() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Issue 5</Title>
            <Series>Amazing Comics</Series>
            <Number>5</Number>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.title, "Issue 5")
        XCTAssertEqual(metadata?.belongsToSeries.count, 1)
        XCTAssertEqual(metadata?.belongsToSeries.first?.name, "Amazing Comics")
        XCTAssertEqual(metadata?.belongsToSeries.first?.position, 5.0)
    }

    func testToMetadataWithAlternateSeries() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Crossover Issue</Title>
            <Series>Batman</Series>
            <Number>10</Number>
            <AlternateSeries>Justice League</AlternateSeries>
            <AlternateNumber>3</AlternateNumber>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.belongsToSeries.count, 2)
        XCTAssertEqual(metadata?.belongsToSeries[0].name, "Batman")
        XCTAssertEqual(metadata?.belongsToSeries[0].position, 10.0)
        XCTAssertEqual(metadata?.belongsToSeries[1].name, "Justice League")
        XCTAssertEqual(metadata?.belongsToSeries[1].position, 3.0)
    }

    func testToMetadataWithFractionalNumber() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Issue 5.5</Title>
            <Series>Amazing Comics</Series>
            <Number>5.5</Number>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.belongsToSeries.first?.position, 5.5)
    }

    func testToMetadataWithNonNumericNumber() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Annual Issue</Title>
            <Series>Amazing Comics</Series>
            <Number>Annual 1</Number>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        // Non-numeric number should result in nil position
        XCTAssertNil(metadata?.belongsToSeries.first?.position)
    }

    func testToMetadataMangaYesAndRightToLeftSetsRTL() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Manga</Title>
            <Manga>YesAndRightToLeft</Manga>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.readingProgression, .rtl)
    }

    func testToMetadataMangaYesDoesNotSetRTL() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Manga</Title>
            <Manga>Yes</Manga>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.readingProgression, .auto)
    }

    func testToMetadataMangaNoSetsAuto() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Comic</Title>
            <Manga>No</Manga>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.readingProgression, .auto)
    }

    func testToMetadataMangaCaseInsensitiveParsing() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Manga</Title>
            <Manga>YESANDRIGHTTOLEFT</Manga>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.readingProgression, .rtl)
    }

    func testToMetadataContributors() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Writer>Frank Miller, Bob Kane</Writer>
            <Penciller>Jim Lee</Penciller>
            <CoverArtist>Alex Ross</CoverArtist>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.authors.count, 2)
        XCTAssertEqual(metadata?.authors.map(\.name), ["Frank Miller", "Bob Kane"])
        XCTAssertEqual(metadata?.pencilers.count, 1)
        XCTAssertEqual(metadata?.pencilers.first?.name, "Jim Lee")
        XCTAssertEqual(metadata?.contributors.count, 1)
        XCTAssertEqual(metadata?.contributors.first?.name, "Alex Ross")
        XCTAssertEqual(metadata?.contributors.first?.roles, ["cov"])
    }

    func testToMetadataSubjects() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Genre>Superhero, Action, Adventure</Genre>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.subjects.count, 3)
        XCTAssertEqual(metadata?.subjects.map(\.name), ["Superhero", "Action", "Adventure"])
    }

    func testToMetadataPublishedDate() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Year>2020</Year>
            <Month>6</Month>
            <Day>15</Day>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: metadata!.published!)

        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }

    func testToMetadataPublishedDateYearOnly() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Year>2020</Year>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: metadata!.published!)

        XCTAssertEqual(components.year, 2020)
        XCTAssertEqual(components.month, 1) // Default to January
        XCTAssertEqual(components.day, 1) // Default to 1st
    }

    func testToMetadataOtherMetadata() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ComicInfo>
            <Title>Test</Title>
            <Volume>2</Volume>
            <Characters>Batman, Robin</Characters>
            <AgeRating>Teen</AgeRating>
        </ComicInfo>
        """

        let result = ComicInfoParser.parse(data: xml.data(using: .utf8)!, warnings: nil)
        let metadata = result?.toMetadata()

        XCTAssertEqual(metadata?.otherMetadata["https://anansi-project.github.io/docs/comicinfo/documentation#volume"] as? String, "2")
        XCTAssertEqual(metadata?.otherMetadata["https://anansi-project.github.io/docs/comicinfo/documentation#characters"] as? String, "Batman, Robin")
        XCTAssertEqual(metadata?.otherMetadata["https://anansi-project.github.io/docs/comicinfo/documentation#agerating"] as? String, "Teen")
    }
}
