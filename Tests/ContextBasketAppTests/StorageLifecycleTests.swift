import AppKit
import Testing
@testable import ContextBasket

@Suite @MainActor struct StorageLifecycleTests {
    private func library() throws -> MaterialLibrary {
        try MaterialLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent("StorageLifecycle-\(UUID())"))
    }
    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    @Test func relaunchRemovesOnlyCopiesNoMaterialRefersTo() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("source.txt")
        try "原件".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(source), .file(source)]) { await task.value }
        let kept = library.url(for: try #require(store.items[0].assetPath))
        let removed = library.url(for: try #require(store.items[1].assetPath))
        store.remove(store.items[1].id)
        #expect(exists(removed)) // Still needed for undo in this session.
        let relaunched = BasketStore(library: library)
        #expect(relaunched.items.count == 1)
        #expect(exists(kept))
        #expect(!exists(removed.deletingLastPathComponent()))
        #expect(try String(contentsOf: source, encoding: .utf8) == "原件")
    }

    @Test func unreadableIndexIsKeptAsideWithItsCopies() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("source.txt")
        try "原件".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(source)]) { await task.value }
        let copy = library.url(for: try #require(store.items[0].assetPath))
        let index = library.directory.appendingPathComponent("basket.json")
        let newer = #"{"version":3,"items":[],"prompt":"较新版本的内容","importMode":"copy"}"#
        try newer.write(to: index, atomically: true, encoding: .utf8)
        let relaunched = BasketStore(library: library)
        #expect(relaunched.items.isEmpty && relaunched.errorMessage != nil)
        relaunched.setImportMode(.reference)
        let backup = library.directory.appendingPathComponent("basket.unreadable.json")
        #expect(try String(contentsOf: backup, encoding: .utf8) == newer)
        #expect(exists(copy))
    }

    @Test func oldSnapshotsAreRemovedWhileRecentAndNewestStay() throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let now = Date()
        func snapshot(hoursOld: Double) throws -> URL {
            let folder = try library.makeExportFolder()
            try FileManager.default.setAttributes([.creationDate: now.addingTimeInterval(-hoursOld * 3600)], ofItemAtPath: folder.path)
            return folder
        }
        let ancient = try [100, 90, 80, 70].map { try snapshot(hoursOld: $0) }
        library.pruneExports(now: now)
        #expect(ancient.map(exists) == [false, true, true, true])
        let recent = try [3, 2, 1].map { try snapshot(hoursOld: $0) }
        let yesterday = try snapshot(hoursOld: 23)
        library.pruneExports(now: now)
        #expect(ancient.map(exists) == [false, false, false, false])
        #expect((recent + [yesterday]).allSatisfy(exists))
    }

    @Test func typingIsSavedOncePerPauseAndBeforeQuitting() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        for task in store.add([.text("材料")]) { await task.value }
        let id = try #require(store.items.first?.id)
        store.setPrompt("第一版")
        store.setNote(id, "说明")
        #expect(try library.loadDocument().prompt.isEmpty)
        store.flush()
        #expect(try library.loadDocument().prompt == "第一版")
        #expect(try library.loadDocument().items.first?.note == "说明")
        store.setPrompt("第二版")
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while try library.loadDocument().prompt != "第二版", ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(try library.loadDocument().prompt == "第二版")
    }

    @Test func switchingToReferenceReleasesTheCopy() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let source = library.directory.appendingPathComponent("switch.txt")
        try "original".write(to: source, atomically: true, encoding: .utf8)
        let store = BasketStore(library: library)
        for task in store.add([.file(source)]) { await task.value }
        let id = try #require(store.items.first?.id)
        let copy = library.url(for: try #require(store.items[0].assetPath))
        await store.changeMode(id, to: .reference)?.value
        #expect(store.items[0].content == .reference(source: source, thumbnailPath: nil))
        #expect(!exists(copy))
        #expect(try String(contentsOf: source, encoding: .utf8) == "original")
    }

    @Test func version2FieldsDecodeToOneContentEachAndRoundTrip() throws {
        let json = """
        {"version":2,"prompt":"","importMode":"copy","items":[
        {"id":"ED50A3C0-3A31-4B10-8846-FED1798F0041","kind":"file","title":"a.pdf","detail":"PDF","isLoading":false,"assetPath":"assets/x/a.pdf","sourceURL":"file:///tmp/a.pdf","importMode":"copy"},
        {"id":"ED50A3C0-3A31-4B10-8846-FED1798F0042","kind":"file","title":"b.pdf","detail":"PDF","isLoading":false,"assetPath":"assets/y/b.pdf","sourceURL":"file:///tmp/b.pdf","importMode":"reference"},
        {"id":"ED50A3C0-3A31-4B10-8846-FED1798F0043","kind":"link","title":"example.com","detail":"链接","isLoading":false,"text":"https://example.com"},
        {"id":"ED50A3C0-3A31-4B10-8846-FED1798F0044","kind":"image","title":"图片.png","detail":"2 × 2","isLoading":false,"assetPath":"assets/z/图片.png","thumbnailPath":"thumbnails/z/preview.png"}
        ]}
        """
        let document = try JSONDecoder().decode(BasketDocument.self, from: Data(json.utf8))
        let source = URL(string: "file:///tmp/a.pdf")!
        #expect(document.items[0].content == .copy(Material.Copy(assetPath: "assets/x/a.pdf", sourceURL: source)))
        #expect(document.items[1].content == .reference(source: URL(string: "file:///tmp/b.pdf")!, thumbnailPath: nil))
        #expect(document.items[2].content == .link("https://example.com"))
        #expect(document.items.map(\.kind) == [.file, .file, .link, .image])
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any]
        let first = try #require((saved?["items"] as? [[String: Any]])?.first)
        #expect(first["assetPath"] as? String == "assets/x/a.pdf")
        #expect(first["importMode"] as? String == "copy")
        #expect(first["isLoading"] as? Bool == false)
        #expect(try JSONDecoder().decode(BasketDocument.self, from: JSONEncoder().encode(document)).items == document.items)
    }

    @Test func sheetsAndEditorsCloseWhenTheirMaterialLeaves() async throws {
        let library = try library()
        defer { try? FileManager.default.removeItem(at: library.directory) }
        let store = BasketStore(library: library)
        let ui = ShelfPresentation(store: store)
        for task in store.add([.text("第一份"), .text("第二份")]) { await task.value }
        ui.open(store.items[0])
        ui.editNote(store.items[1].id)
        ui.presentPromptPreview()
        store.remove(store.items[0].id)
        #expect(ui.preview == nil)
        #expect(ui.noteEditorID == store.items[0].id && ui.showPromptPreview)
        store.clearBasket()
        #expect(ui.noteEditorID == nil && !ui.showPromptPreview)
    }
}
