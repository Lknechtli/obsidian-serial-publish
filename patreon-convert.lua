-- patreon-convert.lua
-- Patreon mode: convert Obsidian markdown to plaintext + blockquotes
-- suitable for pasting into Patreon's post editor.
--
-- Output format: plain text with markdown-lite formatting markers.
--   headings  -> # Header text
--   callouts  -> > **Symbol Title**\n> body lines\n>
--   bold      -> **text**
--   italic    -> *text*
--   strike    -> ~~text~~
--   links     -> [text](url)
--   images    -> ![alt](url)
--   code      -> `inline code`, fenced ``` blocks
--   lists     -> - item / 1. item
--   hr        -> ---
--   wiki links -> stripped (keep inner text)
--   \[\[...\]\] -> literal [[...]]
--   raw HTML  -> stripped

local settings_path = os.getenv("RR_CONVERT_SETTINGS")
local settings = {}
if settings_path then
  local ok, mod = pcall(dofile, settings_path)
  if ok and type(mod) == "table" then settings = mod end
end

local callout_defs = settings.callouts or {}
local callout_symbols = {}
local callout_colors = {}
for k, v in pairs(callout_defs) do
  callout_symbols[k] = v.symbol or ""
  callout_colors[k] = v.color
end

local function normalize_callout_type(t)
  if not t then return nil end
  if t == "hidden" then return "info-hidden" end
  if callout_colors[t] then return t end
  local base = t:match("^(.-)%-[%d]+$")
  if base and callout_colors[base] then return base end
  if t:match("-hidden$") then
    local base = t:gsub("-hidden$", "")
    if callout_colors[base] then return t end
  end
  return nil
end

local function get_symbol(t)
  local base = t:gsub("-hidden$", "")
  return callout_symbols[base] or ""
end

local function unwrap_div(elem)
  if elem.t == "Div" and #elem.content > 0 then
    return unwrap_div(elem.content[1])
  end
  return elem
end

local function convert_sentinels(text)
  return text:gsub("\1LB\1LB", "[["):gsub("\1RB\1RB", "]]"):gsub("\1LB", "["):gsub("\1RB", "]")
end

-- Convert inline elements to markdown-formatted plain text string
local function inlines_to_md(inlines)
  local parts = {}
  local n = #inlines
  for idx = 1, n do
    local el = inlines[idx]
    if not el or not el.t then goto continue end
    if el.t == "Str" then
      local txt = el.text or ""
      if type(txt) == "string" then parts[#parts + 1] = convert_sentinels(txt) end
    elseif el.t == "Space" then
      parts[#parts + 1] = " "
    elseif el.t == "SoftBreak" then
      parts[#parts + 1] = " "
    elseif el.t == "LineBreak" then
      parts[#parts + 1] = "\n"
    elseif el.t == "Strong" and el.content then
      parts[#parts + 1] = "**" .. inlines_to_md(el.content) .. "**"
    elseif el.t == "Emph" and el.content then
      parts[#parts + 1] = "*" .. inlines_to_md(el.content) .. "*"
    elseif el.t == "Strikeout" and el.content then
      parts[#parts + 1] = "~~" .. inlines_to_md(el.content) .. "~~"
    elseif el.t == "Code" then
      parts[#parts + 1] = "`" .. (el.text or "") .. "`"
    elseif el.t == "Link" then
      parts[#parts + 1] = "[" .. inlines_to_md(el.content) .. "](" .. (el.target or "") .. ")"
    elseif el.t == "Image" then
      parts[#parts + 1] = "![" .. inlines_to_md(el.content) .. "](" .. (el.source or "") .. ")"
    elseif el.t == "RawInline" then
      local raw_txt = (el.text or ""):gsub("<[^>]+>", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
      if #raw_txt > 0 then parts[#parts + 1] = raw_txt end
    elseif el.t == "Span" and el.content then
      parts[#parts + 1] = inlines_to_md(el.content)
    elseif el.t == "Quoted" and el.content then
      local quote_char = el.quoteType == pandoc.SingleQuote and "'" or '"'
      parts[#parts + 1] = quote_char .. inlines_to_md(el.content) .. quote_char
    end
    ::continue::
  end
  return table.concat(parts)
end

-- Convert inline elements to a table of lines.
-- Unlike inlines_to_md, treats SoftBreak as a line separator (not a space).
-- This preserves the visual line structure of callout body text.
local function inlines_to_lines(inlines)
  local lines = {""}  -- start with first line
  local n = #inlines
  for idx = 1, n do
    local el = inlines[idx]
    if not el or not el.t then goto continue end
    if el.t == "Str" then
      local txt = el.text or ""
      if type(txt) == "string" then lines[#lines] = lines[#lines] .. convert_sentinels(txt) end
    elseif el.t == "Space" then
      lines[#lines] = lines[#lines] .. " "
    elseif el.t == "SoftBreak" then
      lines[#lines + 1] = ""  -- blank line for Patreon paste compatibility
      lines[#lines + 1] = ""  -- start a new line
    elseif el.t == "LineBreak" then
      lines[#lines + 1] = ""  -- blank line for Patreon paste compatibility
      lines[#lines + 1] = ""  -- start a new line (hard break)
    elseif el.t == "Strong" and el.content then
      lines[#lines] = lines[#lines] .. "**" .. inlines_to_md(el.content) .. "**"
    elseif el.t == "Emph" and el.content then
      lines[#lines] = lines[#lines] .. "*" .. inlines_to_md(el.content) .. "*"
    elseif el.t == "Strikeout" and el.content then
      lines[#lines] = lines[#lines] .. "~~" .. inlines_to_md(el.content) .. "~~"
    elseif el.t == "Code" then
      lines[#lines] = lines[#lines] .. "`" .. (el.text or "") .. "`"
    elseif el.t == "Link" then
      lines[#lines] = lines[#lines] .. "[" .. inlines_to_md(el.content) .. "](" .. (el.target or "") .. ")"
    elseif el.t == "Image" then
      lines[#lines] = lines[#lines] .. "![" .. inlines_to_md(el.content) .. "](" .. (el.source or "") .. ")"
    elseif el.t == "RawInline" then
      local raw_txt = (el.text or ""):gsub("<[^>]+>", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
      if #raw_txt > 0 then lines[#lines] = lines[#lines] .. raw_txt end
    elseif el.t == "Span" and el.content then
      lines[#lines] = lines[#lines] .. inlines_to_md(el.content)
    elseif el.t == "Quoted" and el.content then
      local quote_char = el.quoteType == pandoc.SingleQuote and "'" or '"'
      lines[#lines] = lines[#lines] .. quote_char .. inlines_to_md(el.content) .. quote_char
    end
    ::continue::
  end
  -- Trim each line
  for i = 1, #lines do
    lines[i] = lines[i]:gsub("^%s+", ""):gsub("%s+$", "")
  end
  return lines
end

-- Extract callout type and title (title stops at first LineBreak)
local function extract_callout_title(inlines)
  local callout_type = nil
  local title_parts = {}

  for idx = 1, #inlines do
    local inline = inlines[idx]
    if not callout_type then
      if inline.t == "Str" and inline.text and inline.text:match("^%[!(.-)%]") then
        callout_type = inline.text:match("^%[!(.-)%]")
        local after = inline.text:gsub("^%[!.-%]", "")
        if #after > 0 then title_parts[#title_parts + 1] = after end
      end
    else
      if inline.t == "LineBreak" or inline.t == "SoftBreak" then break
      elseif inline.t == "Str" and inline.text then title_parts[#title_parts + 1] = convert_sentinels(inline.text)
      elseif inline.t == "Space" then title_parts[#title_parts + 1] = " "
      elseif inline.t == "Quoted" and inline.content then
        local quote_char = inline.quoteType == pandoc.SingleQuote and "'" or '"'
        title_parts[#title_parts + 1] = quote_char .. inlines_to_md(inline.content) .. quote_char
      end
    end
  end

  if not callout_type then return nil, "" end
  local title = table.concat(title_parts, ""):gsub("^%s+", ""):gsub("%s+$", "")
  return callout_type, convert_sentinels(title)
end

-- Collect body lines from callout content, skipping title block
local function collect_callout_body(bq_content)
  local body_lines = {}
  local found_title = false

  for idx = 1, #(bq_content or {}) do
    local cblk = bq_content[idx]
    local unwrapped = unwrap_div(cblk)

    local is_title_block = false
    if (unwrapped.t == "Para" or unwrapped.t == "Plain") and unwrapped.content then
      local ct, _ = extract_callout_title(unwrapped.content)
      if ct then is_title_block = true end
    end

    if not found_title and is_title_block then
      found_title = true
      -- Extract body text after first LineBreak/SoftBreak in title block
      local past_break = false
      local after_inlines = {}
      for iidx = 1, #unwrapped.content do
        local ie = unwrapped.content[iidx]
        if ie.t == "LineBreak" or ie.t == "SoftBreak" then
          if not past_break then
            past_break = true
          else
            after_inlines[#after_inlines + 1] = ie
          end
        elseif past_break then
          after_inlines[#after_inlines + 1] = ie
        end
      end
      if #after_inlines > 0 then
        local lines = inlines_to_lines(after_inlines)
        for lidx = 1, #lines do
          body_lines[#body_lines + 1] = lines[lidx]
        end
      end

    elseif found_title then
      if unwrapped.t == "HorizontalRule" then
        -- Blank line before divider (unless already blank)
        if body_lines[#body_lines] ~= "" then
          body_lines[#body_lines + 1] = ""
        end
        body_lines[#body_lines + 1] = "---"
        -- Blank line after divider
        body_lines[#body_lines + 1] = ""
      elseif (unwrapped.t == "Para" or unwrapped.t == "Plain") and unwrapped.content then
        -- Add blank line between consecutive Para/Plain blocks
        local last = body_lines[#body_lines]
        if last and last ~= "" then
          body_lines[#body_lines + 1] = ""
        end
        local lines = inlines_to_lines(unwrapped.content)
        for lidx = 1, #lines do
          body_lines[#body_lines + 1] = lines[lidx]
        end
      elseif unwrapped.t == "BulletList" then
        for iidx = 1, #unwrapped.content do
          local items = unwrapped.content[iidx]
          for jidx = 1, #items do
            local item = items[jidx]
            local text = item.t and pandoc.utils.stringify(item) or inlines_to_md(item)
            text = convert_sentinels(text):gsub("^%s+", ""):gsub("%s+$", "")
            if #text > 0 then body_lines[#body_lines + 1] = "- " .. text end
          end
        end
      elseif unwrapped.t == "OrderedList" then
        local idx = 1
        for iidx = 1, #unwrapped.content do
          local items = unwrapped.content[iidx]
          for jidx = 1, #items do
            local item = items[jidx]
            local text = item.t and pandoc.utils.stringify(item) or inlines_to_md(item)
            text = convert_sentinels(text):gsub("^%s+", ""):gsub("%s+$", "")
            if #text > 0 then body_lines[#body_lines + 1] = idx .. ". " .. text end
            idx = idx + 1
          end
        end
      elseif unwrapped.t == "CodeBlock" then
        local code = convert_sentinels(unwrapped.text or "")
        for line in code:gmatch("[^\r\n]+") do
          body_lines[#body_lines + 1] = "    " .. line
        end
      end
    end
  end

  return body_lines
end

local function is_callout(bq)
  for idx = 1, #(bq.content or {}) do
    local child = bq.content[idx]
    local unwrapped = unwrap_div(child)
    if (unwrapped.t == "Para" or unwrapped.t == "Plain") and unwrapped.content then
      local ct, _ = extract_callout_title(unwrapped.content)
      if ct then return true end
    end
  end
  return false
end

-- Strip wiki links and convert to plain text
local function strip_wiki_links_to_text(content)
  local result = {}
  local i = 1

  while i <= #content do
    local elem = content[i]

    if elem.t == "Str" and elem.text then
      local text = elem.text
      if text:match("^%[%[") and #text > 2 then
        local full_text = ""
        local found_close = false
        local found_triple = false
        local j = i

        while j <= #content do
          local next_elem = content[j]
          if next_elem.t == "Str" and next_elem.text then
            full_text = full_text .. next_elem.text
            if not found_close then
              if full_text:match("%]%]%]") then found_triple = true; found_close = true
              elseif full_text:match("%]%]") then found_close = true
              end
            end
          elseif next_elem.t == "Space" then
            full_text = full_text .. " "
          else break end
          if found_close then break end
          j = j + 1
        end

        if found_close then
          if found_triple then
            local triple_match, remainder = full_text:match("^%[%[%[(.-)%]%]%](.*)")
            if triple_match then
              local trimmed = triple_match:gsub("^%s+",""):gsub("%s+$","")
              result[#result + 1] = " [[" .. trimmed .. "]] "
              if remainder and #remainder > 0 then result[#result + 1] = remainder end
              i = j + 1
              goto continue
            end
          end
          local wiki_match, remainder = full_text:match("^%[%[(.-)%]%](.*)")
          if wiki_match then
            local trimmed = wiki_match:gsub("^%s+",""):gsub("%s+$","")
            result[#result + 1] = " " .. trimmed .. " "
          end
          if remainder and #remainder > 0 then result[#result + 1] = remainder end
          i = j + 1
          goto continue
        end
      end
      result[#result + 1] = convert_sentinels(text)
    else
      local md = inlines_to_md({[1] = elem})
      if #md > 0 then result[#result + 1] = md end
    end

    i = i + 1
    ::continue::
  end

  return table.concat(result)
end

-- Output accumulator
local output_lines = {}

local function emit(text)
  if text then output_lines[#output_lines + 1] = text end
end

local function emit_blank()
  if #output_lines > 0 and output_lines[#output_lines] ~= "" then
    output_lines[#output_lines + 1] = ""
  end
end

local function process_block(blk)
  local unwrapped = unwrap_div(blk)

  if unwrapped.t == "Header" then
    local hashes = string.rep("#", unwrapped.level or 1)
    local text = inlines_to_md(unwrapped.inlines or unwrapped.content or {}):gsub("^%s+", ""):gsub("%s+$", "")
    emit(hashes .. " " .. text)

  elseif unwrapped.t == "Para" then
    local text = strip_wiki_links_to_text(unwrapped.content):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > 0 then emit(text) end

  elseif unwrapped.t == "Plain" then
    local text = strip_wiki_links_to_text(unwrapped.content):gsub("^%s+", ""):gsub("%s+$", "")
    if #text > 0 then emit(text) end

  elseif unwrapped.t == "BlockQuote" then
    if is_callout(unwrapped) then
      for idx = 1, #unwrapped.content do
        local child = unwrapped.content[idx]
        local inner = unwrap_div(child)
        if (inner.t == "Para" or inner.t == "Plain") and inner.content then
          local ct, title = extract_callout_title(inner.content)
          if ct then
            local norm = normalize_callout_type(ct)
            if norm then
              local baseType = norm:gsub("-hidden$", "")
              baseType = callout_colors[baseType] and baseType or "info"
              local sym = get_symbol(baseType)
              title = title or (baseType:sub(1,1):upper() .. baseType:sub(2))

              emit("> **" .. title .. "**")

              local body_lines = collect_callout_body(unwrapped.content)
              if #body_lines > 0 then
                emit(">")  -- blank line between title and body
              end
              for bidx = 1, #body_lines do
                local line = body_lines[bidx]
                emit(#line > 0 and "> " .. line or ">")
              end
              emit(">")
              break
            end
          end
        end
      end
    else
      local prev_was_para = false
      for idx = 1, #unwrapped.content do
        local child = unwrapped.content[idx]
        local inner = unwrap_div(child)
        if (inner.t == "Para" or inner.t == "Plain") and inner.content then
          if prev_was_para then emit(">") end
          prev_was_para = true
          local lines = inlines_to_lines(inner.content)
          for lidx = 1, #lines do
            local line = lines[lidx]
            emit(#line > 0 and "> " .. line or ">")
          end
        elseif inner.t == "HorizontalRule" then
          emit("> ---")
          prev_was_para = false
        else
          prev_was_para = false
        end
      end
      emit(">")
    end

  elseif unwrapped.t == "HorizontalRule" then
    emit("---")

  elseif unwrapped.t == "BulletList" then
    for iidx = 1, #unwrapped.content do
      local items = unwrapped.content[iidx]
      for jidx = 1, #items do
        local item = items[jidx]
        local text
        if item.t then
          -- It's a block, stringify it
          text = pandoc.utils.stringify(item)
        else
          -- It's inlines
          text = inlines_to_md(item)
        end
        text = convert_sentinels(text):gsub("^%s+", ""):gsub("%s+$", "")
        if #text > 0 then emit("- " .. text) end
      end
    end

  elseif unwrapped.t == "OrderedList" then
    local idx = 1
    for iidx = 1, #unwrapped.content do
      local items = unwrapped.content[iidx]
      for jidx = 1, #items do
        local item = items[jidx]
        local text
        if item.t then
          text = pandoc.utils.stringify(item)
        else
          text = inlines_to_md(item)
        end
        text = convert_sentinels(text):gsub("^%s+", ""):gsub("%s+$", "")
        if #text > 0 then emit(idx .. ". " .. text) end
        idx = idx + 1
      end
    end

  elseif unwrapped.t == "CodeBlock" then
    local lang = unwrapped.attributes and unwrapped.attributes.language or ""
    local code = convert_sentinels(unwrapped.text or "")
    emit("```" .. (#lang > 0 and lang or ""))
    emit(code)
    emit("```")

  elseif unwrapped.t == "Image" then
    emit("![" .. inlines_to_md(unwrapped.content or {}) .. "](" .. (unwrapped.source or "") .. ")")

  elseif unwrapped.t == "Figure" then
    local img_block = unwrapped.content[1]
    if img_block then
      for iidx = 1, #img_block.content do
        local elem = img_block.content[iidx]
        if elem.t == "Image" then
          emit("![" .. inlines_to_md(elem.content or {}) .. "](" .. (elem.source or "") .. ")")
          return
        end
      end
    end

  elseif unwrapped.t == "RawBlock" then
    if unwrapped.format ~= "html" then
      local text = (unwrapped.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if #text > 0 then emit(text) end
    end

  elseif unwrapped.t == "Div" then
    for iidx = 1, #unwrapped.content do
      process_block(unwrapped.content[iidx])
    end
  end
end

return {
  Pandoc = function(doc)
    output_lines = {}

    -- Strip %% comments
    local filtered = {}
    local in_comment = false
    for idx = 1, #doc.blocks do
      local blk = doc.blocks[idx]
      local txt = pandoc.utils.stringify(blk):gsub("^%s+", ""):gsub("%s+$", "")
      local after_pct = txt:gsub("^%%%s*", "", 1)
      if #after_pct < #txt then
        in_comment = not in_comment
        goto continue
      end
      if not in_comment then
        filtered[#filtered + 1] = blk
      end
      ::continue::
    end

    for idx = 1, #filtered do
      emit_blank()
      process_block(filtered[idx])
    end

    -- Remove leading blank line
    if #output_lines > 0 and output_lines[1] == "" then
      table.remove(output_lines, 1)
    end

    local output = table.concat(output_lines, "\n")
    if #output > 0 and output:sub(-1) ~= "\n" then
      output = output .. "\n"
    end

    return pandoc.Pandoc({pandoc.Plain({pandoc.Str(output)})})
  end,
}
