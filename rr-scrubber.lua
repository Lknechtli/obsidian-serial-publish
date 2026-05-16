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
  , note = "#8bc34a", task = "#9c27b0", quote = "#607d8b", example = "#ba68c8"
}

local callout_symbols = {
  info = "\u{2139} ", warning = "\u{26A0} ", error = "\u{2716} "
  , tip = "\u{25B6} ", note = "\u{270E} ", task = "\u{2611} ", quote = "\u{201C} "
  , example = "\u{2637}"
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

local function unwrap_div(elem)
  if elem.t == "Div" and #elem.content > 0 then
    return unwrap_div(elem.content[1])
  end
  return elem
end

local function extract_callout_title(inlines)
  local marker_idx = 0
  local callout_type = nil
  for i, inline in ipairs(inlines) do
    if inline.t == "Str" and inline.text and inline.text:match("^%[!(.-)%]") then
      callout_type = inline.text:match("^%[!(.-)%]")
      marker_idx = i
      break
    end
  end
  if marker_idx == 0 then return nil, nil, 0 end

  local break_idx = 0
  for i = marker_idx + 1, #inlines do
    if inlines[i].t == "LineBreak" or inlines[i].t == "SoftBreak" then
      break_idx = i
      break
    end
  end

  local title_parts = {}
  local limit = break_idx > 0 and (break_idx - 1) or #inlines
  for i = marker_idx + 1, limit do
    local inline = inlines[i]
    if inline.t == "LineBreak" or inline.t == "SoftBreak" then break end
    if inline.t == "Space" or inline.t == "SoftBreak" then
      table.insert(title_parts, " ")
    elseif inline.t == "Str" and inline.text then
      table.insert(title_parts, inline.text)
    end
  end

  return callout_type, table.concat(title_parts, ""):gsub("^%s+", ""):gsub("%s+$", ""), break_idx
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
  if el.t == "Span" and el.content then
    local inner = ""
    for _, child in ipairs(el.content) do
      inner = inner .. inline_to_html(child)
    end
    local attrs = el.attributes or el.attr or {}
    local data_attrs = ""
    for k, v in pairs(attrs) do
      if k:match("^data-") then
        data_attrs = data_attrs .. ' ' .. k .. '="' .. v .. '"'
      end
    end
    if #data_attrs > 0 then
      return '<span' .. data_attrs .. '>' .. inner .. '</span>'
    end
    return inner
  end
  local txt = pandoc.utils.stringify(el):gsub("^%s+", ""):gsub("%s+$", "")
  return #txt > 0 and txt or ""
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

  -- Build body content from blockquote children, splitting on HorizontalRule (---) into sections
  local body_sections = {}   -- array of raw HTML strings per section
  local current_section = ""

  for _, cblk in ipairs(bq_content or {}) do
    local unwrapped = unwrap_div(cblk)
    -- Detect --- separator: either HorizontalRule or RawBlock(html) containing <hr>
    local is_separator = (unwrapped.t == "HorizontalRule")
      or (cblk.t == "RawBlock" and cblk.format == "html" and cblk.text:match("^%s*<hr"))
    if is_separator then
      --- separator: flush current section and start a new one
      table.insert(body_sections, current_section)
      current_section = ""
    elseif #current_section == 0 and (#body_sections == 0) then
      -- First content child (before any ---): find [!type] marker and extract body after title
      local unwrapped = unwrap_div(cblk)

      if (unwrapped.t == "Para" or unwrapped.t == "Plain") and unwrapped.content then
        _, _, break_idx = extract_callout_title(unwrapped.content)

        -- Collect body from first break onward, LineBreaks become \n
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
      -- Subsequent Para/Div children: prepend newline separator, then extract content
      local unwrapped = unwrap_div(cblk)
      current_section = current_section .. "\n\n"  -- double newline for paragraph break spacing
      for _, inline in ipairs(unwrapped.content or {}) do
        local html = inline_to_html(inline)
        if #html > 0 then current_section = current_section .. html end
      end
    end
  end

  -- Flush the last section
  table.insert(body_sections, current_section)

  -- Process each section: clean, wrap lines in spans, escape ampersands
  local processed_sections = {}
  for _, raw_html in ipairs(body_sections) do
    local clean_body = raw_html:gsub("^%s+", ""):gsub("%s+$", "")
    if is_error then
      clean_body = '<b>' .. clean_body .. '</b>'
    end
    local rendered_body = clean_body:gsub("\n", "<br />")

    -- Convert markdown checkboxes to unicode: - [ ] → ☐, - [x] → ☑
    rendered_body = rendered_body:gsub("[-*+]%s+%[ %]", "☐"):gsub("[-*+]%s+%[%XX%]", "☑")

    -- Convert <span data-glitch="">text</span> to bold + chromatic aberration text-shadow
    rendered_body = rendered_body:gsub("<span%s+([^>]*)data%-glitch=\"\"([^>]*)>(.-)</span>", function(pre, post, inner)
      return '<b style="text-shadow:-1px 0 0 rgba(255,0,0,0.7),1px 0 0 rgba(0,255,255,0.7)!important;">' .. inner .. '</b>'
    end)

    -- Split on <br /> and wrap each line in a block span for consistent text-indent
    local lines = {}
    local parts = {}
    local tmp = rendered_body:gsub("^%s*$", ""):gsub("%s+$", "")
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
      rendered_body = table.concat(lines)
    else
      rendered_body = ""
    end

    -- Only escape bare ampersands, preserve existing HTML tags from inline_to_html()
    local esc_body = rendered_body:gsub("&([^;])", function(c) return "&amp;" .. c end)
    table.insert(processed_sections, esc_body)
  end

  -- Build table HTML (RR-safe, no <pre> tags) — outer padding only, title + body sections as rows
  local border_style = 'border:4px solid ' .. color .. '!important;'

  if is_error then
    border_style = 'box-shadow: -2px -1px 0 #ff0000!important, 2px 1px 0 #00ffff!important, -3px 2px 0 rgba(255,0,0,0.4)!important, 3px -2px 0 rgba(0,255,255,0.4)!important, -4px 4px 0 #f4433666!important;'
    border_style = border_style .. 'border: 4px solid #f44336!important;'
  end

  -- Count non-empty body sections to determine separator logic
  local num_body_sections = 0
  for _, s in ipairs(processed_sections) do
    if #s:gsub("^%s*$", "") > 0 then num_body_sections = num_body_sections + 1 end
  end

  local table_html = '<div style="max-width:60ch!important;margin:auto;"><table style="border-spacing:0!important;background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;' .. (is_error and '' or shadow_style) .. border_style .. '"><tbody>'

  -- Title row (macOS window title bar style)
  if title then
    local esc_title = title:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
    local bottom_border = num_body_sections > 0 and ('border-bottom:2px solid ' .. color .. '!important;') or ''
    local dots = '<span style="color:#ff5f57!important;">&#11044;</span>&#8201;<span style="color:#febc2e!important;">&#11044;</span>&#8201;<span style="color:#28c840!important;">&#11044;</span>&ensp;'
    table_html = table_html .. '<tr><td style="background:' .. color .. '!important;color:#1a1a2e!important;font-weight:bold!important;padding:0.5em 1em 0.5em 0.3em!important;border:none!important;' .. bottom_border .. '">' .. dots .. esc_title .. '</td></tr>'
  end

  -- Body section rows (each --- creates a new row with separator border)
  local rendered_body_count = 0
  for idx, section_html in ipairs(processed_sections) do
    local trimmed = section_html:gsub("^%s*$", "")
    if #trimmed > 0 then
      rendered_body_count = rendered_body_count + 1
      -- Add bottom-border separator between body sections (not after the last one)
      local is_last = (rendered_body_count == num_body_sections)
      local sep_border = not is_last and ('border-bottom:1px solid ' .. color .. '!important;') or ''
      table_html = table_html .. '<tr><td style="padding:0.5em 1em!important;border:none!important;' .. sep_border .. '">' .. section_html .. '</td></tr>'
    end
  end

  return pandoc.RawBlock("html", table_html .. '</tbody></table></div>')
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

        if text:match("^%[%[") and #text > 2 and not text:match("%]%]") then

          -- Look ahead for closing ]] or ]]] in subsequent elements

          local found_close = false

          local found_triple = false

          local full_text = ""

          local j = i

          while j <= #para.content do

            local next_elem = para.content[j]

            if next_elem.t == "Str" and next_elem.text then

              full_text = full_text .. (next_elem.text)

              if full_text:match("%]%]%]") then

                found_triple = true

                found_close = true

                break

              end

              if full_text:match("%]%]") then

                found_close = true

                break

              end

            elseif next_elem.t == "Space" then

              full_text = full_text .. " "

            else

              break

            end

            j = j + 1

          end

          if found_close then

            -- Triple brackets [[[Text]]] → literal [[Text]]

            if found_triple then

              local triple_match, remainder = full_text:match("^%[%[%[(.-)%]%]%](.*)")

              if triple_match then

                local trimmed = triple_match:gsub("^%s+",""):gsub("%s+$","")

                local prefix = " "

                local suffix = " "

                if remainder and #remainder > 0 then

                  suffix = ""

                end

                new_content:insert(pandoc.Str(prefix .. "[[" .. trimmed .. "]]" .. suffix))

                if remainder and #remainder > 0 then

                  new_content:insert(pandoc.Str(remainder))

                end

                i = j + 1

                goto continue

              end

            end

            -- Regular wiki link [[Text]] → stripped

            local wiki_match, remainder = full_text:match("^%[%[(.-)%]%](.*)")

            if wiki_match then

              local trimmed = wiki_match:gsub("^%s+",""):gsub("%s+$","")

              local prefix = " "

              local suffix = " "

              if remainder and #remainder > 0 then

                suffix = ""

              end

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

    local original = str.text

    -- Don't delete if contains escape markers (will be converted in Para/Plain handler)
    if original:find("\1LB") or original:find("\1RB") then return str end

    -- Triple brackets [[[Text]]] → literal [[Text]]
    local triple = original:match("^%[%[%[(.+)%]%]%]$")
    if triple then return pandoc.Str("[[" .. triple .. "]]") end

    -- Delete wiki link patterns [[Text]]

    if original:match("^%[%[.-%]%]$") then return {} end


    -- Unescape brackets

    local s = original:gsub("%\\([%[%]])", "%1")

    if s ~= original then return pandoc.Str(s) end


    return str

  end,



  -- Pass through links: Royal Road supports <a href=""> tags natively

  -- Strip HTML comments (<!-- ... -->) from block-level raw HTML
  RawBlock = function(rb)
    if rb.format == "html" and rb.text:match("^%s*<!%-%-") then
      return pandoc.RawBlock("html", "")
    end
    return rb
  end,

  -- Strip HTML comments (<!-- ... -->) from inline raw HTML
  RawInline = function(ri)
    if ri.format == "html" and ri.text:match("^%s*<!%-%-") then
      return pandoc.Str("")
    end
    return ri
  end,

  -- Inline code: add display:inline to override RR's default block rendering
  Code = function(el)
    local txt = el.text or (el.c and el.c[2]) or ""
    local escaped = txt:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return pandoc.RawInline("html", '<code style="display:inline!important;">' .. escaped .. '</code>')
  end,

  -- Fenced code blocks: strip <pre> (RR strips <pre> tags); output raw <code>
  CodeBlock = function(cb)
    local lang = cb.attributes.language or ""
    local code = cb.text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    local inner = '<code' .. (#lang > 0 and (' class="sourceCode ' .. lang .. '">') or '>') .. code .. '</code>'
    return pandoc.RawBlock("html", '<div class="sourceCode">' .. inner .. '</div>')
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

  -- Style horizontal dividers with margin, max-width, and chromatic aberration
  HorizontalRule = function()
    return pandoc.RawBlock("html", '<hr style="margin:1em auto!important;max-width:80%!important;border:none!important;height:2px!important;background:#ddd!important;box-shadow:-1px 0 0 rgba(255,0,0,0.6),1px 0 0 rgba(0,255,255,0.6)!important;" />')
  end,

  -- Wrap entire document body in a max-width div for readable line length; strip multi-line Obsidian comments
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
    doc.blocks = pandoc.Div(doc.blocks, {style = "max-width:80ch!important;margin-left:auto!important;margin-right:auto!important;"})
    return doc
  end,

}

