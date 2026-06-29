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
-- closes it with a second extmark per indented line: an overlay of spaces at
-- window column 0, repeated on each wrapped row (virt_text_repeat_linebreak).
-- We assert that overlay exists for indented lines (width == the indent's
-- display width) and is absent for lines with no indent -- which is what makes
-- the fill reach column 0 on continuation rows. No UI/wrap needed: the extmark
-- options are the behaviour; we verified they render correctly by hand.

local function check_overlays(name, lines, want_widths)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local cfg = require("orlando.config").options.features.code_block
  cb.apply(buf, 0, cfg)

  local ns = vim.api.nvim_get_namespaces()["orlando/code_block"]
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })

  local got = {} -- row -> overlay width, for the overlay (virt_text) extmarks
  local bad = nil -- first malformed-overlay message, if any
  for _, m in ipairs(marks) do
    local row, d = m[2], m[4]
    if d.virt_text then
      got[row] = vim.fn.strdisplaywidth(d.virt_text[1][1])
      if d.virt_text_win_col ~= 0 or d.virt_text_repeat_linebreak ~= true then
        bad = bad
          or string.format(
            "row %d overlay has win_col=%s repeat=%s (want 0 / true)",
            row,
            tostring(d.virt_text_win_col),
            tostring(d.virt_text_repeat_linebreak)
          )
      end
    end
  end

  vim.api.nvim_buf_delete(buf, { force = true })

  -- Compare the row->width maps exactly.
  local ok = bad == nil
  if ok then
    for row, w in pairs(want_widths) do
      if got[row] ~= w then
        ok = false
      end
    end
    for row in pairs(got) do
      if want_widths[row] == nil then
        ok = false
      end
    end
  end

  print(string.format("%s  %s", ok and "pass" or "FAIL", name))
  if not ok then
    if bad then
      print("       " .. bad)
    end
    local function fmt_map(t)
      local parts = {}
      for row, w in pairs(t) do
        parts[#parts + 1] = string.format("[%d]=%d", row, w)
      end
      table.sort(parts)
      return "{" .. table.concat(parts, " ") .. "}"
    end
    print(string.format("       want %s  got %s", fmt_map(want_widths), fmt_map(got)))
  end
  return ok
end

print("")

-- Indented lines get an overlay sized to their indent; the fences and the
-- flush-left line (rows 0, 2, 4) get none.
if
  not check_overlays("overlay fills breakindent of indented lines", {
    "```rust", -- row 0: fence, no indent
    "    four space indent", -- row 1: indent 4
    "no indent", -- row 2: indent 0
    "        eight space indent", -- row 3: indent 8
    "```", -- row 4: fence, no indent
  }, { [1] = 4, [3] = 8 })
then
  failed = failed + 1
end

-- A block whose lines are all flush-left needs no overlays at all.
if
  not check_overlays("no overlay when nothing is indented", {
    "```",
    "flush left",
    "```",
  }, {})
then
  failed = failed + 1
end

print("")
if failed > 0 then
  print(failed .. " failure(s)")
  os.exit(1)
end
print("all cases passed")
