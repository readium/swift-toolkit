//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

@Suite struct URITemplateTests {
    @Suite struct Parameters {
        @Test func simpleVariables() {
            #expect(URITemplate("{x,hello,y}").parameters == ["x", "hello", "y"])
        }

        @Test func formQueryVariables() {
            #expect(URITemplate("{?x,y}").parameters == ["x", "y"])
        }

        @Test func formContinuationVariables() {
            #expect(URITemplate("{&x,y}").parameters == ["x", "y"])
        }

        @Test func trimsWhitespace() {
            #expect(URITemplate("{&end, id,name}").parameters == ["end", "id", "name"])
        }

        @Test func emptyForPlainURL() {
            #expect(URITemplate("/url").parameters == [])
        }

        @Test func mixedOperators() {
            #expect(URITemplate("/url{?x,hello,y}name{z,y,w}").parameters == ["x", "hello", "y", "z", "w"])
        }
    }

    @Suite struct Expand {
        @Suite struct SimpleString {
            @Test func multipleVariables() {
                #expect(
                    URITemplate("/url{x,hello,y}name{z,y,w}").expand(with: [
                        "x": "aaa",
                        "hello": "Hello, world",
                        "y": "b",
                        "z": "45",
                        "w": "w",
                    ]) == "/urlaaa,Hello,%20world,bname45,b,w"
                )
            }

            @Test func missingVariableExpandsToEmpty() {
                #expect(URITemplate("{x,y}").expand(with: ["x": "a"]) == "a,")
            }
        }

        @Suite struct FormQuery {
            @Test func standardExpansion() {
                #expect(
                    URITemplate("/url{?x,hello,y}name").expand(with: [
                        "x": "aaa",
                        "hello": "Hello, world",
                        "y": "b",
                    ]) == "/url?x=aaa&hello=Hello,%20world&y=bname"
                )
            }

            @Test func missingVariablesOmitted() {
                #expect(URITemplate("{?x,y}").expand(with: ["x": "a"]) == "?x=a")
            }

            @Test func allVariablesMissingExpandsToEmpty() {
                #expect(URITemplate("{?x,y}").expand(with: [:]) == "")
            }
        }

        @Suite struct FormContinuation {
            @Test func standardExpansion() {
                #expect(
                    URITemplate("{&x,y}").expand(with: ["x": "a", "y": "b"]) == "&x=a&y=b"
                )
            }

            @Test func appendsToExistingQueryString() {
                #expect(
                    URITemplate("/url?a=1{&x,y}").expand(with: ["x": "foo", "y": "bar"]) == "/url?a=1&x=foo&y=bar"
                )
            }

            @Test func trimsWhitespaceAroundVariableNames() {
                #expect(URITemplate("{& a , b }").expand(with: ["a": "1", "b": "2"]) == "&a=1&b=2")
            }

            @Test func missingVariablesOmitted() {
                #expect(URITemplate("{&x,y}").expand(with: ["x": "a"]) == "&x=a")
            }

            @Test func allVariablesMissingExpandsToEmpty() {
                #expect(URITemplate("{&x,y}").expand(with: [:]) == "")
            }
        }

        @Suite struct General {
            @Test func noVariableTemplateUnchanged() {
                #expect(URITemplate("/path").expand(with: ["search": "banana"]) == "/path")
            }

            @Test func extraParametersIgnored() {
                #expect(
                    URITemplate("/path{?search}").expand(with: ["search": "banana", "code": "14"]) == "/path?search=banana"
                )
            }

            @Test func mixedOperators() {
                #expect(
                    URITemplate("/url{?x}{&y}").expand(with: ["x": "a", "y": "b"]) == "/url?x=a&y=b"
                )
            }
        }
    }
}
