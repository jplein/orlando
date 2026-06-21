# Orlando

Orlando is a rendering plugin for Markdown files in Neovim.

## What it does

Orlando adds small rendering touches to Markdown buffers.

### Wrap indent

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

### Code block background

A highlight normally stops at a line's last character, so a code block's
background only paints the text. Orlando fills **every line of a fenced code
block to the right edge of the pane** — so a background colour reads as one
solid block. The default highlight is background-only (linked to `CursorLine`),
so syntax colours inside the block are kept; point `hl_group` at your own group
or redefine `OrlandoCodeBlock` to change the colour.

## How it works

**Wrap indent.** There is no per-line "wrap indent" API in Neovim, so Orlando
uses the built-in machinery that already supports exactly this:

| Option                    | Role                                                                  |
| ------------------------- | -------------------------------------------------------------------- |
| `breakindent`             | Wrapped lines continue at the first line's indent.                   |
| `breakindentopt=list:-1`  | Marked lines continue under their *text* (width of the marker match). |
| `formatlistpat`           | The regex that decides what counts as a marker. Orlando widens it.   |
| `wrap`, `linebreak`       | Soft-wrap on, breaking at word boundaries.                           |

The only side effect worth knowing: `formatlistpat` is also consulted by `gq`
reflow, so reflowing now treats headings/blockquotes as list headers too.

**Code block background.** Orlando scans for fenced code blocks and places one
extmark per line with `hl_eol = true`, which continues the highlight past the
last character to the end of the screen line. Extmarks don't survive edits, so
it repaints on `TextChanged`/`TextChangedI`. Only fenced blocks are matched;
indented (4-space) blocks are left alone.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "jplein/orlando" }
```

It activates automatically on Markdown buffers. `setup()` is optional.

### Nix / home-manager

This repo is a flake. Add it as an input:

```nix
inputs.orlando.url = "github:jplein/orlando";
```

Then reference the package directly in your Neovim plugins:

```nix
programs.neovim.plugins = [ inputs.orlando.packages.${pkgs.system}.default ];
```

Or apply the overlay and pull it from `pkgs.vimPlugins`:

```nix
nixpkgs.overlays = [ inputs.orlando.overlays.default ];
# ...
programs.neovim.plugins = [ pkgs.vimPlugins.orlando ];
```

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
    code_block = {
      enabled = true,
      hl_group = "OrlandoCodeBlock",  -- background-only; links to CursorLine
      priority = 10,                  -- low, so token colours win
    },
  },
})
```

## Development

```sh
nvim -l test/wrap_indent_spec.lua   # numeric tests (exit 0 = pass)
nvim -l test/code_block_spec.lua
```

Or eyeball it: `nvim test/sample.md`, then narrow the window until lines wrap.

## Layout

```
plugin/orlando.lua              activation autocmds
lua/orlando/init.lua            public API + feature orchestration
lua/orlando/config.lua          defaults + setup() merge
lua/orlando/features/           one module per rendering feature
  wrap_indent.lua
  code_block.lua
```

New rendering features (heading styles, conceal, …) drop in as another module
under `features/` plus a config block — the core does not change.
