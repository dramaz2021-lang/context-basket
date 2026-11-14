import AppKit
import Carbon.HIToolbox

/// A system-wide shortcut that works while another app is in front. It needs no
/// accessibility permission; if another app already owns the shortcut, nothing is registered.
@MainActor
final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    /// Control-Option-B.
    static func toggleBasket(_ action: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(controlKey | optionKey), action: action)
    }

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }, 1, &pressed, context, &handler)
        let id = EventHotKeyID(signature: OSType(0x43424B54), id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKey)
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
