-- Royal Road Scrubber — Pandoc Lua Filter
local heading_styles = {
  [1] = 'font-size:2.0em;font-weight:bold;margin:1.5em 0 0.8em;',
  [2] = 'font-size:1.6em;font-weight:bold;margin:1.3em 0 0.7em;',
  [3] = 'font-size:1.3em;font-weight:bold;margin:1.1em 0 0.5em;',
  [4] = 'font-size:1.1em;font-weight:bold;margin:0.9em 0 0.4em;',
  [5] = 'font-size:1.0em;font-weight:bold;margin:0.7em 0 0.3em;',
  [6] = 'font-size:0.9em;font-weight:bold;text-transform:uppercase;margin:0.6em 0 0.2em;',
}

local callout_colors = {
  info = "#1e90ff", warning = "#ff5722", error = "#f44336", tip = "#4caf50"
  , note = "#8bc34a", task = "#9c27b0", quote = "#607d8b"
}

local callout_symbols = {
  info = "\u{2139} ", warning = "\u{26A0} ", error = "\u{2716} "
  , tip = "\u{25B6} ", note = "\u{270E} ", task = "\u{2611} ", quote = "\u{201C} "
}

local function normalize_callout_type(t)
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

local function convert_callout(callout_type, title, bq_content)
  callout_type = callout_colors[callout_type] and callout_type or "info"
  title = title or (callout_type:sub(1,1):upper() .. callout_type:sub(2))
  local sym = callout_symbols[callout_type] or ""
  if sym then title = sym .. title end

  local color = callout_colors[callout_type] or "#9e9e9e"
  local is_error = (callout_type == "error")
  local shadow_color = color .. "66"
  local shadow_style = 'box-shadow: -4px 4px 0 ' .. shadow_color .. '!important;'

  local function unwrap_div(div_elem)
    if div_elem.t == "Div" and #div_elem.content > 0 then
      return unwrap_div(div_elem.content[1])
    end
    return div_elem
  end

  local function inline_to_html(el)
    if el.t == "Str" and el.text then return el.text end
    if el.t == "Space" then return " " end
    if el.t == "LineBreak" then return "\n" end
    if el.t == "SoftBreak" then return " " end
    if el.t == "Code" then
      local code_text = el.text or (el.c and el.c[2]) or ""
      return "<code>" .. code_text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;") .. "</code>"
    end
    if (el.t == "Strong" or el.t == "Emph") and el.content then
      local inner = ""
      for _, child in ipairs(el.content) do
        inner = inner .. inline_to_html(child)
      end
      return (el.t == "Strong" and "<b>%s</b>" or "<i>%s</i>"):format(inner)
    end
    if el.t == "Strikeout" and el.content then
      local inner = ""
      for _, child in ipairs(el.content) do
        inner = inner .. inline_to_html(child)
      end
      return ("<del>%s</del>"):format(inner)
    end
    if el.t == "Link" then
      local url = (el.target or "")
      local inner = ""
      for _, child in ipairs(el.content) do
        inner = inner .. inline_to_html(child)
      end
      return '<a href="' .. url:gsub('"','&quot;') .. '">' .. inner .. '</a>'
    end
    if el.t == "Image" then
      local src = (el.source or "")
      local alt_text = ""
      for _, child in ipairs(el.content) do
        if child.t == "Str" then alt_text = alt_text .. child.text end
      end
      return '<img src="' .. src:gsub('"','&quot;') .. '" alt="' .. alt_text:gsub('"','&quot;') .. '">'
    end
    if el.t == "RawInline" and el.format == "html" then return el.text or "" end
    local txt = pandoc.utils.stringify(el):gsub("^%s+", ""):gsub("%s+$", "")
    return #txt > 0 and txt or ""
  end

  -- Build body content from blockquote children  
  local inner_html = ""

  for _, cblk in ipairs(bq_content or {}) do
    if #inner_html == 0 then
      -- First child: find [!type] marker and split at first break element
      local unwrapped = unwrap_div(cblk)
      
      if (unwrapped.t == "Para" or unwrapped.t == "Plain") and unwrapped.content then
        local marker_idx = 0
        for i, inline in ipairs(unwrapped.content) do
            if inline.t == "Str" and inline.text and inline.text:match("^%[!(.-)%]") then
            marker_idx = i
            break
          end
        end

        -- Find first LineBreak or SoftBreak after the marker
        local break_idx = 0
        for i = marker_idx + 1, #unwrapped.content do
          if unwrapped.content[i].t == "LineBreak" or unwrapped.content[i].t == "SoftBreak" then
            break_idx = i
            break
          end
        end

        -- Collect body from first break onward, LineBreaks become \n
        local body_parts = {}
        if break_idx > 0 then
          for i = break_idx, #unwrapped.content do
            local elem = unwrapped.content[i]
            if elem.t == "LineBreak" then
              table.insert(body_parts, "\n")
            elseif elem.t == "Space" or elem.t == "SoftBreak" then
              -- Only add space between Str elements to avoid leading/trailing spaces
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

        -- Concatenate body parts — DO NOT strip \n characters
        inner_html = table.concat(body_parts, "")
      else
        -- Non-Para child: process normally  
        local unwrapped2 = unwrap_div(cblk)
        if (unwrapped2.t == "Para") and unwrapped2.content then
          for _, inline in ipairs(unwrapped2.content) do
            if inline.t == "LineBreak" then inner_html = inner_html .. "\n" end
            if inline.t == "Str" and inline.text then inner_html = inner_html .. inline.text end
            local html = inline_to_html(inline)
            if #html > 0 then inner_html = inner_html .. html end
          end
        end
      end
    elseif (cblk.t == "Para") and cblk.content then
      -- Subsequent Para children: extract with LineBreak preservation  
      for _, inline in ipairs(cblk.content) do
        if inline.t == "LineBreak" then inner_html = inner_html .. "\n" end
        if inline.t == "Str" and inline.text then inner_html = inner_html .. inline.text end
        local html = inline_to_html(inline)
        if #html > 0 then inner_html = inner_html .. html end
      end
    end
  end

  -- Build body content (newlines preserved as <br />)
  local clean_body = inner_html:gsub("^%s+", ""):gsub("%s+$", "")
  if is_error then
    clean_body = '<b>' .. clean_body .. '</b>'
  end
  local rendered_body = clean_body:gsub("\n", "<br />")

  -- Convert markdown checkboxes to unicode: - [ ] → ☐, - [x] → ☑
  rendered_body = rendered_body:gsub("[-*+]%s+%[ %]", "☐"):gsub("[-*+]%s+%[%XX%]", "☑")

  -- Split on <br /> and wrap each line in a block span for consistent text-indent
  local lines = {}
  local parts = {}
  local tmp = rendered_body
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
    table.insert(lines, '<span style="display:block!important;padding-left:1em!important;text-indent:-1em!important;">' .. line .. '</span>')
  end
  rendered_body = table.concat(lines)

  -- Build table HTML (RR-safe, no <pre> tags) — outer padding only, title + body as two rows
  local border_style = 'border:4px solid ' .. color .. '!important'

  if is_error then
    border_style = [[box-shadow: -2px -1px 0 #ff0000!important, 2px 1px 0 #00ffff!important, -3px 2px 0 rgba(255,0,0,0.4)!important, 3px -2px 0 rgba(0,255,255,0.4)!important;]]
    border_style = border_style .. shadow_style .. 'border: 4px solid #f44336!important;'
  end

  local table_html = '<div style="max-width:90ch!important;margin:auto;"><table style="background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;' .. shadow_style .. border_style .. '">'

  -- Title row (if present)
  if title then
    local esc_title = title:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
    local has_body = (#rendered_body > 0)
    local bottom_border = has_body and ('border-bottom:2px solid ' .. color .. '!important') or 'border-bottom:0!important'
    table_html = table_html .. '<tr><td colspan="2" style="color:' .. color .. '!important;font-weight:bold!important;padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;' .. bottom_border .. '">' .. esc_title .. '</td></tr>'
  end

  -- Body row (single row with <br /> preserving line separation)
  if #rendered_body > 0 then
    -- Only escape bare ampersands, preserve existing HTML tags from inline_to_html()
    local esc_body = rendered_body:gsub("&([^;])", function(c) return "&amp;" .. c end)
    table_html = table_html .. '<tr><td colspan="2" style="padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:0!important;">' .. esc_body .. '</td></tr>'
  end

  return pandoc.RawBlock("html", table_html .. '</tbody></table>')
end

return {

  -- Handle Obsidian callouts detected in blockquotes → RR-safe table blocks

  BlockQuote = function(bq)
    local callout_type = nil

    local extracted_title = nil

    

    for j, child in ipairs(bq.content or {}) do

        if (child.t == "Para" or child.t == "Plain") and child.content then

        local marker_idx = 0

        for i, inline in ipairs(child.content) do

            if inline.t == "Str" and inline.text and inline.text:match("^%[!(.-)%]") then

            callout_type = inline.text:match("^%[!(.-)%]")

            marker_idx = i

            break

          end

        end

        

        -- Find first LineBreak or SoftBreak after the marker

        local break_idx = 0

        for i = marker_idx + 1, #child.content do

          if child.content[i].t == "LineBreak" or child.content[i].t == "SoftBreak" then

            break_idx = i

            break

          end

        end

        

        -- Extract title: text after [!type] up to first break (or entire content if no break)

        local title_parts = {}

        local limit = break_idx > 0 and (break_idx - 1) or #child.content

        for i = marker_idx + 1, limit do

          local inline = child.content[i]

          if inline.t == "LineBreak" or inline.t == "SoftBreak" then break end

          if inline.t == "Space" or inline.t == "SoftBreak" then

            table.insert(title_parts, " ")

          elseif inline.t == "Str" and inline.text then

            table.insert(title_parts, inline.text)

          end

        end

        

        extracted_title = table.concat(title_parts, ""):gsub("^%s+", ""):gsub("%s+$", "")

        

      elseif child.t == "RawBlock" and child.format == "html" then

        local html_text = (child.text or ""):gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")

        callout_type, _ = try_parse_callout(html_text)

        

      elseif child.t == "Div" and #child.content > 0 then

        local inner = child.content[1]

          if (inner.t == "Para") and inner.content then

          local marker_idx = 0

          for i, inline in ipairs(inner.content) do

            if inline.t == "Str" and inline.text and inline.text:match("^%[!(.-)%]") then

              callout_type = inline.text:match("^%[!(.-)%]")

              marker_idx = i

              break

            end

          end

          

          local break_idx = 0

          for i = marker_idx + 1, #inner.content do

            if inner.content[i].t == "LineBreak" or inner.content[i].t == "SoftBreak" then

              break_idx = i

              break

            end

          end

          

          local title_parts = {}

          local limit = break_idx > 0 and (break_idx - 1) or #inner.content

          for i = marker_idx + 1, limit do

            local inline = inner.content[i]

            if inline.t == "LineBreak" or inline.t == "SoftBreak" then break end

            if inline.t == "Space" or inline.t == "SoftBreak" then

              table.insert(title_parts, " ")

            elseif inline.t == "Str" and inline.text then

              table.insert(title_parts, inline.text)

            end

          end

          

          extracted_title = table.concat(title_parts, ""):gsub("^%s+", ""):gsub("%s+$", "")

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

    return pandoc.RawBlock("html", '<div style="' .. style .. '">' .. all_text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;") .. '</div>')

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

        if text:match("^%[%[") then

          -- Look ahead for closing ]] in subsequent elements (cross-node wiki link detection)

          local found_close = false

          local full_text = ""

          local j = i

          while j <= #para.content do

            local next_elem = para.content[j]

            if next_elem.t == "Str" and next_elem.text then

              full_text = full_text .. (next_elem.text)

              if full_text:match("%]%]$") then

                found_close = true

                break

              end

            elseif next_elem.t ~= "Space" then

              break

            end

            j = j + 1

          end

          if found_close then

            -- Extract inner text between [[ and ]]

            local match = full_text:match("^%[%[(.+)%]%]$")

            if match then

              new_content:insert(pandoc.Str(" " .. match:gsub("^%s+",""):gsub("%s+$","") .. " "))

            end

            i = j + 1

            goto continue

          end

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

    

    para.content = new_content

    local wrapped = pandoc.List:new()

    wrapped:insert(para)

    return pandoc.Div(wrapped, {style = "margin-bottom:1em;"})

  end,



  Plain = function(plain)

    if not plain then return end

    local str_parts = {}

    for _, child in ipairs(plain.content or {}) do

      if child.t == "Str" and child.text then table.insert(str_parts, child.text) end

    end

    local txt = table.concat(str_parts, "")

    txt = txt:gsub("\\(%[%])", "%1")

    txt = txt:gsub("%[%[(.+)%]%]", function(match) return " "..match:gsub("^%s+",""):gsub("%s+$","").." " end)

    if type(txt) ~= "string" then txt = "" end

    return pandoc.Plain({pandoc.Str(txt)})

  end,



  -- Unescape brackets and delete wiki links in inline text nodes

  Str = function(str)

    if not str or not str.text then return str end

    local s = str.text:gsub("\\(%[%])", "%1")

    if s ~= str.text then return pandoc.Str(s) end

    

    -- Delete wiki link patterns [[Text]] in Str nodes (when wikilinks extension is NOT used)

    if s:match("^%[%[.-%]%]$") then return {} end

    

    return str

  end,



  -- Pass through links: Royal Road supports <a href=""> tags natively

}

