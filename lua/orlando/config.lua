-- Orlando configuration: defaults + user override merging.
--
-- The plugin is structured as a set of independent "features". Each feature
-- has an entry under `features.<name>` here, and a matching module under
-- `lua/orlando/features/<name>.lua`. This keeps room for future rendering
-- features (heading styles, conceal, ...) without reworking the core.

local M = {}

M.defaults = {
  -- Filetypes Orlando activates for. Checked dynamically, so changing this
  -- via setup() works even when the plugin loads before your config runs.
  filetypes = { "markdown" },

  features = {
    -- Marker-aware hanging indent for soft-wrapped paragraphs.
    wrap_indent = {
      enabled = true,

      -- Window options Orlando manages. Set any of these to false to leave
      -- the user's own value untouched.
      wrap = true, -- soft-wrap long lines
      linebreak = true, -- wrap at word boundaries, not mid-word

      -- breakindent itself is always enabled (it is the mechanism). This is
      -- its option string; list:-1 indents continuation lines of marked
      -- paragraphs to the start of the text after the marker.
      breakindentopt = "list:-1",

      -- Which block markers get text-aligned continuation lines. The first
      -- line's indent is always preserved regardless (plain breakindent).
      markers = {
        bullets = true, -- -, *, +
        ordered = true, -- 1. 2) ...
        headings = true, -- #, ##, ### ...
        blockquotes = true, -- >, >>, ...
      },
    },
  },
}

M.options = vim.deepcopy(M.defaults)

--- Merge user options over the defaults.
---@param opts table|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
