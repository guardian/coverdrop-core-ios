@testable import CoverDropCore
import XCTest

final class PaddiedCompressedStringTests: XCTestCase {
    func testSuccessfullRoundtrip() throws {
        // let expected = "hello world"
        let expected = "hello world"

        let pcs = try PaddedCompressedString.fromString(text: expected)

        XCTAssertTrue(
            Constants.messagePaddingLen == pcs.value.count
        )

        let actual: String = try pcs.toString()

        XCTAssertEqual(expected, actual)
    }

    func testIsAlwaysTheSameSize() throws {
        let messages = [
            "a",
            "this is a small message",
            "this is a longer message with a few extra words"
        ]

        for message in messages {
            let pcs = try PaddedCompressedString.fromString(text: message)

            XCTAssertTrue(pcs.value.count == Constants.messagePaddingLen)
        }
    }

    func testWillErrorIfStringIsTooLong() {
        let message = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Donec hendrerit mauris nibh, et blandit ex venenatis ut. Nullam nec lorem enim.
        Nam dignissim, metus in pulvinar luctus, eros mi congue libero, non dignissim nisi nunc vitae mi.
        Proin sagittis diam quis est posuere luctus. Vivamus vitae lectus neque.
        Morbi et mollis libero, vitae vestibulum lorem.
        Etiam ornare enim vel sem placerat, nec tempus massa fringilla. Nam eu nibh at nulla aliquet mattis.
        Praesent hendrerit lacinia tempus. Vivamus molestie diam nisi, in finibus libero dictum et.
        Quisque condimentum consequat elit, in tempor augue posuere non.
        Nunc porttitor, leo eu mollis tincidunt, libero nisi fermentum libero, sed feugiat sem purus a ante.
        Donec condimentum aliquam augue, sit amet aliquet felis vehicula non.
        Quisque urna dolor, accumsan non ullamcorper sodales, fermentum ac mi.
        """

        XCTAssertThrowsError(try PaddedCompressedString.fromString(text: message)) { error in
            XCTAssertEqual(error as! PaddedCompressedStringError, PaddedCompressedStringError.compressedStringTooLong)
        }
    }

    func testIfDecompressionRatioTooHighThenError() throws {
        let message = String(repeating: "a", count: 10000)
        let pcs = try PaddedCompressedString.fromString(text: message)

        XCTAssertThrowsError(try pcs.toString()) { error in
            XCTAssertEqual(error as! PaddedCompressedStringError, PaddedCompressedStringError.decompressionRatioTooHigh)
        }
    }
}
