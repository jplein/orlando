-- Feature: full-width background for fenced code blocks.
--
-- A code block's highlight normally stops at the last character of each line,
-- so a background colour only paints the text, not the rest of the pane. This
-- feature paints every line of a fenced block edge-to-edge.
--
-- Mechanism (built-in Neovim extmarks, no dependencies):
--
--   * one extmark per code-block line, with `hl_eol = true` so the highlight
--     continues past the last character to the end of the screen line.
--   * the highlight group is background-only by default (`OrlandoCodeBlock`,
--     linked to `CursorLine`), so per-token syntax/treesitter foreground
--     colours inside the block are preserved -- we only add the background.
--
-- Extmarks are buffer-local and do not survive edits, so the feature also
-- registers a buffer-local autocmd to repaint on text changes.

local M = {}

M.name = "code_block"

local ns = vim.api.nvim_create_namespace("orlando/code_block")
local augroup = vim.api.nvim_create_augroup("orlando/code_block", { clear = false })

--- Scan buffer lines for fenced code blocks (``` or ~~~, 3+ chars).
--- Indented (4-space) code blocks are intentionally not matched.
---@param lines string[]
---@return table[] blocks  list of { from, to } 0-based inclusive line ranges
function M.find_blocks(lines)
  local blocks = {}
  local open = nil -- { row, char, len } of the current open fence, or nil

  for i, line in ipairs(lines) do
    local row = i - 1
    local indent, fence = line:match("^(%s*)([`~]+)")
    if fence and #fence >= 3 then
      if not open then
        -- Opening fence; an info string ("```lua") is allowed.
        open = { row = row, char = fence:sub(1, 1), len = #fence }
      else
        -- A closing fence must use the same char, be at least as long, and
        -- carry no info string after it. Otherwise it is block content.
        local rest = line:sub(#indent + #fence + 1)
        if fence:sub(1, 1) == open.char and #fence >= open.len and rest:match("^%s*$") then
          blocks[#blocks + 1] = { from = open.row, to = row }
          open = nil
        end
      end
    end
  end

  -- An unterminated fence (common while typing) runs to the end of the buffer.
  if open then
    blocks[#blocks + 1] = { from = open.row, to = #lines - 1 }
  end

  return blocks
end

--- Define the default highlight group once. Uses `default = true` so a user- or
--- colourscheme-defined `OrlandoCodeBlock` wins, and a link so it tracks
--- colourscheme changes automatically.
---@param cfg table
local function ensure_hl(cfg)
  if cfg.hl_group == "OrlandoCodeBlock" then
    vim.api.nvim_set_hl(0, "OrlandoCodeBlock", { link = "CursorLine", default = true })
  end
end

--- Repaint every fenced code block in `buf` with a full-width background.
---@param buf integer
---@param cfg table
local function paint(buf, cfg)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, block in ipairs(M.find_blocks(lines)) do
    for row = block.from, block.to do
      local line = lines[row + 1]

      local opts = {
        hl_group = cfg.hl_group,
        hl_eol = true, -- paint past the last character to the pane edge
        priority = cfg.priority,
      }
      if row < #lines - 1 then
        opts.end_row = row + 1
        opts.end_col = 0 -- cover the newline so the fill reaches the edge
      else
        opts.end_col = #line -- last buffer line: no next row to span to
      end
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, opts)

      -- Soft-wrapped rows are re-indented by 'breakindent', and that virtual
      -- indent is drawn with the window background, not the extmark highlight --
      -- leaving an unpainted gap at the start of every wrapped row. The range
      -- highlight above only reaches real character cells, so it cannot fill it.
      -- Overlay the indent columns with our highlight and repeat it on each
      -- wrapped row (virt_text_repeat_linebreak) so the fill reaches column 0
      -- there too. Lines with no indent have no gap, so skip them.
      local width = vim.fn.strdisplaywidth(line:match("^%s*"))
      if width > 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
          virt_text = { { string.rep(" ", width), cfg.hl_group } },
          virt_text_pos = "overlay",
          virt_text_win_col = 0,
          virt_text_repeat_linebreak = true,
          hl_mode = "combine",
          priority = cfg.priority,
        })
      end
    end
  end
end

--- Apply the feature to buffer `buf`. Paints now and keeps the buffer in sync
--- by repainting on text changes. `win` is unused (highlighting is per-buffer).
---@param buf integer
---@param win integer
---@param cfg table  the feature's config (config.options.features.code_block)
function M.apply(buf, win, cfg)
  ensure_hl(cfg)
  paint(buf, cfg)

  if not vim.b[buf].orlando_code_block_attached then
    vim.b[buf].orlando_code_block_attached = true
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = augroup,
      buffer = buf,
      callback = function()
        -- Re-read config so a later setup() change is honoured on the next edit.
        local fcfg = require("orlando.config").options.features.code_block
        paint(buf, fcfg)
      end,
    })
  end
end

return M
