-- Orlando: a rendering plugin for Markdown files in Neovim.
--
-- Public API:
--   require("orlando").setup(opts)   -- optional; override defaults
--   require("orlando").attach(buf)   -- (re)apply features to a buffer
--
-- Activation is automatic via autocmds registered in plugin/orlando.lua.

local config = require("orlando.config")

local M = {}

-- Registered features, applied in order.
local features = {
  require("orlando.features.wrap_indent"),
}

--- Is Orlando configured to act on this buffer's filetype?
---@param buf integer
---@return boolean
local function enabled_for(buf)
  local ft = vim.bo[buf].filetype
  for _, f in ipairs(config.options.filetypes) do
    if ft == f then
      return true
    end
  end
  return false
end

--- Apply every enabled feature to `buf` in `win`.
---@param buf integer
---@param win integer
local function apply(buf, win)
  for _, feature in ipairs(features) do
    local fcfg = config.options.features[feature.name]
    if fcfg and fcfg.enabled then
      feature.apply(buf, win, fcfg)
    end
  end
end

--- Override the default configuration. Optional — Orlando works out of the box.
---@param opts table|nil
function M.setup(opts)
  config.setup(opts)
end

--- (Re)apply Orlando's features to a buffer in every window that shows it.
--- Safe to call repeatedly; it is the entry point used by the autocmds.
---@param buf integer
function M.attach(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not enabled_for(buf) then
    return
  end

  local wins = vim.fn.win_findbuf(buf)
  if vim.tbl_isempty(wins) then
    -- Not displayed yet (e.g. filetype set on a hidden buffer). Apply now so
    -- buffer-local options land; window options get reapplied on BufWinEnter.
    apply(buf, vim.api.nvim_get_current_win())
  else
    for _, win in ipairs(wins) do
      apply(buf, win)
    end
  end
end

return M
