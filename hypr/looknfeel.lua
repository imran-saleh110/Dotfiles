hl.config({
  general = {
    -- No gaps between windows or borders.
    gaps_in = 1,
    gaps_out = 1,
    border_size = 1,

    col = {
      active_border = "rgba(575a60ff)",
      inactive_border = "rgba(575a60ff)",
    },
  },

  decoration = {
    -- Keep corners square. Omarchy's "sharp corners" toggle (set with
    -- `omarchy hyprland corners sharp`) also enforces this after themes.
    rounding = 0,

    -- macOS-like soft shadow: broad, slightly below the window, no hard edge.
    shadow = {
      enabled = true,
      range = 20,
      render_power = 2,
      color = "rgba(00000066)",
      color_inactive = "rgba(00000044)",
      offset = { 0, 2 },
      sharp = false,
    },
  },

  group = {
    col = {
      border_active = "rgba(e1e3e4ff)",
      border_inactive = "rgba(575a60ff)",
    },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
