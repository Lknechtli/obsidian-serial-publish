-- ghost-convert.lua — Convert Obsidian markdown to clean HTML for Ghost CMS
-- Shares core transformations with rr-convert.lua (wiki links, callouts, etc.)
-- but outputs semantic HTML styled by the Ghost theme's CSS custom properties.

-- Load settings from rr-convert.settings.lua (RR_CONVERT_SETTINGS env var)
local settings_path = os.getenv("RR_CONVERT_SETTINGS")
if not settings_path or #settings_path == 0 then
  settings_path = nil
end
local settings = {}
if settings_path then
  local ok, mod = pcall(dofile, settings_path)
  if ok and type(mod) == "table" then
    settings = mod
  end
end

local rr_defaults = settings.rr_defaults or {}

local heading_styles     = settings.headings     or {}
local callout_defs       = settings.callouts     or {}
local callout_table_cfg  = settings.callout_table or {}
local code_override      = settings.code         or nil
local font_override      = settings.font         or nil
local fenced_override    = settings.fenced       or nil
-- Data-* span effects (class-based output for theme CSS)
local data_span_defs   = settings.data_spans or {}

local code_cfg   = code_override or rr_defaults.code or {}
local font_cfg   = font_override or rr_defaults.font or {}
local fenced_cfg = fenced_override or rr_defaults.fenced or {}

-- Derive color/symbol maps for validation
local callout_colors  = {}
local callout_symbols = {}
for k, v in pairs(callout_defs) do
  callout_colors[k]  = v.color
  callout_symbols[k] = v.symbol or ""
end

local function normalize_callout_type(t)
  if not t then return nil end
  local base = t:match("^([a-zA-Z]+)")
  if base and callout_colors[base] then return base end
  return nil
end

local function unwrap_div(elem)
  if elem.t == "Div" and #elem.content > 0 then
    return unwrap_div(elem.content[1])
  end
  return elem
end

local function escape_html(txt)
  return txt:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

-- Inline element to HTML (for callout body rendering)
local inline_to_html
local function collect_inner(content)
  local parts = {}
  for _, el in ipairs(content or {}) do
    table.insert(parts, inline_to_html(el))
  end
  return table.concat(parts)
end

inline_to_html = function(el)
  if el.t == "Str" and el.text then return el.text end
  if el.t == "Space" then return " " end
  if el.t == "SoftBreak" then return " " end
  if el.t == "LineBreak" then return "<br/>" end
  if el.t == "Emph" then return "<i>" .. collect_inner(el.content) .. "</i>" end
  if el.t == "StrongEmph" then return "<b>" .. collect_inner(el.content) .. "</b>" end
  if el.t == "Strikeout" then return "<del>" .. collect_inner(el.content) .. "</del>" end
  if el.t == "Code" then
    local txt = (el.text or ""):gsub("\1LB", "\\["):gsub("\1RB", "\\]")
    return "<code>" .. escape_html(txt) .. "</code>"
  end
  if el.t == "Link" then
    local href = el.target or el.url or ""
    return '<a href="' .. href .. '">' .. collect_inner(el.content) .. '</a>'
  end
  if el.t == "RawInline" and el.format == "html" then return el.text end
  return ""
end

local function extract_callout_title(inlines)
  local callout_type = nil
  local title_parts = {}
  local break_idx = 0

  for i, inline in ipairs(inlines) do
    if not callout_type then
      -- State: looking for [!type] marker
      if inline.t == "Str" and inline.text and inline.text:match("^%[!(.-)%]") then
        callout_type = inline.text:match("^%[!(.-)%]")
        local after_marker = inline.text:gsub("^%[!.-%]", "")
        if #after_marker > 0 then table.insert(title_parts, after_marker) end
      end
    elseif break_idx == 0 then
      -- State: collecting title until line break
      if inline.t == "LineBreak" or inline.t == "SoftBreak" then
        break_idx = i
        break
      elseif inline.t == "Space" or inline.t == "SoftBreak" then
        table.insert(title_parts, " ")
      elseif inline.t == "Str" and inline.text then
        table.insert(title_parts, inline.text)
      end
    end
  end

  if not callout_type then return nil, nil, 0 end
  return callout_type, table.concat(title_parts, ""):gsub("^%s+", ""):gsub("%s+$", ""), break_idx
end

