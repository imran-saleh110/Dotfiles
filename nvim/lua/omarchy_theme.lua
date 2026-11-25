-- Dynamic Omarchy theming for Neovim.
--
-- Omarchy writes a lazy.nvim-style spec to the staged current theme. This
-- module translates that spec for vim.pack (which ignores `opts`) and applies
-- it with Aether's setup(). Aether's own hotreload watches the spec files and
-- re-applies palettes when the desktop theme changes.
local M = {}

local AETHER_SPEC = {
  src = "https://github.com/omacom/aether.nvim",
  name = "aether",
  version = "v3",
}

-- The live theme lives under ~/.local/state; the ~/.config path is kept for
-- older Omarchy installs and for manually generated specs.
local SPEC_PATHS = {
  vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua"),
  vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua"),
}

function M.spec_paths()
  return SPEC_PATHS
end

local function read_spec()
  for _, path in ipairs(SPEC_PATHS) do
    if vim.fn.filereadable(path) == 1 then
      local chunk = loadfile(path)
      if chunk then
        local ok, spec = pcall(chunk)
        if ok and type(spec) == "table" then
          return spec
        end
      end
    end
  end
  return nil
end

local function add_repo(spec)
  local src = spec[1]
  if type(src) ~= "string" then
    return
  end
  if not src:match("^https?://") then
    src = "https://github.com/" .. src .. ".git"
  end
  local version = spec.version or spec.branch
  pcall(vim.pack.add, { { src = src, name = spec.name, version = version } })
end

local function load_aether(opts)
  pcall(vim.pack.add, { AETHER_SPEC })
  local ok, aether = pcall(require, "aether")
  if not ok then
    return false
  end
  pcall(aether.setup, opts or {})
  return true
end

local function parse_spec(spec)
  local parsed = { aether_opts = nil, plugin_spec = nil, colorscheme = nil }

  if spec then
    for _, item in ipairs(spec) do
      if type(item) == "table" then
        local repo = item[1]
        if type(repo) == "string" then
          if repo:match("LazyVim") then
            -- Only used as a hint for the colorscheme name below.
          elseif repo:match("aether") then
            parsed.aether_opts = type(item.opts) == "table" and item.opts or {}
            parsed.plugin_spec = AETHER_SPEC
          else
            parsed.plugin_spec = parsed.plugin_spec or item
          end
        end
        if type(item.opts) == "table" and type(item.opts.colorscheme) == "string" then
          parsed.colorscheme = item.opts.colorscheme
        end
      end
    end
  end

  parsed.use_aether = not parsed.aether_opts
    or not parsed.colorscheme
    or parsed.colorscheme == "aether"
  parsed.desired = parsed.use_aether and "aether" or parsed.colorscheme
  return parsed
end

---Read the current Omarchy theme spec and apply it.
---@param skip_if_current? boolean Skip when the wanted colorscheme is already
---active (used by reload events after Aether has applied new palette opts).
function M.apply(skip_if_current)
  local parsed = parse_spec(read_spec())
  if skip_if_current and parsed.desired == vim.g.colors_name then
    return
  end

  if not load_aether(parsed.aether_opts or {}) then
    return
  end

  -- Generated specs always name Aether, but keep support for themes that
  -- ship a different colorscheme plugin of their own.
  if parsed.use_aether then
    pcall(vim.cmd.colorscheme, "aether")
  else
    add_repo(parsed.plugin_spec)
    pcall(vim.cmd.colorscheme, parsed.colorscheme)
  end
end

return M
