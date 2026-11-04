import XCTest
@testable import KernelCore

final class CodeDocumentTests: XCTestCase {
    func testExactBytesAndLanguage() {
        let source = "const company = 'Apple Inc';\r\nconsole.log(company);\r\n"
        let blocks = CodeDocument.parse("説明\n```javascript\r\n" + source + "```\n完了")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].source.data(using: .utf8), source.data(using: .utf8))
        XCTAssertEqual(blocks[0].fileName, "kernel-1.js")
    }
    func testIncompleteStreamingFence() {
        XCTAssertEqual(CodeDocument.parse("```html\n<h1>Hello</h1>").first?.source, "<h1>Hello</h1>")
        XCTAssertEqual(CodeDocument.parse("```html\n<h1>Hello</h1>").first?.fencedText, "```html\n<h1>Hello</h1>")
    }
    func testAllFencesRoundTripWithoutChanges() {
        let original = "Hello Apple Inc\r\n\r\n~~~~javascript\r\nconst x = `hello`;\r\n~~~~\r\n次の説明\n```html\n<p>hi</p>"
        let reconstructed = CodeDocument.segments(original).map { segment -> String in
            switch segment { case .prose(let text): return text; case .code(let code): return code.fencedText }
        }.joined()
        XCTAssertEqual(Data(reconstructed.utf8), Data(original.utf8))
    }
    func testInlineFenceNotCode() {
        XCTAssertTrue(CodeDocument.parse("文章の中の ``` はコードではない").isEmpty)
    }
    func testLongFenceAndMultipleFiles() {
        let blocks = CodeDocument.parse("````html\n```\n````\n~~~python\nprint(42)\n~~~")
        XCTAssertEqual(blocks.map(\.source), ["```\n", "print(42)\n"])
        XCTAssertEqual(blocks.map(\.fileName), ["kernel-1.html", "kernel-2.py"])
    }
}
