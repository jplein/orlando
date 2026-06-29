-- Numeric test for the code_block feature.
--
-- Two behaviours are checked, neither needs an attached UI:
--   1. find_blocks() returns the exact 0-based inclusive line ranges to paint.
--   2. paint() (via apply) lays down the extmarks that produce a full-width
--      background -- including the overlay that fills the 'breakindent' gap at
--      the start of soft-wrapped rows (see "wrapped rows" below).
--
-- Run:  nvim -l test/code_block_spec.lua   (exit code 0 = pass)
--
-- prepend, not append: if Orlando is also installed (e.g. via home-manager it
-- lands under .local/share/nvim/site/pack/.../orlando), that copy sits earlier
-- on the runtimepath and `require` would load IT instead of this working tree --
-- so the tests would silently exercise the installed plugin. Prepending the cwd
-- guarantees the working copy wins. nvim -l does not preload these modules, so
-- this is enough; no package.loaded reset needed.
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local cb = require("orlando.features.code_block")

-- Each case: { lines, expected ranges as {from,to} 0-based inclusive }
local cases = {
  {
    name = "single backtick block, fences included",
    lines = { "before", "```lua", "print(1)", "```", "after" },
    want = { { 1, 3 } },
  },
  {
    name = "tilde fence",
    lines = { "~~~", "code", "~~~" },
    want = { { 0, 2 } },
  },
  {
    name = "two separate blocks",
    lines = { "```", "a", "```", "text", "```", "b", "```" },
    want = { { 0, 2 }, { 4, 6 } },
  },
  {
    name = "indented fence still matches",
    lines = { "  ```", "  code", "  ```" },
    want = { { 0, 2 } },
  },
  {
    name = "longer fence, inner ``` is content not a close",
    lines = { "````", "```", "still in block", "````" },
    want = { { 0, 3 } },
  },
  {
    name = "close must have no info string",
    lines = { "```", "x", "```js", "y", "```" },
    want = { { 0, 4 } },
  },
  {
    name = "unterminated fence runs to end of buffer",
    lines = { "text", "```", "code", "more" },
    want = { { 1, 3 } },
  },
  {
    name = "fewer than three ticks is not a fence",
    lines = { "``inline``", "plain" },
    want = {},
  },
  {
    name = "no code blocks",
    lines = { "# heading", "a paragraph", "- a bullet" },
    want = {},
  },
}

local function ranges_equal(got, want)
  if #got ~= #want then
    return false
  end
  for i = 1, #got do
    if got[i].from ~= want[i][1] or got[i].to ~= want[i][2] then
      return false
    end
  end
  return true
end

