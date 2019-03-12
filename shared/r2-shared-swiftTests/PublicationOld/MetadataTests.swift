//
//  Created by Mickaël Menu on 25.01.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import XCTest
@testable import R2Shared

class MetadataTests: XCTestCase {
    
    func testEmptyJSONSerialization() {
        let sut = Metadata()
       
        XCTAssertEqual(toJSON(sut), """
            {"languages":[],"title":""}
            """)
    }
    
    func testJSONSerialization() {
        func multilangString(_ title: String) -> MultilangString {
            let string = MultilangString()
            string.singleString = title
            return string
        }
        
        func contributor(_ name: String) -> Contributor {
            let contributor = Contributor()
            contributor.multilangName = multilangString(name)
            return contributor
        }
        
        func subject(_ name: String) -> Subject {
            let subject = Subject()
            subject.name = name
            return subject
        }
        
        func rendition() -> Rendition {
            let rendition = Rendition()
            rendition.layout = .reflowable
            rendition.flow = .paginated
            rendition.orientation = .auto
            rendition.spread = .landscape
            rendition.viewport = "1280x760"
            return rendition
        }
        
        func metadata(_ property: String, _ value: String) -> MetadataItem {
            let item = MetadataItem()
            item.property = property
            item.value = value
            return item
        }
        
        func collection(_ name: String) -> PublicationCollection {
            return PublicationCollection(name: name)
        }
        
        func belongsTo() -> BelongsTo {
            let belongsTo = BelongsTo()
            belongsTo.series = [collection("Serie 1")]
            belongsTo.collection = [collection("Collection 1"), collection("Collection 2")]
            return belongsTo
        }
        
        
        let sut = Metadata()
        sut.multilangTitle = multilangString("Title")
        sut.multilangSubtitle = multilangString("Subtitle")
        sut.direction = .ltr
        sut.languages = ["fr", "en"]
        sut.identifier = "1234"
        sut.publishers = [contributor("Publisher 1"), contributor("Publisher 2")]
        sut.imprints = [contributor("Imprint")]
        sut.contributors = [contributor("Contributor")]
        sut.authors = [contributor("Author")]
        sut.translators = [contributor("Translator")]
        sut.editors = [contributor("Editor")]
        sut.artists = [contributor("Artist")]
        sut.illustrators = [contributor("Illustrator")]
        sut.letterers = [contributor("Letterer")]
        sut.pencilers = [contributor("Penciler")]
        sut.colorists = [contributor("Colorist")]
        sut.inkers = [contributor("Inker")]
        sut.narrators = [contributor("Narrator")]
        sut.subjects = [subject("tourism"), subject("exploration")]
        sut.modified = Date(timeIntervalSinceReferenceDate: 2350)
        sut.published = "2016-09-02"
        sut.description = "Description"
        sut.rendition = rendition()
        sut.source = "Source"
        sut.epubType = ["type1", "type2"]
        sut.rights = "rights"
        sut.rdfType = "rdftype"
        sut.otherMetadata = [metadata("key1", "value1"), metadata("key2", "value2")]
        sut.belongsTo = belongsTo()
        sut.duration = 56
        
        XCTAssertEqual(toJSON(sut), """
            {"artists":[{"name":"Artist"}],"authors":[{"name":"Author"}],"colorists":[{"name":"Colorist"}],"contributors":[{"name":"Contributor"}],"editors":[{"name":"Editor"}],"identifier":"1234","illustrators":[{"name":"Illustrator"}],"imprints":[{"name":"Imprint"}],"inkers":[{"name":"Inker"}],"languages":["fr","en"],"letterers":[{"name":"Letterer"}],"modified":"2001-01-01T00:39:10+0000","narrators":[{"name":"Narrator"}],"pencilers":[{"name":"Penciler"}],"published":"2016-09-02","publishers":[{"name":"Publisher 1"},{"name":"Publisher 2"}],"rendition":{"flow":"paginated","layout":"reflowable","orientation":"auto","spread":"landscape","viewport":"1280x760"},"rights":"rights","source":"Source","subjects":[{"name":"tourism"},{"name":"exploration"}],"subtitle":"Subtitle","title":"Title","translators":[{"name":"Translator"}]}
            """)
    }
    
    func testJSONSerializationWithLocalizedTitles() {
        func multilangString(_ title: String?, _ strings: [String: String] = [:]) -> MultilangString {
            let string = MultilangString()
            string.singleString = title
            string.multiString = strings
            return string
        }
        
        
        let sut = Metadata()
        sut.multilangTitle = multilangString("Title", ["fr": "Titre", "de": "Titel"])
        sut.multilangSubtitle = multilangString(nil, ["fr": "Sous-titre"])

        XCTAssertEqual(toJSON(sut), """
            {"languages":[],"subtitle":{"fr":"Sous-titre"},"title":{"de":"Titel","fr":"Titre"}}
            """)
    }

}
