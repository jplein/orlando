-- Numeric test for the wrap_indent feature.
--
-- breakindentopt=list:-1 indents a marked continuation line by the display
-- width of its 'formatlistpat' match. That width IS the feature's behaviour,
-- so we can verify correctness exactly without rendering: for each line,
-- assert the match width equals the column where the text begins.
--
-- Run:  nvim -l test/wrap_indent_spec.lua   (exit code 0 = pass)

vim.opt.runtimepath:append(vim.fn.getcwd())

local wi = require("orlando.features.wrap_indent")

local flp = wi.build_formatlistpat({
  bullets = true,
  ordered = true,
  headings = true,
  blockquotes = true,
})

-- Continuation indent that list:-1 would produce for `line`.
local function indent_of(line)
  local match = vim.fn.matchstr(line, flp)
  return vim.fn.strdisplaywidth(match)
end

local cases = {
  -- { line, expected continuation indent }
  { "- This is a bullet, and", 2 },
  { "* star bullet", 2 },
  { "+ plus bullet", 2 },
  { "1. ordered item", 3 },
  { "12) ordered, two digits", 4 },
  { "### This is a long", 4 },
  { "# Top heading", 2 },
  { "> a blockquote", 2 },
  { ">> nested blockquote", 3 },
  { "  - nested bullet", 4 }, -- 2 leading + "- "
  { "plain paragraph", 0 }, -- no marker -> plain breakindent only
  { "#hashtag is not a heading", 0 }, -- no space after # -> no match
}

local failed = 0
for _, case in ipairs(cases) do
  local line, want = case[1], case[2]
  local got = indent_of(line)
  local ok = got == want
  if not ok then
    failed = failed + 1
  end
  print(string.format("%s  want %2d  got %2d  |  %s", ok and "pass" or "FAIL", want, got, line))
end

print("")
print("formatlistpat = " .. flp)
print("")

if failed > 0 then
  print(failed .. " failure(s)")
  os.exit(1)
end
print("all " .. #cases .. " cases passed")
