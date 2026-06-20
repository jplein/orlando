# Orlando

Orlando is a rendering plugin for Markdown files in Neovim.

## What it does

When a paragraph soft-wraps, Orlando keeps the wrapped lines visually aligned:

- The second and subsequent visual lines are indented **at least as much as the
  first line**.
- When a paragraph starts with a **marker**, the wrapped lines align with the
  start of the text, not the marker:

```text
- This is a bullet, and
  this is how it wraps

### This is a long
    heading, and it wraps
    like this
```

Supported markers: bullets (`-` `*` `+`), ordered lists (`1.` `2)`), ATX
headings (`#` … `######`), and blockquotes (`>`).

## How it works

There is no per-line "wrap indent" API in Neovim, so Orlando uses the built-in
machinery that already supports exactly this:

| Option                    | Role                                                                  |
| ------------------------- | -------------------------------------------------------------------- |
| `breakindent`             | Wrapped lines continue at the first line's indent.                   |
| `breakindentopt=list:-1`  | Marked lines continue under their *text* (width of the marker match). |
| `formatlistpat`           | The regex that decides what counts as a marker. Orlando widens it.   |
| `wrap`, `linebreak`       | Soft-wrap on, breaking at word boundaries.                           |

The only side effect worth knowing: `formatlistpat` is also consulted by `gq`
reflow, so reflowing now treats headings/blockquotes as list headers too.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "jplein/orlando" }
```

It activates automatically on Markdown buffers. `setup()` is optional.

## Configuration

```lua
require("orlando").setup({
  filetypes = { "markdown" },
  features = {
    wrap_indent = {
      enabled = true,
      wrap = true,         -- set false to leave 'wrap' untouched
      linebreak = true,    -- set false to leave 'linebreak' untouched
      breakindentopt = "list:-1",
      markers = {
        bullets = true,
        ordered = true,
        headings = true,
        blockquotes = true,
      },
    },
  },
})
```

## Development

```sh
nvim -l test/wrap_indent_spec.lua   # numeric tests (exit 0 = pass)
```

Or eyeball it: `nvim test/sample.md`, then narrow the window until lines wrap.

## Layout

```
plugin/orlando.lua              activation autocmds
lua/orlando/init.lua            public API + feature orchestration
lua/orlando/config.lua          defaults + setup() merge
lua/orlando/features/           one module per rendering feature
  wrap_indent.lua
```

New rendering features (heading styles, conceal, …) drop in as another module
under `features/` plus a config block — the core does not change.
