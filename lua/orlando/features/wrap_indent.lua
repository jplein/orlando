-- Feature: marker-aware hanging indent for soft-wrapped paragraphs.
--
-- Mechanism (all built-in Neovim, no extmarks/decorations — there is no
-- per-line wrap-indent API):
--
--   * 'breakindent'      makes every wrapped line continue at the first
--                        line's indent  -> "at least as much as the first line"
--   * 'breakindentopt'   "list:-1" sets the continuation indent of a *marked*
--                        line to the display width of its 'formatlistpat'
--                        match -> aligns under the text after the marker
--   * 'formatlistpat'    the regex deciding what counts as a marked line. We
--                        widen it beyond the default (ordered lists only) to
--                        cover bullets, headings and blockquotes too.

local M = {}

M.name = "wrap_indent"

--- Build a 'formatlistpat' regex (Vim regex, magic) matching the enabled
--- marker types. The match runs from the start of line through the marker and
--- its trailing whitespace, so its display width equals the column where the
--- text begins -- exactly the hanging indent list:-1 applies.
---@param markers table
---@return string|nil pattern  nil when no marker type is enabled
function M.build_formatlistpat(markers)
  local alts = {}
  if markers.ordered then
    alts[#alts + 1] = [[\d\+[.)][ \t]\+]] -- 1.  2)  12.
  end
  if markers.bullets then
    alts[#alts + 1] = [[[-*+][ \t]\+]] -- -  *  +
  end
  if markers.headings then
    alts[#alts + 1] = [[#\{1,6}[ \t]\+]] -- # .. ###### (space required)
  end
  if markers.blockquotes then
    alts[#alts + 1] = [[>\+[ \t]*]] -- >  >>  (space optional)
  end
  if #alts == 0 then
    return nil
  end
  return [[^\s*\%(]] .. table.concat(alts, [[\|]]) .. [[\)]]
end

--- Apply the feature to buffer `buf` displayed in window `win`.
---@param buf integer
---@param win integer
---@param cfg table  the feature's config (config.options.features.wrap_indent)
function M.apply(buf, win, cfg)
  if cfg.wrap then
    vim.wo[win].wrap = true
  end
  if cfg.linebreak then
    vim.wo[win].linebreak = true
  end
  vim.wo[win].breakindent = true
  vim.wo[win].breakindentopt = cfg.breakindentopt

  local flp = M.build_formatlistpat(cfg.markers)
  if flp then
    vim.bo[buf].formatlistpat = flp
  end
end

return M
