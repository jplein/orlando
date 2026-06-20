-- Numeric test for the code_block feature's fence detection.
--
-- The feature paints a full-width background over every line of a fenced code
-- block. The behaviour-defining step is which lines belong to a block, so we
-- verify find_blocks() returns the exact 0-based inclusive ranges -- no
-- rendering needed.
--
-- Run:  nvim -l test/code_block_spec.lua   (exit code 0 = pass)

vim.opt.runtimepath:append(vim.fn.getcwd())

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

print("")
if failed > 0 then
  print(failed .. " failure(s)")
  os.exit(1)
end
print("all " .. #cases .. " cases passed")