local function fmt(ranges, is_got)
  local parts = {}
  for _, r in ipairs(ranges) do
    local from = is_got and r.from or r[1]
    local to = is_got and r.to or r[2]
    parts[#parts + 1] = string.format("[%d,%d]", from, to)
  end
  return "{" .. table.concat(parts, " ") .. "}"
end

local failed = 0
for _, case in ipairs(cases) do
  local got = cb.find_blocks(case.lines)
  local ok = ranges_equal(got, case.want)
  if not ok then
    failed = failed + 1
  end
  print(string.format("%s  %s", ok and "pass" or "FAIL", case.name))
  if not ok then
    print(string.format("       want %s  got %s", fmt(case.want, false), fmt(got, true)))
  end
end

-- Part 2: wrapped rows.
--
-- A soft-wrapped line is re-indented by 'breakindent', and that virtual indent
-- is drawn with the window background, not our highlight -- so the range
-- extmark leaves an unpainted gap at the start of every wrapped row. paint()
-- closes it with overlay extmarks at window column 0, repeated onto each wrapped
-- row (virt_text_repeat_linebreak):
--
--   * a "fill" overlay of spaces sized to the continuation indent. For a plain
--     line that is its leading whitespace; under 'breakindentopt=list:-1' a
--     marked line (matching 'formatlistpat') instead hangs at the marker width.
--   * for a marked line the fill would blank the marker on the FIRST row, so a
--     second "redraw" overlay (no repeat -> first row only) repaints the real
--     prefix on top.
--
-- paint() reads the continuation indent from the *window*, so the buffer must be
-- shown in one with breakindent on. We assert the fill widths and prefix
-- redraws; the extmark options are the behaviour (verified to render by hand).

-- Mirror wrap_indent's real defaults so marked lines match.
local flp = require("orlando.features.wrap_indent").build_formatlistpat({
  bullets = true,
  ordered = true,
  headings = true,
  blockquotes = true,
})

--- @param want_fills table   row -> fill width (the repeated space overlay)
--- @param want_redraws table row -> prefix string (the first-row marker redraw)
local function check_overlays(name, lines, want_fills, want_redraws)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_buf(0, buf) -- continuation indent is read from the window
  vim.wo[0].wrap = true
  vim.wo[0].breakindent = true
  vim.wo[0].breakindentopt = "list:-1"
  vim.bo[buf].formatlistpat = flp

  cb.apply(buf, 0, require("orlando.config").options.features.code_block)

  local ns = vim.api.nvim_get_namespaces()["orlando/code_block"]
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })

  local fills, redraws = {}, {} -- row -> width / prefix string
  local bad = nil
  for _, m in ipairs(marks) do
    local row, d = m[2], m[4]
    if d.virt_text then
      if d.virt_text_win_col ~= 0 then
        bad = bad or string.format("row %d overlay win_col=%s (want 0)", row, tostring(d.virt_text_win_col))
      end
      if d.virt_text_repeat_linebreak == true then
        fills[row] = vim.fn.strdisplaywidth(d.virt_text[1][1])
      else
        redraws[row] = d.virt_text[1][1]
      end
    end
  end

  local function map_eq(got, want)
    for k, v in pairs(want) do
      if got[k] ~= v then
        return false
      end
    end
    for k in pairs(got) do
      if want[k] == nil then
        return false
      end
    end
    return true
  end

  local ok = bad == nil and map_eq(fills, want_fills) and map_eq(redraws, want_redraws)

  print(string.format("%s  %s", ok and "pass" or "FAIL", name))
  if not ok then
    if bad then
      print("       " .. bad)
    end
    print("       fills   want " .. vim.inspect(want_fills):gsub("%s+", " ") .. "  got " .. vim.inspect(fills):gsub("%s+", " "))
    print("       redraws want " .. vim.inspect(want_redraws):gsub("%s+", " ") .. "  got " .. vim.inspect(redraws):gsub("%s+", " "))
  end
  return ok
end

print("")

-- Plain indented lines: fill sized to leading whitespace, no marker redraw.
-- Fences and the flush-left line (rows 0, 2, 4) get nothing.
if
  not check_overlays("plain indented lines fill to their leading whitespace", {
    "```rust", -- row 0: fence, no indent
    "    four space indent", -- row 1: indent 4
    "no indent", -- row 2: indent 0
    "        eight space indent", -- row 3: indent 8
    "```", -- row 4: fence, no indent
  }, { [1] = 4, [3] = 8 }, {})
then
  failed = failed + 1
end

-- Marker lines (list:-1): fill hangs at the marker width and the marker is
-- redrawn on the first row; a plain indented line among them still fills to its
-- whitespace with no redraw.
if
  not check_overlays("marker lines fill the hanging indent and redraw the marker", {
    "```", -- row 0
    "- a bulleted line that wraps", -- row 1: "- "  -> fill 2, redraw "- "
    "    plain four space indent", -- row 2: indent 4 -> fill 4, no redraw
    "1. an ordered item that wraps", -- row 3: "1. " -> fill 3, redraw "1. "
    "```", -- row 4
  }, { [1] = 2, [2] = 4, [3] = 3 }, { [1] = "- ", [3] = "1. " })
then
  failed = failed + 1
end

-- A block whose lines are all flush-left needs no overlays at all.
if
  not check_overlays("no overlay when nothing is indented", {
    "```",
    "flush left",
    "```",
  }, {}, {})
then
  failed = failed + 1
end

print("")
if failed > 0 then
  print(failed .. " failure(s)")
  os.exit(1)
end
print("all cases passed")
