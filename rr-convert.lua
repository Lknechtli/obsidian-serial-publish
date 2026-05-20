-- Load settings from rr-convert.settings.lua
local settings_path = os.getenv("RR_CONVERT_SETTINGS")
if not settings_path or #settings_path == 0 then
  -- Fallback: try same directory as the filter (via PANDOC_FILTER_SCRIPT_FILE or ARGV)
  settings_path = nil  -- will use defaults below
end

local settings = {}
if settings_path then
  local ok, mod = pcall(dofile, settings_path)
  if ok and type(mod) == "table" then
    settings = mod
  end
end

local rr_defaults = settings.rr_defaults or {}

-- Convenience accessors: user override first, then RR default, then empty
local heading_styles     = settings.headings     or {}
local callout_defs       = settings.callouts     or {}
local data_span_defs     = settings.data_spans   or {}
local callout_table_cfg  = settings.callout_table or {}
local code_override      = settings.code         or nil
local font_override      = settings.font         or nil
local fenced_override    = settings.fenced       or nil
local hr_override        = settings.hr           or nil

-- Effective config: override if set, else RR default
local code_cfg = code_override or rr_defaults.code or {}
local font_cfg = font_override or rr_defaults.font or {}
local fenced_cfg = fenced_override or rr_defaults.fenced or {}

-- Derive color/symbol maps for validation (used by normalize_callout_type, try_parse_callout)
local callout_colors = {}
local callout_symbols = {}
for k, v in pairs(callout_defs) do
  callout_colors[k]  = v.color
  callout_symbols[k] = v.symbol or ""
end

local function normalize_callout_type(t)
  if not t then return nil end
  if callout_colors[t] then return t end
  local base = t:match("^(.-)%-[%d]+$")
  if base and callout_colors[base] then return base end
  return nil
end

local function try_parse_callout(txt)
  local mtch = txt:match("^%[!(.-)%]")
  if mtch and callout_colors[mtch] then
    return mtch, txt:gsub("^%[!" .. mtch .. "%].*", "")
  end
  return nil, nil
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

local inline_to_html
local function collect_inner(content)
  local parts = {}
  for _, child in ipairs(content) do
    table.insert(parts, inline_to_html(child))
  end
  return table.concat(parts)
end

inline_to_html = function(el)
  if el.t == "Str" and el.text then return el.text end
  if el.t == "Space" then return " " end
  if el.t == "LineBreak" then return "\n" end
  if el.t == "SoftBreak" then return " " end
  if el.t == "Code" then
    local code_text = el.text or (el.c and el.c[2]) or ""
    return "<code>" .. escape_html(code_text) .. "</code>"
  end
  if (el.t == "Strong" or el.t == "Emph") and el.content then
    return (el.t == "Strong" and "<b>%s</b>" or "<i>%s</i>"):format(collect_inner(el.content))
  end
  if el.t == "Strikeout" and el.content then
    return ("<del>%s</del>"):format(collect_inner(el.content))
  end
  if el.t == "Link" then
    local url = (el.target or "")
    return table.concat({'<a href="', url:gsub('"','&quot;'), '">'}, '') .. collect_inner(el.content) .. '</a>'
  end
  if el.t == "Image" then
    local src = (el.source or "")
    local alt_parts = {}
    for _, child in ipairs(el.content) do
      if child.t == "Str" then table.insert(alt_parts, child.text) end
    end
    return '<img src="' .. src:gsub('"','&quot;') .. '" alt="' .. table.concat(alt_parts):gsub('"','&quot;') .. '">'
  end
  if el.t == "RawInline" and el.format == "html" then return el.text or "" end
  if el.t == "Span" and el.content then
    local inner = collect_inner(el.content)
    local attrs = el.attributes or el.attr or {}
    local data_parts = {}
    for k, v in pairs(attrs) do
      if k:match("^data-") then
        table.insert(data_parts, ' ' .. k .. '="' .. v .. '"')
      end
    end
    if #data_parts > 0 then
      return '<span' .. table.concat(data_parts) .. '>' .. inner .. '</span>'
    end
    return inner
  end
  local txt = pandoc.utils.stringify(el):gsub("^%s+", ""):gsub("%s+$", "")
  return #txt > 0 and txt or ""
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
      elseif (unwrapped.t == "Para") and unwrapped.content then
        for _, inline in ipairs(unwrapped.content) do
          if inline.t == "LineBreak" then current_section = current_section .. "\n" end
          if inline.t == "Str" and inline.text then current_section = current_section .. inline.text end
          local html = inline_to_html(inline)
          if #html > 0 then current_section = current_section .. html end
        end
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

  rendered = rendered:gsub("[-*+]%s+%[ %]", "☐"):gsub("[-*+]%s+%[%XX%]", "☑")

  -- Apply each data-* span style from settings
  for key, def in pairs(data_span_defs) do
    local tag = def.tag or "span"
    local style = def.style or ""
    rendered = rendered:gsub(
      "<span%s+([^>]*)data%-" .. key .. "=\"\"([^>]*)>(.-)</span>",
      function(_, _, inner)
        return '<' .. tag .. (style and (' style="' .. style .. '">') or '>') .. inner .. '</' .. tag .. '>'
      end
    )
  end

  local lines = {}
  local parts = {}
  local tmp = rendered:gsub("^%s*$", ""):gsub("%s+$", "")
  if #tmp > 0 then
    while true do
      local pos = tmp:find("<br />")
      if not pos then
        table.insert(parts, tmp)
        break
      end
      table.insert(parts, tmp:sub(1, pos - 1))
      tmp = tmp:sub(pos + 6)
    end
    for _, line in ipairs(parts) do
      local span_style = "display:block!important;padding-left:1em!important;text-indent:-1em!important;"
      if #line == 0 then
        span_style = span_style .. "height:1em!important;"
      end
      table.insert(lines, '<span style="' .. span_style .. '">' .. line .. '</span>')
    end
    rendered = table.concat(lines)
  else
    rendered = ""
  end

  return (rendered:gsub("&([^;])", function(c) return "&amp;" .. c end))
