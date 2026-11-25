# imran.emoji-picker

A Windows-style emoji picker for the Omarchy shell. It opens just below the
pointer (flipping above when there is not enough room), always on top of other
windows, and inserts the chosen emoji into the focused text field.

The UI follows emoji-mart's dark theme: rounded search field, category icon
strip with an accent underline, and a grouped emoji grid with no bottom preview
panel. Emoji are ordered by popularity within Facebook-style categories:
Smileys & People, Animals & Nature, Food & Drink, Activities, Travel & Places,
Objects, Symbols and Flags.

## Install / enable

The plugin lives in `~/.config/omarchy/plugins/imran.emoji-picker/` and is
already enabled in `~/.config/omarchy/shell.json` under `plugins`.

```bash
omarchy plugin validate ~/.config/omarchy/plugins/imran.emoji-picker
omarchy plugin enable imran.emoji-picker          # if ever disabled
omarchy-shell shell summon imran.emoji-picker      # open manually
```

`SUPER + PERIOD` is bound in `~/.config/hypr/bindings.lua` to
`omarchy-shell shell toggle imran.emoji-picker`, so pressing it again closes an
open picker.

## Controls

- Type to search names, keywords or shortcodes.
- Click a category icon to jump to that group.
- `←` / `→` move one emoji, `↑` / `↓` one row, `Page Up` / `Page Down` a page.
- `Enter` inserts into the focused text field; `Shift + Enter` copies instead.
- Click an emoji to insert; `Shift + Click` copies.
- `Escape` clears the search, then closes; clicking outside also closes.

Wayland does not expose "a text field is focused" to apps. The picker therefore
opens at the pointer on the shortcut and inserts into whatever text field has
focus when you choose an emoji — the same model as Windows' emoji panel.

## Files

- `EmojiPicker.qml` — overlay UI, cursor placement, keyboard handling.
- `Picker.js` — bounded parsing/filtering of the bundled catalog.
- `data/emojis.json` — 1,870 Unicode emoji in 8 categories, ordered by
  popularity (Facebook/emoji-mart style), with GitHub aliases indexed for
  search.
- `i18n/en.json` — UI strings. Other languages fall back to English.

Emoji names, aliases and keywords come from the GitHub Emoji dataset; the
ordering comes from emoji-mart's curated `native` set. All data is bundled
locally, so the picker never needs network access at runtime.

## Tests

```bash
cd ~/.config/omarchy/plugins/imran.emoji-picker && node --test tests/picker.test.mjs
```

## Troubleshooting

```bash
journalctl -t omarchy-shell -f
omarchy-shell shell rescanPlugins
omarchy restart shell
```
