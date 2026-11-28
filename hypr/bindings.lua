-- Right Alt is not a dictation key: drop Omarchy's default push-to-talk bind.
hl.unbind("ALT + Alt_R")

-- Window focus
o.bind("SUPER + h", "Focus left window", hl.dsp.focus({ direction = "l" }))
o.rebind("SUPER + j", "Focus below window", hl.dsp.focus({ direction = "d" }))
o.rebind("SUPER + k", "Focus above window", hl.dsp.focus({ direction = "u" }))
o.rebind("SUPER + l", "Focus right window", hl.dsp.focus({ direction = "r" }))

-- Swap the active window with its neighbor
o.bind("SUPER + ALT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.rebind("SUPER + ALT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))
o.rebind("SUPER + ALT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + ALT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

-- Workspaces 1-4
for workspace = 1, 4 do
  local key = "code:" .. tostring(workspace + 9)
  o.rebind("SUPER + " .. key, "Switch to workspace " .. workspace, o.workspaces.focus(workspace))
end

local function adjacent_workspace(delta)
  return function()
    local workspace = hl.get_active_workspace()
    if not workspace then
      return
    end

    local slots = o.workspaces.slots
    local current = ((workspace.id - 1) % slots) + 1
    local target = math.max(1, math.min(slots, current + delta))
    hl.dispatch(o.workspaces.focus(target))
  end
end

o.bind("SUPER + SHIFT + H", "Previous workspace", adjacent_workspace(-1))
o.bind("SUPER + SHIFT + L", "Next workspace", adjacent_workspace(1))

-- Window resizing
o.rebind("SUPER + CTRL + H", "Expand window left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }))
o.rebind("SUPER + CTRL + L", "Shrink window left", hl.dsp.window.resize({ x = 50, y = 0, relative = true }))
o.rebind("SUPER + CTRL + K", "Shrink window up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
o.bind("SUPER + CTRL + J", "Expand window down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

-- Toggle only tiling (dwindle) and scrolling on the current workspace.
function toggle_tiling_scrolling()
  local workspace = hl.get_active_workspace()
  if not workspace or not workspace.id or workspace.id < 1 then
    return
  end

  local id = tostring(workspace.id)
  local state = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
  local dir = state .. "/omarchy/workspace-layouts"

  local function read_mode(path, pattern)
    local file = io.open(path)
    if not file then
      return nil
    end
    local content = file:read("*a")
    file:close()
    return content:match(pattern)
  end

  local current = read_mode(dir .. "/" .. id .. ".lua", 'mode = "(%a+)"')
    or read_mode(dir .. "/default.lua", 'default = "(%a+)"')
    or "dwindle"
  if current ~= "scrolling" then
    current = "dwindle"
  end

  local target = current == "dwindle" and "scrolling" or "dwindle"
  o.workspace_mode({ workspace = id, mode = target })

  local file = io.open(dir .. "/" .. id .. ".lua", "w")
  if file then
    file:write(string.format('o.workspace_mode({ workspace = "%s", mode = "%s" })\n', id, target))
    file:close()
  end

  hl.exec_cmd("omarchy-shell -q omarchy.workspaces refresh")
  hl.exec_cmd("omarchy-shell -q omarchy.dock refresh")
end

o.rebind("SUPER + SHIFT + F", "Toggle tiling/scrolling layout", toggle_tiling_scrolling) -- was: File manager


-- Applications
o.rebind("SUPER + SPACE", "Apps", "omarchy-shell omarchy.dock apps")
o.rebind("SUPER + ALT + SPACE", "Omarchy menu", { menu = "root" })
o.bind("SUPER + E", "File manager (Nautilus)", { launch = "nautilus" })
o.rebind("SUPER + T", "Terminal", [[uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"]])
o.bind("SUPER + ALT + T", "Tmux", [[uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" bash -c "tmux attach || tmux new -s Work"]])


-- Menus and utilities
o.bind("SUPER + PERIOD", "Emoji picker", "omarchy-shell shell toggle imran.emoji-picker")
o.rebind("SUPER + SHIFT + S", "Omasnap", "uwsm-app -- omasnap") -- was: Capture menu
o.rebind("SUPER + SHIFT + SLASH", "Show key bindings", "omarchy-menu-keybindings")
o.rebind("SUPER + P", "Passwords", "uwsm-app -- proton-pass")
o.rebind("SUPER + V", "Clipboard manager", "omarchy-launch-or-focus-tui clipse")


-- Universal paste on CTRL SHIFT + V: re-send a paste chord directly to the
-- focused surface, so it also works in layer-shell panels. Normal apps get
-- CTRL + V; terminals get their native CTRL SHIFT + V.
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end
  return false
end

local function universal_paste()
  if active_window_is_terminal() then
    send_shortcut_once("CTRL SHIFT", "V")()
  else
    send_shortcut_once("CTRL", "V")()
  end
end

o.rebind("CTRL + SHIFT + V", "Universal paste", universal_paste)
