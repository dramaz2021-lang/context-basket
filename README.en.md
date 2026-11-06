# 🧺 context basket

[简体中文](README.md) | **English**

> **Gather scattered context into one basket and hand it to AI in a single paste.**

Sound familiar? You copy a paragraph from the browser, dig up a file in Finder, grab a screenshot, then shuffle back and forth pasting everything into a chat box, worried you have missed something.

**context basket** is a native macOS floating window built for exactly that. It sits quietly at the edge of your screen and collects text, images, links and files for you, one item at a time. Add a line describing your task, click **Copy**, paste once into your agent, and everything arrives neatly together. ✨

> The app interface is currently available in Simplified Chinese only.

---

## 💡 Why you'll love it

- **📋 Copy to collect**: copy text, an image, a URL or a file in any app and it lands in the basket automatically. No window switching.
- **🖱️ Just drag it in**: drop a file on an add slot. The green zone saves an independent copy; the blue zone only references the original file path.
- **📝 A note for every item**: tell the AI "this is for reference" or "focus on the third paragraph" so it understands your intent at a glance.
- **🚀 Copy the full prompt in one click**: the task, item notes and all attachment copies are copied together, so you paste only once.
- **👀 Live preview**: the full prompt updates as soon as your task or materials change. Take a look before you send.
- **🫧 Light glass bubbles**: most of the time it is just a 58-point icon. Click to expand, click again to collapse. Native Liquid Glass on macOS 26+.
- **↩️ Experiment freely**: deleting and clearing can both be undone in one step, and **your source files are never deleted**.

## 🔒 Untouched, and local

context basket **does not call any model**. It never summarizes, rewrites or guesses what you mean. It arranges your original content in a fixed structure and passes it on as is.

- Materials, notes and tasks are stored locally in `Application Support/ContextBasket`.
- Copying never touches the network. URLs are kept as links; web pages are never downloaded.
- Automatic clipboard collection can be paused or resumed from the top bar at any time, and the choice survives restarts.
- Only newly copied content is collected; earlier clipboard history is never back-filled. Content marked as concealed, transient or auto-generated (for example, passwords copied from a password manager) is skipped.
- Prompts copied by the app itself are never collected back.

## 🎬 Get started in four steps

1. **Collect**: copy content in other apps, or drag files straight into the basket.
2. **Annotate**: add a short note to any item that needs one, then write your task in the instruction box.
3. **Check**: click **Preview** to see the full prompt.
4. **Deliver**: click **Copy**, then paste into your agent's input box and send. 🎉

> The first time you use it, macOS may ask for clipboard access. Allow it so automatic collection can work.

## 🛠️ Build from source

Running requires **macOS 14+**. Building requires Apple developer tools with the **macOS 26+ SDK**.

```sh
bash scripts/test.sh          # run the automated checks
bash scripts/build-app.sh     # build the app
open "dist/context basket.app"
```

> The build is ad-hoc signed for local use and targets your machine's CPU architecture only. Developer ID signing, notarization and prebuilt downloads are on the way.

## 📦 The details

- When copying the full prompt: with attachments, `PROMPT.txt` and every attachment copy are copied together; with text only, the text itself is copied.
- The prompt keeps only the task, attachment names and notes. Collected text and the contents of readable text files are included verbatim.
- Items that reference a source file keep its original path; the original is never handed over as an attachment.
- Each copied file is limited to 100 MB. Folders can be added as source references.
- Every copy creates an independent snapshot in `exports/<UUID>/`, so previously copied content can still be pasted after you delete the items. These snapshots are not cleaned up automatically yet.
- Click a card to preview it. Source references are revealed in Finder and opened in Quick Look; URLs open in your browser.
- The **+** menu lets you choose files, add links, paste on demand, set the default import mode, undo and quit.
- The instruction box accepts text only; dragged files and images are ignored.
- Right-click (or Control-click) the floating icon or the menu bar icon to quit the app.

<details>
<summary>🆕 What's new in 0.11.7</summary>

- The top bar now shows, in order: icon, Preview prompt, Copy prompt, Pause/Resume clipboard, Clear. Clear removes both the instruction and attachments and can be undone in one step.
- Right-click or Control-click the floating basket icon or the menu bar icon to show "Quit context basket", whether the floating icon is expanded or collapsed.
- The instruction box starts at one line and grows with line breaks and wrapping; long text scrolls inside the box.
- Instructions and attachment notes use black text, with a black caret while editing.
- The input hint hides immediately while an input method is composing, and returns if composition is cancelled and the box is empty.
- Two attachments per row; empty slots show a large "+", and a new row is added once a row fills up.
- Attachment notes are edited inside the card; the frame keeps the same size while typing, after line breaks and when done, and long notes scroll inside the editor.
- Import zones are hidden by default; the green copy and blue link zones appear only on the slot a file is dragged over.
- The floating entry, menu bar and app icons share one vector drawing of files going into a basket.
- Each bubble renders its own colorless glass. The attachment area matches the top bar's transparency, with no connecting backdrop, colored edges or outer glow. Native Liquid Glass on macOS 26+, with a translucent material fallback on older systems.

</details>

## 📚 Learn more

The following documents are written in Chinese:

- [Product spec](docs/product.md): exact behavior of every action
- [Architecture](docs/architecture.md): how the code is organized
- [Verification log](docs/compatibility.md): what was actually tested in each release
- [Roadmap](docs/roadmap.md): how the versions evolved

Bilingual guides:

- [Contributing](CONTRIBUTING.md): read this before opening an issue or changing code
- [Security policy](SECURITY.md): how to report a security issue privately

## 📄 License

Released under the [MIT License](LICENSE).

---

If context basket saves you some copy-paste round trips, a ⭐ would be much appreciated! Ideas or problems? Issues are always welcome. 💬