end

local function build_table_html(callout_type, title, processed_sections)
  local def = callout_defs[callout_type] or {}
  local color = def.color or "#9e9e9e"

  -- Shadow and border from settings
  local shadow_tpl = callout_table_cfg.shadow or 'box-shadow: -4px 4px 0 %s66!important;'
  local border_tpl = callout_table_cfg.border or 'border:4px solid %s!important;'
  local shadow_style = shadow_tpl:format(color)
  local border_style = border_tpl:format(color)

  -- Error override
  local err = def.error_override
  if err then
    shadow_style = err.shadow or shadow_style
    border_style = err.border or border_style
  end

  local num_body_sections = 0
  for _, s in ipairs(processed_sections) do
    if #s:gsub("^%s*$", "") > 0 then num_body_sections = num_body_sections + 1 end
  end

  -- Wrapper + table opening
  local wrapper_style = callout_table_cfg.wrapper_style or 'max-width:60ch!important;margin:auto;'
  local table_style   = callout_table_cfg.table_style   or 'border-spacing:0!important;background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;'
  local html = '<div style="' .. wrapper_style .. '"><table style="' .. table_style .. shadow_style .. border_style .. '"><tbody>'

  -- Title row
  local heading_style_tpl = def.heading_style or 'background:%s!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;'
  if title then
    local esc_title = escape_html(title)
    local heading_style = heading_style_tpl:format(color)
    local border_heading_tpl = def.border_heading or 'border-bottom:2px solid %s!important;'
    local bottom_border = num_body_sections > 0 and border_heading_tpl:format(color) or ''
    local prefix = callout_table_cfg.title_prefix or ''
    html = html .. '<tr><td style="' .. heading_style .. bottom_border .. '">' .. prefix .. esc_title .. '</td></tr>'
  end

  -- Body rows
  local body_style     = def.body_style     or 'padding:0.5em 1em!important;border:none!important;'
  local border_between = def.border_between or 'border-bottom:1px solid %s!important;'
  local rendered_count = 0
  for _, section_html in ipairs(processed_sections) do
    local trimmed = section_html:gsub("^%s*$", "")
    if #trimmed > 0 then
      rendered_count = rendered_count + 1
      local is_last = (rendered_count == num_body_sections)
      local sep_border = not is_last and border_between:format(color) or ''
      html = html .. '<tr><td style="' .. body_style .. sep_border .. '">' .. section_html .. '</td></tr>'
    end
  end

  return html .. '</tbody></table></div>'
end

local function convert_callout(callout_type, title, bq_content)
  callout_type = callout_colors[callout_type] and callout_type or "info"
  title = title or (callout_type:sub(1,1):upper() .. callout_type:sub(2))
  local sym = callout_symbols[callout_type] or ""
  if sym then title = sym .. title end

  local body_sections = build_body_sections(bq_content)

  local processed_sections = {}
  local is_error = (callout_type == "error")
  for _, raw_html in ipairs(body_sections) do
    table.insert(processed_sections, process_section(raw_html, is_error))
  end

  local table_html = build_table_html(callout_type, title, processed_sections)
  return pandoc.RawBlock("html", table_html)
end

