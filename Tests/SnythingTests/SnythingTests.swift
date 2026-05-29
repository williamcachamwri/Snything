import XCTest
@testable import Snything

final class SnythingTests: XCTestCase {
    func testSearchResultKindDetection() {
        let imageURL = URL(fileURLWithPath: "/Users/test/photo.png")
        XCTAssertEqual(SearchResult.kind(from: imageURL), .image)

        let appURL = URL(fileURLWithPath: "/Applications/Safari.app")
        XCTAssertEqual(SearchResult.kind(from: appURL), .application)

        let folderURL = URL(fileURLWithPath: "/Users/test/Documents", isDirectory: true)
        XCTAssertEqual(SearchResult.kind(from: folderURL), .folder)

        let codeURL = URL(fileURLWithPath: "/Users/test/main.swift")
        XCTAssertEqual(SearchResult.kind(from: codeURL), .code)
    }

    func testRelevanceScoring() {
        let result = SearchResult(
            url: URL(fileURLWithPath: "/Applications/Xcode.app"),
            name: "Xcode",
            path: "/Applications/Xcode.app",
            kind: .application,
            size: nil,
            modifiedDate: nil,
            relevanceScore: 1.0
        )
        XCTAssertEqual(result.displayName, "Xcode")
        XCTAssertEqual(result.kind, .application)
    }
}
