import Testing
@testable import ContextBasket

@Suite struct ShelfAutoHideTests {
    @Test func leavingCollapsesAfterGracePeriod() {
        var policy = ShelfAutoHidePolicy()
        #expect(policy.action(collapsed: false, pointerInside: true, interacting: false, now: 0) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 1) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 1.5) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 1.6) == .collapse)
    }

    @Test func returningCancelsPendingCollapse() {
        var policy = ShelfAutoHidePolicy()
        _ = policy.action(collapsed: false, pointerInside: false, interacting: false, now: 0)
        #expect(policy.action(collapsed: false, pointerInside: true, interacting: false, now: 0.4) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 0.6) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 1) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 1.2) == .collapse)
    }

    @Test func hoveringExpandsButPassingAcrossDoesNot() {
        var policy = ShelfAutoHidePolicy()
        #expect(policy.action(collapsed: true, pointerInside: true, interacting: false, now: 0) == nil)
        #expect(policy.action(collapsed: true, pointerInside: false, interacting: false, now: 0.1) == nil)
        #expect(policy.action(collapsed: true, pointerInside: true, interacting: false, now: 1) == nil)
        #expect(policy.action(collapsed: true, pointerInside: true, interacting: false, now: 1.2) == .expand)
    }

    @Test func editingMenusAndDraggingSuspendCollapse() {
        var policy = ShelfAutoHidePolicy()
        _ = policy.action(collapsed: false, pointerInside: false, interacting: false, now: 0)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: true, now: 2) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: true, now: 100) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 101) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 101.6) == .collapse)
    }

    @Test func openingFromMenuGetsTimeToReachTheShelf() {
        var policy = ShelfAutoHidePolicy()
        policy.suspendedUntil = 2
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 1) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 2.1) == nil)
        #expect(policy.action(collapsed: false, pointerInside: false, interacting: false, now: 2.7) == .collapse)
    }
}