return {

  -- Handle Obsidian callouts detected in blockquotes → RR-safe table blocks

  BlockQuote = function(bq)
    local callout_type = nil
    local extracted_title = nil

    for _, child in ipairs(bq.content or {}) do
      if (child.t == "Para" or child.t == "Plain") and child.content then
        callout_type, extracted_title = extract_callout_title(child.content)
      elseif child.t == "RawBlock" and child.format == "html" then
        local html_text = (child.text or ""):gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
        callout_type, _ = try_parse_callout(html_text)
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
  end,



  -- Convert headers to divs with inline styles (RR-safe — RR mangles h1-h6)

  Header = function(h)

    local level = h.level or 1

    local style = heading_styles[level]

    if not style then return h end



    local all_text = pandoc.utils.stringify(h.inlines or h.content or {})

    return pandoc.RawBlock("html", '<div style="' .. style .. '">' .. escape_html(all_text) .. '</div>')

  end,



  -- Add margin-bottom to paragraphs and strip wiki links [[text]] from Str nodes

  Para = function(para)

    if not para or not para.content then return end

    local new_content = pandoc.List:new()

    local i = 1

    while i <= #para.content do

      local elem = para.content[i]


       if elem.t == "Str" and elem.text then

        local text = elem.text

        if text:match("^%[%[") and #text > 2 then
          -- Check for complete wiki link in a single element or spanning multiple elements
          local full_text = ""
          local found_close = false
          local found_triple = false
          local j = i

          while j <= #para.content do
            local next_elem = para.content[j]
            if next_elem.t == "Str" and next_elem.text then
              full_text = full_text .. (next_elem.text)
              -- Check for triple close first, then regular close
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
            -- Triple brackets [[[Text]]] → literal [[Text]]
            if found_triple then
              local triple_match, remainder = full_text:match("^%[%[%[(.-)%]%]%](.*)")
              if triple_match then
                local trimmed = triple_match:gsub("^%s+",""):gsub("%s+$","")
                local prefix = " "
                local suffix = ""
                if remainder and #remainder > 0 then suffix = "" end
                new_content:insert(pandoc.Str(prefix .. "[[" .. trimmed .. "]]" .. suffix))
                if remainder and #remainder > 0 then
                  new_content:insert(pandoc.Str(remainder))
                end
                i = j + 1
                goto continue
              end
            end
            -- Regular wiki link [[Text]] → stripped (content replaced with trimmed text)
            local wiki_match, remainder = full_text:match("^%[%[(.-)%]%](.*)")
            if wiki_match then
              local trimmed = wiki_match:gsub("^%s+",""):gsub("%s+$","")
              local prefix = " "
              local suffix = ""
              if remainder and #remainder > 0 then suffix = "" end
              new_content:insert(pandoc.Str(prefix .. trimmed .. suffix))
            end
            if remainder and #remainder > 0 then
              new_content:insert(pandoc.Str(remainder))
            end
            i = j + 1
            goto continue
          else
            -- Can't find closing ]], treat as regular text
            new_content:insert(elem)
          end
          i = i + 1
          goto continue
        elseif text:match("\\(%[%])") then

          -- Unescape brackets

          new_content:insert(pandoc.Str(text:gsub("\\(%[%])", "%1")))

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
      if elem.t == "Str" and elem.text then
        local s = elem.text:gsub("\1LB\1LB", "[["):gsub("\1RB\1RB", "]]")
        if s ~= elem.text then
          markers:insert(pandoc.Str(s))
        else
          markers:insert(elem)
        end
      else
        markers:insert(elem)
      end
    end

    para.content = markers

    local wrapped = pandoc.List:new()

    wrapped:insert(para)

    return pandoc.Div(wrapped, {style = "margin-bottom:1em;"})

  end,



  Plain = function(plain)

    if not plain then return end

    -- Pass through if contains non-text elements (e.g., Image)
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

    txt = txt:gsub("\\(%[%])", "%1")

    txt = txt:gsub("%[%[(.+)%]%]", function(match) return " "..match:gsub("^%s+",""):gsub("%s+$","").." " end)

    -- Convert escape markers to literal brackets
    txt = txt:gsub("\1LB\1LB", "[["):gsub("\1RB\1RB", "]]")

    if type(txt) ~= "string" then txt = "" end

    return pandoc.Plain({pandoc.Str(txt)})

  end,



  -- Unescape brackets and delete wiki links in inline text nodes

  Str = function(str)
    if not str or not str.text then return str end
    -- Passthrough: escape markers are handled in Para/Plain handler
    if str.text:find("\1LB") or str.text:find("\1RB") then return str end
    return str
  end,



  -- Pass through links: Royal Road supports <a href=""> tags natively

  -- Strip HTML comments (<!-- ... -->) from raw HTML
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

  -- Pass through images, strip figcaption (alt text is enough)
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

  -- Inline code: class="rr-code" (styled by <style> block standalone).
  -- Inline style only added when user overrides rr_defaults.code.
  Code = function(el)
    local txt = el.text or (el.c and el.c[2]) or ""
    local attr = ' class="rr-code"'
    if code_override and code_override.inline_style then
      attr = attr .. ' style="' .. code_override.inline_style .. '"'
    end
    return pandoc.RawInline("html", '<code' .. attr .. '>' .. escape_html(txt) .. '</code>')
  end,

  -- Fenced code blocks: class="rr-code-block" (styled by <style> block standalone).
  -- Inline style only added when user overrides rr_defaults.fenced.
  CodeBlock = function(cb)
    local lang = cb.attributes.language or ""
    local code = escape_html(cb.text)
    local cls = 'rr-code-block' .. (#lang > 0 and (' sourceCode ' .. lang) or '')
    local attr = ' class="' .. cls .. '"'
    if fenced_override and fenced_override.inline_style then
      attr = attr .. ' style="' .. fenced_override.inline_style .. '"'
    end
    return pandoc.RawBlock("html", '<div class="sourceCode"><code' .. attr .. '>' .. code .. '</code></div>')
  end,

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
      return pandoc.RawBlock("html", '')
    end
    return div
  end,

  -- Horizontal rule: class="rr-hr" (styled by <style> block standalone).
  -- If user sets horizontal_rule in config, it overrides the entire element.
  HorizontalRule = function()
    if settings.horizontal_rule then
      return pandoc.RawBlock("html", settings.horizontal_rule)
    end
    local attr = ' class="rr-hr"'
    if hr_override and hr_override.inline_style then
      attr = attr .. ' style="' .. hr_override.inline_style .. '"'
    end
    return pandoc.RawBlock("html", '<hr' .. attr .. '>')
  end,

  -- Wrap entire document in styled div; inject <style> block for standalone viewing.
  -- RR strips <style> tags and custom classes, so these are no-ops on RR.
  -- Standalone browsers use them for faithful rendering.
  Pandoc = function(doc)
    -- Strip block-level %%...%% comments (spanning multiple paragraphs; Para handler wraps them in Divs)
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

    -- Build <style> block from rr_defaults (stripped by RR, preserved standalone)
    local rules = {}
    local rr_font = rr_defaults.font
    if rr_font and (rr_font.family or rr_font.size) then
      local parts = {}
      if rr_font.family then table.insert(parts, 'font-family:' .. rr_font.family) end
      if rr_font.size then table.insert(parts, 'font-size:' .. rr_font.size) end
      table.insert(rules, '.rr-theme{' .. table.concat(parts, ';') .. '}')
    end
    local rr_code = rr_defaults.code
    if rr_code and rr_code.inline_style then
      table.insert(rules, '.rr-code{' .. rr_code.inline_style .. '}')
    end
    local rr_fenced = rr_defaults.fenced
    if rr_fenced and rr_fenced.inline_style then
      table.insert(rules, '.rr-code-block{' .. rr_fenced.inline_style .. '}')
    end
    local rr_hr = rr_defaults.hr
    if rr_hr and rr_hr.inline_style then
      table.insert(rules, '.rr-hr{' .. rr_hr.inline_style .. '}')
    end
    local css = table.concat(rules, "")
    local style_block = pandoc.RawBlock("html", '<style>' .. css .. '</style>')

    -- Inject Google Fonts link if configured (stripped by RR, preserved standalone)
    local head_blocks = pandoc.List:new{style_block}
    local import_url = font_cfg.import_url
    if import_url and #import_url > 0 then
      table.insert(head_blocks, 1, pandoc.RawBlock("html", '<link href="' .. import_url .. '" rel="stylesheet">'))
    end

    -- Wrapper div: class for standalone, inline styles only for overrides
    local wrapper_style = settings.doc_wrapper_style or "max-width:80ch!important;margin-left:auto!important;margin-right:auto!important;"
    if font_override then
      local overrides = {}
      if font_override.family then table.insert(overrides, 'font-family:' .. font_override.family .. '!' .. 'important') end
      if font_override.size then table.insert(overrides, 'font-size:' .. font_override.size .. '!' .. 'important') end
      if #overrides > 0 then wrapper_style = wrapper_style .. table.concat(overrides, ';') .. ';' end
    end

    -- Build doc as: [head_blocks, <div open>, content, </div>]
    local final = pandoc.List:new(head_blocks)
    final:insert(pandoc.RawBlock("html", '<div class="rr-theme" style="' .. wrapper_style .. '">'))
    for _, blk in ipairs(filtered) do
      final:insert(blk)
    end
    final:insert(pandoc.RawBlock("html", '</div>'))
    doc.blocks = final
    return doc
  end,

}

