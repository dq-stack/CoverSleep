# CoverSleep

**Book cover while reading, custom screensavers on menu sleep. For jailbroken Kindles, including older models like the Paperwhite 2.**

CoverSleep is a lightweight sleep-screen hack for jailbroken Kindles:

- **Asleep inside a book?** The Kindle shows that book's cover, pulled full-size from the book file and centred without stretching.
- **Asleep anywhere else** (Home, Library, Store, Settings)? It shows a random image from your own `/screensavers/` folder, never the same one twice in a row.

It keeps the stock Kindle reading experience. It **doesn't need KOReader or KUAL**, doesn't modify any Kindle system files, and doesn't start at boot, so a restart always returns the Kindle to stock behaviour.

CoverSleep is a fork of [Kindle Custom Screensaver](https://github.com/chengandre/kindle-custom-screensaver) by André Cheng, which provides the core screensaver engine.

---

## Features

- Book cover on the sleep screen while reading (MOBI, AZW and AZW3 books with an embedded cover)
- Random custom PNG screensavers everywhere else, with no back-to-back repeats
- Falls back to your custom screensavers when a book has no cover or uses another format (KFX, PDF, …)
- Falls back to the stock Kindle screensaver if `/screensavers/` has no images
- Fast: the image appears in about half a second, with a single clean refresh on wake
- On-screen "ON" / "OFF" message when you toggle it
- One Scriptlet in the Library turns it on and off, just like opening a book
- Builds for both newer Kindles (`kindlehf`, firmware 5.16.3+) and older ones (`kindlepw2`, e.g. Paperwhite 2 on 5.12.x)

---

## Requirements

- A jailbroken Kindle with Scriptlet support
- The right package for your Kindle:

| Package | For |
| --- | --- |
| `coversleep-<version>-kindlepw2.zip` | Older soft-float firmware, e.g. Paperwhite 2 on 5.12.x |
| `coversleep-<version>-kindlehf.zip` | Newer hard-float firmware, 5.16.3 and later |

Not sure which you need? Newer Kindles on 5.16.3 or later use `kindlehf`; anything older uses `kindlepw2`.

### Tested devices

| Device | Firmware | Package |
| --- | --- | --- |
| Kindle Paperwhite 2 (6th gen) | 5.12.2.2 | `kindlepw2` |

The `kindlehf` package builds and includes every feature, but hasn't been tested on a device yet. Reports are welcome. The original project's `kindlehf` screensaver engine was tested on the Kindle 12th Gen, Paperwhite 5 and Paperwhite 6.

---

## Installation

1. Download the ZIP for your Kindle from the [latest release](../../releases/latest).
2. Extract it on your computer. It contains three folders:

   ```text
   documents/       Custom Screensaver.sh (the on/off Scriptlet)
   extensions/      custom-screensaver/ (the runtime)
   screensavers/    put your PNG images here
   ```

3. Connect the Kindle over USB and copy the three folders into the root of the Kindle. If `documents` or `extensions` already exist, copy the contents into them; don't replace the whole folders.
4. Put your PNG images in `/screensavers/`. Any filename works. 758×1024 portrait suits a Paperwhite 2 exactly; other sizes are scaled to fill the screen.
5. Eject the Kindle and open **Custom Screensaver** from the Library. You'll see "Custom screensaver ON" at the bottom of the screen.

Each tap of **Custom Screensaver** moves to the next mode, and a message at the bottom of the screen says which one you're in:

1. **Covers in books** ("Custom screensaver ON - covers in books"): the book's cover while you're reading, your PNGs everywhere else.
2. **Custom everywhere** ("Custom screensaver everywhere"): your PNGs everywhere, including inside books. PNGs with transparency are drawn over the page you were reading.
3. **Off** ("Custom screensaver OFF"): the stock screensaver is restored.

The next tap after Off goes back to covers in books.

### Updating

1. Turn CoverSleep off with the Scriptlet.
2. Copy the new `documents` and `extensions` contents over the old ones.
3. Eject and turn it back on.

Your images in `/screensavers/` are never touched.

### Uninstalling

1. Turn CoverSleep off with the Scriptlet.
2. Delete `/documents/Custom Screensaver.sh` and `/extensions/custom-screensaver/`.

Keep `/screensavers/` unless you want to delete your images too.

---

## Options

- **Transparent images:** in *Custom everywhere* mode, a PNG with an alpha channel is blended over whatever was on screen when the Kindle slept (the book page or menu). Fully opaque PNGs simply cover the screen as usual.
- The current mode is stored in `/screensavers/.cover_mode` (`off` = custom everywhere). Turning CoverSleep on always starts in *Covers in books*.

---

## How it works

A small daemon listens for the Kindle's sleep and wake events.

On sleep:

```text
sleep event
   ↓
is a book open?  ── yes ──→ extract the cover from the book file (cached per book)
   │ no                         ↓
   ↓                       draw the cover, centred
pick a random PNG
   ↓
draw it full-screen
```

The open book is identified from the Kindle's book renderer (`webreader`), which holds exactly the open book's file. That makes it instant and exact, even if you sleep the moment a book opens. The Library database is only a fallback.

On wake, the screen is flash-cleared, then the Kindle redraws the page or menu with one clean refresh.

---

## Safety and recovery

- No boot modifications and no system file changes
- Amazon's screensaver module is only unloaded while CoverSleep is on, and is restored when you turn it off
- Runtime state lives in `/tmp`
- Nothing starts automatically after a reboot

If anything goes wrong, restart the Kindle.

Logs, if you need them: `extensions/custom-screensaver/custom_ss.log` and `launcher.log`. Both trim themselves automatically.

---

## Building

GitHub Actions builds both packages on every push to `main` (see `.github/workflows/build-kindlehf.yml`), using the [koxtoolchain](https://github.com/KindleModding/koxtoolchain) `kindlehf` and `kindlepw2` toolchains and the [Kindle SDK](https://github.com/KindleModding/kindle-sdk). Pushing a `vX.Y.Z` tag publishes a release with both ZIPs.

Native pieces:

- `screensaver_shield`: an X11 window that keeps the Kindle UI from drawing over the sleep image (from the original project), plus a `--refresh` mode for firmware without `xrefresh`
- `cover_extract`: pulls the embedded cover out of MOBI / AZW / AZW3 files
- `fbink`: [FBInk](https://github.com/NiLuJe/FBInk), built from source

---

## Credits

- [Kindle Custom Screensaver](https://github.com/chengandre/kindle-custom-screensaver) by André Cheng: the screensaver engine CoverSleep is built on
- [FBInk](https://github.com/NiLuJe/FBInk) by NiLuJe and contributors
- [KindleModding](https://github.com/KindleModding) for the toolchains, SDK and Scriptlet support
- Kindle Series Manager (KSM), credited by the original project for early FBInk screensaver inspiration

Licensed under the MIT License (see `LICENSE`). FBInk's licence and credits are in `licenses/FBInk/`.
