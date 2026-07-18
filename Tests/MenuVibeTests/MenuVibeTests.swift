import XCTest
@testable import MenuVibe

/// Unit tests for MenuVibe's pure logic — the parts that don't need a running app.
/// UI, Accessibility, and pasteboard behaviour are verified by hand against the
/// checklist in the README; these cover the algorithms that are easy to get subtly
/// wrong (snap geometry, fuzzy search, Markdown parsing, dedup).
final class MenuVibeTests: XCTestCase {

    // MARK: Snap geometry

    func testLeftHalfIsExactlyHalfWidthFullHeight() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = SnapAction.leftHalf.frame(in: screen)
        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 720, height: 900))
    }

    func testRightHalfStartsAtMidpoint() {
        let screen = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let frame = SnapAction.rightHalf.frame(in: screen)
        XCTAssertEqual(frame.minX, 600, accuracy: 0.001)
        XCTAssertEqual(frame.width, 500, accuracy: 0.001)
        XCTAssertEqual(frame.height, 800, accuracy: 0.001)
    }

    func testThirdsTileTheFullWidthWithoutGaps() {
        let screen = CGRect(x: 0, y: 0, width: 1500, height: 900)
        let left = SnapAction.leftThird.frame(in: screen)
        let center = SnapAction.centerThird.frame(in: screen)
        let right = SnapAction.rightThird.frame(in: screen)
        XCTAssertEqual(left.maxX, center.minX, accuracy: 0.001)
        XCTAssertEqual(center.maxX, right.minX, accuracy: 0.001)
        XCTAssertEqual(right.maxX, 1500, accuracy: 0.001)
    }

    func testCenterNeverExceedsScreen() {
        let small = CGRect(x: 0, y: 0, width: 500, height: 400)
        let frame = SnapAction.center.frame(in: small)
        XCTAssertLessThanOrEqual(frame.width, small.width)
        XCTAssertLessThanOrEqual(frame.height, small.height)
        // And stays centered.
        XCTAssertEqual(frame.midX, small.midX, accuracy: 0.001)
        XCTAssertEqual(frame.midY, small.midY, accuracy: 0.001)
    }

    // MARK: Fuzzy search

    func testFuzzyMatchesSubsequence() {
        XCTAssertTrue(Fuzzy.matches("gh", in: "GitHub"))
        XCTAssertTrue(Fuzzy.matches("mnv", in: "MenuVibe"))
        XCTAssertTrue(Fuzzy.matches("", in: "anything"))
    }

    func testFuzzyRejectsOutOfOrder() {
        XCTAssertFalse(Fuzzy.matches("bh", in: "GitHub")) // 'b' after 'h'
        XCTAssertFalse(Fuzzy.matches("xyz", in: "MenuVibe"))
    }

    func testFuzzyIsCaseAndDiacriticInsensitive() {
        XCTAssertTrue(Fuzzy.matches("cafe", in: "Café Menu"))
        XCTAssertTrue(Fuzzy.matches("RESUME", in: "résumé.pdf"))
    }

    // MARK: Clipboard de-duplication

    func testSameTextIsConsideredDuplicate() {
        let a = ClipboardItem(kind: .text, text: "hello")
        let b = ClipboardItem(kind: .text, text: "hello")
        XCTAssertTrue(a.hasSamePayload(as: b))
    }

    func testDifferentKindsAreNotDuplicates() {
        let a = ClipboardItem(kind: .text, text: "hello")
        let b = ClipboardItem(kind: .fileURL, text: "hello")
        XCTAssertFalse(a.hasSamePayload(as: b))
    }

    func testImagesDedupByFilename() {
        let a = ClipboardItem(kind: .image, imageFilename: "x.png")
        let b = ClipboardItem(kind: .image, imageFilename: "x.png")
        let c = ClipboardItem(kind: .image, imageFilename: "y.png")
        XCTAssertTrue(a.hasSamePayload(as: b))
        XCTAssertFalse(a.hasSamePayload(as: c))
    }

    func testPreviewCollapsesWhitespace() {
        let item = ClipboardItem(kind: .text, text: "line one\n\tline two")
        XCTAssertEqual(item.preview, "line one  line two")
    }

    // MARK: KeyCombo

    func testKeyComboRendersStandardGlyphs() {
        let combo = ShortcutID.summonPanel.defaultCombo
        XCTAssertTrue(combo.displayString.contains("⌘"))
        XCTAssertTrue(combo.displayString.contains("⇧"))
        XCTAssertTrue(combo.hasRequiredModifier)
    }

    func testKeyComboRoundTripsThroughCodable() throws {
        let original = ShortcutID.snapLeftHalf.defaultCombo
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: Markdown parsing

    func testMarkdownParsesHeadingsAndLists() {
        let source = """
        # Title

        Some text.

        - one
        - two

        ```
        code here
        ```
        """
        let blocks = MarkdownBlock.parse(source)
        guard case .heading(let level, let text) = blocks.first else {
            return XCTFail("expected a heading first, got \(String(describing: blocks.first))")
        }
        XCTAssertEqual(level, 1)
        XCTAssertEqual(text, "Title")
        XCTAssertTrue(blocks.contains { if case .bullet(let items) = $0 { return items == ["one", "two"] }; return false })
        XCTAssertTrue(blocks.contains { if case .code(let c) = $0 { return c == "code here" }; return false })
    }

    func testMarkdownParserNeverCrashesOnMalformedInput() {
        // A hash with no space is not a heading; an unterminated fence shouldn't hang.
        _ = MarkdownBlock.parse("#nospace\n```\nunterminated")
        _ = MarkdownBlock.parse("")
        _ = MarkdownBlock.parse(">\n>\n- ")
    }
}
