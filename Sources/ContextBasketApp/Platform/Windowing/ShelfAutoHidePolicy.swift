import Foundation

/// Timing is separate from AppKit so brief pointer crossings and editing can be verified.
struct ShelfAutoHidePolicy {
    enum Action: Equatable { case expand, collapse }
    var suspendedUntil: TimeInterval = 0
    private var enteredAt: TimeInterval?
    private var exitedAt: TimeInterval?

    mutating func reset() { enteredAt = nil; exitedAt = nil }

    mutating func action(collapsed: Bool, pointerInside: Bool, interacting: Bool, now: TimeInterval) -> Action? {
        guard !interacting, now >= suspendedUntil else { reset(); return nil }
        if collapsed {
            exitedAt = nil
            guard pointerInside else { enteredAt = nil; return nil }
            if enteredAt == nil { enteredAt = now }
            guard now - (enteredAt ?? now) >= 0.16 else { return nil }
            reset()
            return .expand
        }
        enteredAt = nil
        guard !pointerInside else { exitedAt = nil; return nil }
        if exitedAt == nil { exitedAt = now }
        guard now - (exitedAt ?? now) >= 0.55 else { return nil }
        reset()
        return .collapse
    }
}
