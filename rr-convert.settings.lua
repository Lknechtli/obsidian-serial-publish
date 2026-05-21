-- rr-convert.settings.lua
-- Configuration for the Royal Road Pandoc Lua filter.
--
-- rr_defaults: Royal Road native theme. Rendered as a <style> block at the
--    top of output. RR strips <style> tags, so these are no-ops on RR.
--    Standalone browsers use them for faithful rendering.
-- User overrides: everything else in this return table. Only values that
--    differ from rr_defaults produce inline style="..." attributes (which
--    RR preserves). If you don't override, there are zero inline styles.

local rr_defaults = {

  -- =========================================================================
  -- FONT
  -- Default document font. Applied via .rr-theme class in the <style> block.
  -- =========================================================================
  font = {
    family     = 'Open Sans, Arial, sans-serif',
    size       = '14px',
    import_url = 'https://fonts.googleapis.com/css2?family=Open+Sans:wght@400;700&display=swap',
  },

  -- =========================================================================
  -- INLINE CODE
  -- Royal Road's native <code> styling. Applied via .rr-code class.
  -- =========================================================================
  code = {
    inline_style = 'background-color:#6d737b;color:#dfdee4;font-family:consolas,monospace;font-size:14px;line-height:20px;padding:1.6px 3.2px;border-radius:3px;display:inline;overflow-wrap:break-word;',
  },
  fenced = {
    inline_style = 'background-color:#6d737b;color:#dfdee4;font-family:consolas,monospace;font-size:14px;line-height:20px;padding:1.6px 3.2px;border-radius:3px;display:block;overflow-wrap:break-word;white-space:pre;',
  },

  -- =========================================================================
  -- HORIZONTAL RULE
  -- Royal Road's native <hr> styling. Applied via .rr-hr class.
  -- =========================================================================
  hr = {
    inline_style = 'border-top:1px solid #6d737b;border-bottom:none;border-left:none;border-right:none;',
  },
}

return { rr_defaults = rr_defaults,

  -- =========================================================================
  -- HEADING STYLES
  -- Per-level inline CSS applied to the <div> that replaces each heading.
  -- =========================================================================
  headings = {
    [1] = 'font-size:2.0em;font-weight:bold;margin:1.5em 0 0.8em;',
    [2] = 'font-size:1.6em;font-weight:bold;margin:1.3em 0 0.7em;',
    [3] = 'font-size:1.3em;font-weight:bold;margin:1.1em 0 0.5em;',
    [4] = 'font-size:1.1em;font-weight:bold;margin:0.9em 0 0.4em;',
    [5] = 'font-size:1.0em;font-weight:bold;margin:0.7em 0 0.3em;',
    [6] = 'font-size:0.9em;font-weight:bold;text-transform:uppercase;margin:0.6em 0 0.2em;',
  },

  -- =========================================================================
  -- DATA-* SPAN STYLES
  -- Defines how <span data-foo=""> elements are transformed.
  --   tag    — wrapper tag name (e.g. "b", "span", "em")
  --   style  — inline CSS for the wrapper
  -- =========================================================================
  data_spans = {
    glitch = {
      tag   = 'b',
      style = 'text-shadow:-1px 0 0 rgba(255,0,0,0.7),1px 0 0 rgba(0,255,255,0.7)!important;',
    },
    -- Example of adding a new effect:
    -- rainbow = {
    --   tag   = 'span',
    --   style = 'background:linear-gradient(90deg,red,orange,yellow,green,blue,violet);-webkit-background-clip:text;color:transparent!important;',
    -- },
  },

  -- =========================================================================
  -- CALLOUT TABLE — GLOBAL STYLES
  -- Shared styles for the outer wrapper and the <table> element.
  --   %s in any string is replaced with the callout's hex color.
  -- =========================================================================
  callout_table = {
    wrapper_style = 'max-width:60ch!important;margin:auto;margin-bottom:1em!important;',
    table_style   = 'border-collapse:separate !important;border-spacing:0!important;background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;',
    shadow        = 'box-shadow: -4px 4px 0 %s66!important;',
    border        = 'border:4px solid %s!important;',
    title_prefix  = '<span style="color:#ff5f57!important;">&#11044;</span>&#8201;<span style="color:#febc2e!important;">&#11044;</span>&#8201;<span style="color:#28c840!important;">&#11044;</span>&ensp;',
  },

  -- =========================================================================
  -- CALLOUT DEFINITIONS
  -- Each key is a callout type (e.g. "info", "warning", "error", "tip").
  --
  --   color          — hex color used for backgrounds, borders, shadows
  --   symbol         — unicode symbol prepended to the title
  --   heading_style  — inline CSS for the title <td> (%s → color)
  --   body_style     — inline CSS for body <td> cells
  --   border_between — CSS for the border between body sections (%s → color)
  --   border_heading — CSS for the bottom border of the heading cell (%s → color)
  --   error_override — optional table of styles that replace shadow/border for error callouts
  -- =========================================================================
  callouts = {
    info = {
      color          = "#1e90ff",
      symbol         = "\u{2139} ",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
    },
    warning = {
      color          = "#ff5722",
      symbol         = "\u{26A0} ",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
    },
    error = {
      color          = "#f44336",
      symbol         = "\u{2716} ",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
      error_override = {
        shadow = 'box-shadow: -2px -1px 0 #ff0000!important, 2px 1px 0 #00ffff!important, -3px 2px 0 rgba(255,0,0,0.4)!important, 3px -2px 0 rgba(0,255,255,0.4)!important, -4px 4px 0 #f4433666!important;',
        border = 'border: 4px solid #f44336!important;',
      },
    },
    tip = {
      color          = "#4caf50",
      symbol         = "\u{25B6} ",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
    },
    note = {
      color          = "#8bc34a",
      symbol         = "\u{270E} ",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
    },
    task = {
      color          = "#9c27b0",
      symbol         = "\u{2611} ",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
    },
    quote = {
      color          = "#607d8b",
      symbol         = "\u{201C} ",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
    },
    example = {
      color          = "#ba68c8",
      symbol         = "\u{2637}",
      heading_style  = 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;',
      body_style     = 'padding:0.5em 1em!important;border:none!important;',
      border_between = 'border-bottom:1px solid %s!important;',
      border_heading = 'border-bottom:2px solid %s!important;',
    },
  },

  -- =========================================================================
  -- HORIZONTAL RULE
  -- =========================================================================
  horizontal_rule = '<hr style="margin:1em auto!important;max-width:80%!important;border:none!important;height:2px!important;background:#ddd!important;box-shadow:-1px 0 0 rgba(255,0,0,0.6),1px 0 0 rgba(0,255,255,0.6)!important;" />',

  -- =========================================================================
  -- DOCUMENT WRAPPER
  -- =========================================================================
  doc_wrapper_style = 'max-width:80ch!important;margin-left:auto!important;margin-right:auto!important;',

  -- =========================================================================
  -- INLINE CODE OVERRIDE
  -- display:inline MUST be inline (not just in <style>) because RR strips
  -- <style> blocks. Without this, inline code renders as block on RR.
  -- =========================================================================
  code = { inline_style = 'display:inline!important;' },
}