local function build_body_sections(bq_content)
  local body_sections = {}
  local current_section = ""

  for _, cblk in ipairs(bq_content or {}) do
    local unwrapped = unwrap_div(cblk)
    local is_separator = (unwrapped.t == "HorizontalRule")
      or (cblk.t == "RawBlock" and cblk.format == "html" and cblk.text:match("^%s*<hr"))
    if is_separator then
      table.insert(body_sections, current_section)
      current_section = ""
    elseif #current_section == 0 and (#body_sections == 0) then
      -- First block: may contain the callout title + some body text
      if (unwrapped.t == "Para" or unwrapped.t == "Plain") and unwrapped.content then
        _, _, break_idx = extract_callout_title(unwrapped.content)
        local body_parts = {}
        if break_idx > 0 then
          for i = break_idx, #unwrapped.content do
            local elem = unwrapped.content[i]
            if elem.t == "LineBreak" then
              table.insert(body_parts, "\n")
            elseif elem.t == "Space" or elem.t == "SoftBreak" then
              local prev_is_str = i > 1 and (unwrapped.content[i-1].t == "Str")
              local next_is_str = i < #unwrapped.content and unwrapped.content[i+1] and unwrapped.content[i+1].t == "Str"
              if prev_is_str or next_is_str then table.insert(body_parts, " ") end
            elseif elem.t == "Str" and elem.text then
              table.insert(body_parts, elem.text)
            else
              local html = inline_to_html(elem)
              if #html > 0 then table.insert(body_parts, html) end
            end
          end
        end
        current_section = table.concat(body_parts, "")
      end
    elseif ((cblk.t == "Para") or (cblk.t == "Div")) and cblk.content then
      local unwrapped = unwrap_div(cblk)
      current_section = current_section .. "\n\n"
      for _, inline in ipairs(unwrapped.content or {}) do
        local html = inline_to_html(inline)
        if #html > 0 then current_section = current_section .. html end
      end
    end
  end

  table.insert(body_sections, current_section)
  return body_sections
end

local function process_section(raw_html, is_error)
  local clean_body = raw_html:gsub("^%s+", ""):gsub("%s+$", "")
  if is_error then
    clean_body = '<b>' .. clean_body .. '</b>'
  end
  local rendered = clean_body:gsub("\n", "<br />")

  -- Wrap in span for padding/indent (class: gh-callout-indent)
  rendered = '<span class="gh-callout-indent">' .. rendered .. '</span>'
  -- Re-escape any bare & that aren't part of entities
  return (rendered:gsub("&([^;])", function(c) return "&amp;" .. c end))
end

local function build_table_html(callout_type, title, processed_sections)
  local def = callout_defs[callout_type] or {}
  local symbol = def.symbol or ""

  local html = '<div class="gh-callout gh-callout--' .. callout_type .. '">\n'
  html = html .. '<table class="gh-callout-table"><tbody>\n'

  -- Title row with traffic lights
  local title_display = symbol ~= "" and (symbol .. " " .. title) or title
  html = html .. '<tr><td colspan="2" class="gh-callout-header"><span class="gh-traffic-light"><span class="gh-tl-red">⬤</span><span class="gh-tl-yellow">⬤</span><span class="gh-tl-green">⬤</span></span> ' .. escape_html(title_display) .. '</td></tr>\n'

  -- Body rows (skip empty sections)
  local num_body_sections = 0
  for _, s in ipairs(processed_sections) do
    if #s:gsub("^%s*$", "") > 0 then num_body_sections = num_body_sections + 1 end
  end
  local rendered_count = 0
  for idx, section in ipairs(processed_sections) do
    local trimmed = section:gsub("^%s*$", "")
    if #trimmed > 0 then
      rendered_count = rendered_count + 1
      local body_html = process_section(section, callout_type == "error")
      local cell_class = 'gh-callout-body'
      if idx > 1 then
        cell_class = cell_class .. ' gh-callout-separator'
      end
      html = html .. '<tr><td colspan="2" class="' .. cell_class .. '">' .. body_html .. '</td></tr>\n'
    end
  end

  return html .. '</tbody></table></div>'
end

local function convert_callout(callout_type, title, bq_content)
  callout_type = callout_colors[callout_type] and callout_type or "info"

  local body_sections = build_body_sections(bq_content)
  local processed = {}
  for _, section in ipairs(body_sections) do
    table.insert(processed, section)
  end

  local table_html = build_table_html(callout_type, title or "", processed)
  return pandoc.RawBlock("html", table_html)
end

local function convert_sentinels_in_text(text)
  return text:gsub("\1LB\1LB", "[["):gsub("\1RB\1RB", "]]"):gsub("\1LB", "["):gsub("\1RB", "]")
end

