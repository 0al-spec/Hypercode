import XCTest
@testable import Hypercode

final class SelectorSpecTests: XCTestCase {
    func testSpecificityOrder() {
        XCTAssertTrue(Selector.type("X").specificity < Selector.klass("y").specificity)
        XCTAssertTrue(Selector.klass("y").specificity < Selector.id("z").specificity)
        // a child selector sums components
        XCTAssertEqual(
            Selector.child(.type("A"), .type("B")).specificity,
            Specificity(ids: 0, classes: 0, types: 2)
        )
    }

    func testSimpleSelectors() {
        let button = Command(type: "Button", className: "primary", id: "ok")
        let context = NodeContext(node: button, ancestors: [])

        XCTAssertTrue(selectorSpec(.type("Button")).isSatisfiedBy(context))
        XCTAssertTrue(selectorSpec(.klass("primary")).isSatisfiedBy(context))
        XCTAssertTrue(selectorSpec(.id("ok")).isSatisfiedBy(context))

        XCTAssertFalse(selectorSpec(.type("Label")).isSatisfiedBy(context))
        XCTAssertFalse(selectorSpec(.klass("secondary")).isSatisfiedBy(context))
        XCTAssertFalse(selectorSpec(.id("cancel")).isSatisfiedBy(context))
    }

    func testChildSelectorIsDirectOnly() {
        let listen = Command(type: "Listen")
        let apiServer = Command(type: "APIServer", children: [listen])
        let context = NodeContext(node: listen, ancestors: [Command(type: "Service"), apiServer])

        XCTAssertTrue(selectorSpec(.child(.type("APIServer"), .type("Listen"))).isSatisfiedBy(context))
        // Service is the grandparent, not the direct parent.
        XCTAssertFalse(selectorSpec(.child(.type("Service"), .type("Listen"))).isSatisfiedBy(context))
    }
}
