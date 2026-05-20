-- EPUB Converter — Pandoc Lua Filter
-- Handles Obsidian-specific markdown features for clean EPUB output:
--   - Callouts → styled divs with CSS classes
--   - Wiki links [[text]] → stripped
--   - Escaped brackets \[\[text\]\] → literal [[text]]
--   - HTML comments → stripped

local callout_colors = {
  info = "#1e90ff", warning = "#ff5722", error = "#f44336", tip = "#4caf50",
  note = "#8bc34a", task = "#9c27b0", quote = "#607d8b", example = "#ba68c8"
}

local callout_symbols = {
  info = "\u{2139}", warning = "\u{26A0}", error = "\u{2716}",
  tip = "\u{25B6}", note = "\u{270E}", task = "\u{2611}",
  quote = "\u{201C}", example = "\u{2637}"
}

local function normalize_callout_type(t)
  if callout_colors[t] then return t end
  local base = t:match("^(.-)%-[%d]+$")
  if base and callout_colors[base] then return base end
  return nil
end

-- Extract callout type and title from inline content (single pass, no list mutation)
-- Title is text between marker and first line break
-- Returns: (type, title, body_inlines)
local function extract_callout_info(inlines)
  local callout_type = nil
  local title_parts = {}
  local body_start = 0

  for i, inline in ipairs(inlines) do
    if not callout_type then
      -- State: looking for [!type] marker
      if inline.t == "Str" and inline.text and inline.text:match("^%[!(.-)%]") then
        callout_type = inline.text:match("^%[!(.-)%]")
        local after_marker = inline.text:gsub("^%[!.-%]", "")
        if #after_marker > 0 then table.insert(title_parts, after_marker) end
      end
    elseif body_start == 0 then
      -- State: collecting title until line break; track where body starts
      if inline.t == "LineBreak" or inline.t == "SoftBreak" then
        body_start = i + 1
        break
      elseif inline.t == "Space" or inline.t == "SoftBreak" then
        table.insert(title_parts, " ")
      elseif inline.t == "Str" and inline.text then
        table.insert(title_parts, inline.text)
      end
    end
  end

  if not callout_type then return nil, nil, pandoc.List:new() end

  -- Build body list from index (no mutation of original list)
  local body_inlines = pandoc.List:new()
  for i = body_start, #inlines do
    table.insert(body_inlines, inlines[i])
  end

  return callout_type, table.concat(title_parts, ""):gsub("^%s+", ""):gsub("%s+$", ""), body_inlines
end

-- Build a callout as a styled div with CSS class
local function convert_callout(callout_type, title, bq_content)
  callout_type = callout_colors[callout_type] and callout_type or "info"
  title = title or (callout_type:sub(1, 1):upper() .. callout_type:sub(2))
  local sym = callout_symbols[callout_type] or ""
  if sym then title = sym .. " " .. title end

  local attr = pandoc.Attr("", {"callout", "callout-" .. callout_type}, {})
  local blocks = pandoc.List:new()

  -- Title header
  blocks:insert(pandoc.Header(2, pandoc.Str(title), pandoc.Attr("", {"callout-title"}, {})))

  -- Body content: extract from first para (after marker+title), then remaining blocks
  local found_marker = false
  for _, child in ipairs(bq_content or {}) do
    if not found_marker and (child.t == "Para" or child.t == "Plain") and child.content then
      local ct, _, body_inlines = extract_callout_info(child.content)
      if ct then
        found_marker = true
        if #body_inlines > 0 then
          blocks:insert(pandoc.Para(body_inlines))
        end
        goto continue
      end
    end
    if found_marker then
      blocks:insert(child)
    end
    ::continue::
  end

  return pandoc.Div(blocks, attr)
end

return {
  -- Obsidian callouts → styled divs
  BlockQuote = function(bq)
    local callout_type = nil
    local extracted_title = nil

    for _, child in ipairs(bq.content or {}) do
      if (child.t == "Para" or child.t == "Plain") and child.content then
        callout_type, extracted_title = extract_callout_info(child.content)
      end
      if callout_type then break end
    end

    local norm = normalize_callout_type(callout_type)
    if norm then
      return convert_callout(norm, extracted_title, bq.content)
    end
  end,

  -- Wiki links and escaped brackets in paragraphs
  Para = function(para)
    if not para or not para.content then return end

    local new_content = pandoc.List:new()
    local i = 1

    while i <= #para.content do
      local elem = para.content[i]

      if elem.t == "Str" and elem.text then
        local text = elem.text

        -- Collect wiki link spans across multiple Str/Space elements
        if text:match("^%[%[") and #text > 2 and not text:match("%]%]") then
          local full_text = ""
          local j = i
          while j <= #para.content do
            local next_elem = para.content[j]
            if next_elem.t == "Str" and next_elem.text then
              full_text = full_text .. next_elem.text
            elseif next_elem.t == "Space" then
              full_text = full_text .. " "
            else
              break
            end
            if full_text:match("%]%]") then break end
            j = j + 1
          end

          if full_text:match("%]%]") then
            -- Strip wiki link, keep surrounding text
            local _, remainder = full_text:match("^%[%[(.-)%]%](.*)")
            if remainder and #remainder > 0 then
              new_content:insert(pandoc.Str(remainder))
            end
            i = j + 1
            goto continue
          end
        end

        -- Escaped bracket markers → literal brackets
        local s = text:gsub("\1LB\1LB", "[["):gsub("\1RB\1RB", "]]")
        if s ~= text then
          new_content:insert(pandoc.Str(s))
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
    return para
  end,

  -- Plain text: wiki links and escaped brackets
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
      if child.t == "Str" and child.text then
        table.insert(str_parts, child.text)
      elseif child.t == "Space" then
        table.insert(str_parts, " ")
      end
    end

    local txt = table.concat(str_parts, "")
    txt = txt:gsub("\1LB\1LB", "[["):gsub("\1RB\1RB", "]]")
    -- Strip wiki links
    txt = txt:gsub("%[%[(.+)%]%]", "%1")
    txt = txt:gsub("^%s+", ""):gsub("%s+$", "")

    return pandoc.Plain({pandoc.Str(txt)})
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

  -- Unwrap Figure to just the image in a Para
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

  -- Strip multi-line Obsidian comments (%% markers)
  Pandoc = function(doc)
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
    return doc
  end,
}
