import XCTest
@testable import StemSense

final class YouTubeURLParserTests: XCTestCase {
    func testStandardWatchURL() {
        XCTAssertEqual(
            YouTubeURLParser.videoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=43s"),
            "dQw4w9WgXcQ"
        )
    }

    func testShortAndMobileURLs() {
        XCTAssertEqual(YouTubeURLParser.videoID(from: "https://youtu.be/dQw4w9WgXcQ"), "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeURLParser.videoID(from: "m.youtube.com/shorts/dQw4w9WgXcQ"), "dQw4w9WgXcQ")
    }

    func testEmbedAndLiveURLs() {
        XCTAssertEqual(YouTubeURLParser.videoID(from: "https://youtube.com/embed/dQw4w9WgXcQ"), "dQw4w9WgXcQ")
        XCTAssertEqual(YouTubeURLParser.videoID(from: "https://youtube.com/live/dQw4w9WgXcQ"), "dQw4w9WgXcQ")
    }

    func testCustomDeepLink() {
        XCTAssertEqual(
            YouTubeURLParser.videoID(from: URL(string: "stemsense://watch?v=dQw4w9WgXcQ")!),
            "dQw4w9WgXcQ"
        )
    }

    func testRejectsNonYouTubeAndMalformedValues() {
        XCTAssertNil(YouTubeURLParser.videoID(from: "https://example.com/watch?v=dQw4w9WgXcQ"))
        XCTAssertNil(YouTubeURLParser.videoID(from: "not-a-video"))
        XCTAssertNil(YouTubeURLParser.videoID(from: ""))
    }
}