local function convert_sentinels_in_inline(elem)
  if not elem then return elem end
  if elem.t == "Str" and elem.text then
    local txt = convert_sentinels_in_text(elem.text)
    return pandoc.Str(txt)
  elseif elem.content and type(elem.content) == "table" then
    local new_content = {}
    for _, child in ipairs(elem.content) do
      table.insert(new_content, convert_sentinels_in_inline(child))
    end
    elem.content = new_content
    return elem
  elseif elem.c and type(elem.c) == "table" then
    local new_c = {}
    for _, child in ipairs(elem.c) do
      if type(child) == "table" and (child.t or child[1]) then
        table.insert(new_c, convert_sentinels_in_inline(child))
      else
        table.insert(new_c, child)
      end
    end
    elem.c = new_c
    return elem
  end
  return elem
end

return {

  -- Handle Obsidian callouts → styled table blocks (same as RR, Ghost needs this too)
  BlockQuote = function(bq)
    local callout_type = nil
    local extracted_title = nil

    for _, child in ipairs(bq.content or {}) do
      if (child.t == "Para" or child.t == "Plain") and child.content then
        callout_type, extracted_title = extract_callout_title(child.content)
      elseif child.t == "RawBlock" and child.format == "html" then
        local html_text = (child.text or ""):gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
        callout_type, _ = extract_callout_title({pandoc.Str(html_text)})
      elseif child.t == "Div" and #child.content > 0 then
        local inner = child.content[1]
        if (inner.t == "Para") and inner.content then
          callout_type, extracted_title = extract_callout_title(inner.content)
        end
      end
      if callout_type then break end
    end

    local norm = normalize_callout_type(callout_type)
    if norm then
      return convert_callout(norm, extracted_title or nil, bq.content)
    end

    -- Not a callout — pass through as regular blockquote (Ghost styles these)
    return bq
  end,

  -- Keep semantic headings — Ghost handles them fine via CSS
  Header = function(h)
    return h
  end,

  -- Strip wiki links and unescape brackets in paragraphs
  Para = function(para)
    if not para or not para.content then return end

    local new_content = pandoc.List:new()
    local i = 1

    while i <= #para.content do
      local elem = para.content[i]

      if elem.t == "Str" and elem.text then
        local text = elem.text

        if text:match("^%[%[") and #text > 2 then
          -- Wiki link detection — accumulate across elements
          local full_text = ""
          local found_close = false
          local found_triple = false
          local j = i

          while j <= #para.content do
            local next_elem = para.content[j]
            if next_elem.t == "Str" and next_elem.text then
              full_text = full_text .. (next_elem.text)
              if not found_close then
                if full_text:match("%]%]%]") then
                  found_triple = true
                  found_close = true
                elseif full_text:match("%]%]") then
                  found_close = true
                end
              end
            elseif next_elem.t == "Space" then
              full_text = full_text .. " "
            else
              break
            end
            if found_close then break end
            j = j + 1
          end

          if found_close then
            if found_triple then
              local triple_match, remainder = full_text:match("^%[%[%[(.-)%]%]%](.*)")
              if triple_match then
                local trimmed = triple_match:gsub("^%s+",""):gsub("%s+$","")
                new_content:insert(pandoc.Str(" [[" .. trimmed .. "]] "))
                if remainder and #remainder > 0 then
                  new_content:insert(pandoc.Str(remainder))
                end
                i = j + 1
                goto continue
              end
            end
            local wiki_match, remainder = full_text:match("^%[%[(.-)%]%](.*)")
            if wiki_match then
              local trimmed = wiki_match:gsub("^%s+",""):gsub("%s+$","")
              new_content:insert(pandoc.Str(" " .. trimmed .. " "))
            end
            if remainder and #remainder > 0 then
              new_content:insert(pandoc.Str(remainder))
            end
            i = j + 1
            goto continue
          else
            new_content:insert(elem)
          end
          i = i + 1
          goto continue
        else
          new_content:insert(elem)
        end
      else
        new_content:insert(elem)
      end

      i = i + 1
      ::continue::
    end

    -- Convert escape markers to literal brackets
    local markers = pandoc.List:new()
    for _, elem in ipairs(new_content) do
      markers:insert(convert_sentinels_in_inline(elem))
    end

    para.content = markers
    return para
  end,

  -- Plain text — strip wiki links, unescape brackets
  Plain = function(plain)
    if not plain then return end

    local has_non_text = false
    for _, child in ipairs(plain.content or {}) do
      if child.t ~= "Str" and child.t ~= "Space" and child.t ~= "SoftBreak" then
        has_non_text = true
        break
      end
    end
    if has_non_text then return plain end

    local str_parts = {}
    for _, child in ipairs(plain.content or {}) do
      if child.t == "Str" and child.text then table.insert(str_parts, child.text) end
      if child.t == "Space" then table.insert(str_parts, " ") end
    end

    local txt = table.concat(str_parts, "")
    txt = txt:gsub("%[%[(.+)%]%]", function(match) return " " .. match:gsub("^%s+",""):gsub("%s+$","") .. " " end)
    txt = txt:gsub("\1LB\1LB", "[["):gsub("\1RB\1RB", "]]"):gsub("\1LB", "["):gsub("\1RB", "]")

    if type(txt) ~= "string" then txt = "" end
    return pandoc.Plain({pandoc.Str(txt)})
  end,

  -- Passthrough for strings (escape markers handled in Para/Plain)
  Str = function(str)
    if not str or not str.text then return str end
    if str.text:find("\1LB") or str.text:find("\1RB") then return str end
    return str
  end,

  -- Strip HTML comments
  RawBlock = function(rb)
    if rb.format == "html" and rb.text:match("^%s*<!%-%-") then
      return pandoc.RawBlock("html", "")
    end
    return rb
  end,

  RawInline = function(ri)
    if ri.format == "html" and ri.text:match("^%s*<!%-%-") then
      return pandoc.Str("")
    end
    return ri
  end,

  -- Pass through images
  Figure = function(fig)
    local img_block = fig.content[1]
    if img_block and img_block.t == "Plain" then
      for _, elem in ipairs(img_block.content) do
        if elem.t == "Image" then
          return pandoc.Para({elem})
        end
      end
    end
    return fig
  end,

  -- Inline code — clean <code> tag (Ghost styles via CSS)
  Code = function(el)
    local txt = el.text or (el.c and el.c[2]) or ""
    txt = txt:gsub("\1LB", "\\["):gsub("\1RB", "\\]")
    return pandoc.RawInline("html", '<code class="gh-code">' .. escape_html(txt) .. '</code>')
  end,

  -- Fenced code blocks — clean (Ghost styles via CSS)
  CodeBlock = function(cb)
    local lang = cb.attributes.language or ""
    local code = cb.text:gsub("\1LB", "\\["):gsub("\1RB", "\\]")
    code = escape_html(code)
    local cls = 'gh-code-block' .. (#lang > 0 and (' sourceCode ' .. lang) or '')
    return pandoc.RawBlock("html", '<div class="' .. cls .. '"><code>' .. code .. '</code></div>')
  end,

  -- Strip sourceCode wrapper divs from fenced blocks (pandoc adds these)
  Div = function(div)
    local attrs = div.attributes or div.attr or {}
    local classes = attrs.class or {}
    if type(classes) == "string" then
      classes = {}
      for c in (attrs.class or ""):gmatch("%S+") do table.insert(classes, c) end
    end
    local is_source = false
    for _, c in ipairs(classes) do
      if c == "sourceCode" then is_source = true break end
    end
    if is_source then
      return pandoc.RawBlock("html", "")
    end
    return div
  end,

  -- Horizontal rule — clean <hr> (Ghost styles via CSS)
  HorizontalRule = function()
    return pandoc.RawBlock("html", '<hr>')
  end,
  -- Span: convert data-* attributes to class-based spans for theme CSS
  Span = function(span)
    local attrs = span.attributes or span.attr or {}
    for attr in pairs(attrs) do
      local effect = attr:match("^data%-(.+)$")
      if effect and data_span_defs[effect] then
        return pandoc.RawInline("html", '<span class="gh-' .. effect .. '">' .. pandoc.utils.stringify(span.content) .. '</span>')
      end
    end
    return span
  end,

  -- Wrap document in .rr-theme div for Ghost theme CSS custom properties
  Pandoc = function(doc)
    -- Strip block-level %%...%% comments
    local filtered = pandoc.List:new()
    local in_comment = false
    for _, blk in ipairs(doc.blocks) do
      local txt = ""
      if blk.t == "Plain" or blk.t == "Para" then
        txt = pandoc.utils.stringify(blk):gsub("^%s+", ""):gsub("%s+$", "")
      elseif blk.t == "Div" and #blk.content > 0 then
        txt = pandoc.utils.stringify(blk.content[1]):gsub("^%s+", ""):gsub("%s+$", "")
      end
      if txt == "%%" then
        in_comment = not in_comment
        goto continue
      end
      if not in_comment then
        filtered:insert(blk)
      end
      ::continue::
    end
    doc.blocks = filtered

    -- Wrap content in .rr-theme div for theme CSS (no embedded <style>)
    local final = pandoc.List:new()
    final:insert(pandoc.RawBlock("html", '<div class="rr-theme">'))
    for _, blk in ipairs(filtered) do
      final:insert(blk)
    end
    final:insert(pandoc.RawBlock("html", '</div>'))
    doc.blocks = final
    return doc
  end,

}
