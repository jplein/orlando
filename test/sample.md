# Orlando demo

Open this file in Neovim with the plugin installed and make the window narrow
enough to soft-wrap these lines. The continuation lines should line up under
the text, not under the marker.

This is a plain paragraph that has no marker at all, so when it soft-wraps the second visual line simply keeps the same indent as the first line.

- This is a bullet, and this is a fairly long item so that it soft-wraps and you can see the continuation line align under the word "This".
- A short one.
  - A nested bullet whose continuation should align under its own text, two columns further in than its parent.

1. An ordered list item, also long enough to wrap so you can confirm the continuation aligns under the text after the "1." marker.
12) Two-digit ordinals with a paren still align correctly.

### This is a long heading, and it should wrap with the continuation aligned under the heading text

> A blockquote that runs long enough to wrap; the wrapped portion should sit under the text following the ">" marker rather than at column zero.

#hashtag-like text is not a heading (no space after #), so it wraps as a plain paragraph.

A fenced code block below. Its background should fill each line all the way to
the right edge of the window, even past short lines and the blank line:

```lua
local function greet(name)
  return "hello, " .. name

end
```
