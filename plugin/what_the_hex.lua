--
-- Copyright (c) Souto
--
-- This source code is licensed under the MIT license found in the
-- LICENSE file in the root directory of this source tree.
--
if vim.g.what_the_hex_enable == nil then vim.g.what_the_hex_enable = true end

-- Options for nvim_buf_set_extmark
vim.g.what_the_hex_separator = vim.g.what_the_hex_separator or "_"
vim.g.what_the_hex_highlight = vim.g.what_the_hex_highlight or "Normal"
-- Other options
vim.g.what_the_hex_group_width = vim.g.what_the_hex_group_width or 8

--

local namespace = vim.api.nvim_create_namespace("WhatTheHex")
local hex_patterns = { "0[xX]%x+", "'h%x+" }

-- Setup logger
local logger_params = { plugin = "what-the-hex", level = "warn" }
if vim.g.what_the_hex_debug == true then
  logger_params.level = "trace"
  logger_params.use_console = false
  logger_params.outfile = "/tmp/what_the_hex.log"
end
local _logger = require("plenary.log").new(logger_params)

-- Return a tuple with first/last lines being displayed
local function get_first_and_last_lines_being_displayed(win_id)
  local result = vim.api.nvim_win_call(win_id, function()
    return { vim.fn.line("w0"), vim.fn.line("w$") }
  end)

  return result[1] - 1, result[2] - 1
end

-- Function to search for all hex numbers in the text
local function find_hex_numbers(text)
  local positions = {}

  for _, hex_pattern in pairs(hex_patterns) do
    local start_pos, end_pos = nil, nil
    while true do
      start_pos, end_pos = string.find(text, hex_pattern, end_pos)
      if not start_pos then break end
      table.insert(positions, { first = start_pos, last = end_pos })
      end_pos = end_pos + 1
    end
  end

  return positions
end

local function find_marks_in_lines(lines)
  local marks = {}
  -- Search for hex numbers in the line range and return the positions where the marks
  -- should be placed
  for i, line in pairs(lines) do
    for _, position in ipairs(find_hex_numbers(line)) do
      -- Work backwards the position and add a mark every N characters
      local column = position.last - vim.g.what_the_hex_group_width
      while column > position.first + 1 do
        _logger.trace("Found mark at line", i, "column", column)
        table.insert(marks, { line = i - 1, column = column })
        column = column - vim.g.what_the_hex_group_width
      end
    end
  end
  return marks
end

-- Delete either the marks no longer being displayed or all marks
local function delete_marks(win_id, buf_id, force)
  local first, last = get_first_and_last_lines_being_displayed(win_id)

  local deleted = 0

  for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(buf_id, namespace, 0, -1, {})) do
    local id = extmark[1]
    local line = extmark[2]
    local column = extmark[3]
    if force or line < first or line > last then
      deleted = deleted + 1
      _logger.trace(string.format("mark(id=%d, line=%d, column=%d)", id, line, column),
        "is outside of lines", string.format("[%d..%d]", first, last),
        "and is no longer visible")
      vim.api.nvim_buf_del_extmark(buf_id, namespace, id)
    else
      _logger.trace(string.format("mark(id=%d, line=%d, column=%d)", id, line, column),
        "is still visible")
    end
  end

  _logger.debug("Deleted", deleted, "marks")
end

local function get_lines_being_displayed(win_id, buf_id)
  local first, last = get_first_and_last_lines_being_displayed(win_id)

  -- Get the lines in the specified range
  local lines = vim.api.nvim_buf_get_lines(buf_id, first, last + 1, true)
  -- Make it so that the result is a dictionary where the key is the actual line number.
  -- By default, vim.api.nvim_buf_get_lines returns a list where the first line is
  -- mapped to the first item (i.e., index=0)
  local result = {}
  for i, line in ipairs(lines) do result[i + first] = line end

  return result
end

local function create_marks(win_id, buf_id)
  -- Create a table where the index represents the line numbers of existing marks to
  -- speed up searching. Keys that are not in the array will return nil, so if we find a
  -- true it means the line was in the original list
  local existing_marks = {}
  for _, extmark in ipairs(vim.api.nvim_buf_get_extmarks(buf_id, namespace, 0, -1, {})) do
    existing_marks[extmark[2]] = true
  end

  local added = 0
  for _, mark in ipairs(find_marks_in_lines(get_lines_being_displayed(win_id, buf_id))) do
    if existing_marks[mark.line] ~= true then
      _logger.trace("mark(line=", mark.line, ", column=", mark.column, "is new")
      vim.api.nvim_buf_set_extmark(buf_id, namespace, mark.line, mark.column, {
        virt_text = { { vim.g.what_the_hex_separator, vim.g.what_the_hex_highlight } },
        virt_text_pos = "inline"
      })
      added = added + 1
    else
      _logger.trace("mark(line=", mark.line, ", column=", mark.column, "is NOT new")
    end
  end

  _logger.debug("Added", added, "marks")
end

local function refresh_marks(win_id, buf_id, force)
  delete_marks(win_id, buf_id, force)
  create_marks(win_id, buf_id)
end

-- Create plugin commands
local command = vim.api.nvim_create_user_command

-- Manually refresh
command("WhatTheHexRefresh", function()
  _logger.info("Refreshing marks")
  -- Get the current window ID
  local win_id = vim.api.nvim_get_current_win()
  -- -- Get the buffer associated with the current window
  local buf_id = vim.api.nvim_win_get_buf(win_id)

  refresh_marks(win_id, buf_id, true)
end, { nargs = 0 })

-- Toggle plugin enable for the current buffer only. This clears or creates marks as
-- needed
command("WhatTheHexToggleBuffer", function()
  if vim.b.what_the_hex_enable == nil then
    vim.b.what_the_hex_enable = vim.g.what_the_hex_enable
  end
  vim.b.what_the_hex_enable = not vim.b.what_the_hex_enable

  local win_id = vim.api.nvim_get_current_win()
  local buf_id = vim.api.nvim_win_get_buf(win_id)

  if vim.b.what_the_hex_enable then
    create_marks(win_id, buf_id)
  else
    delete_marks(win_id, buf_id, true)
  end
end, { nargs = 0 })

-- Clear all marks
command("WhatTheHexClear", function()
  _logger.info("Deleting marks")
  -- Get the current window ID
  local win_id = vim.api.nvim_get_current_win()
  -- -- Get the buffer associated with the current window
  local buf_id = vim.api.nvim_win_get_buf(win_id)

  delete_marks(win_id, buf_id, true)
end, { nargs = 0 })

-- Refresh marks when window has scrolled or when entering a buffer
vim.api.nvim_create_autocmd({ "WinScrolled", "BufEnter", "InsertLeave", "TextChanged" }, {
  group = vim.api.nvim_create_augroup("WhatTheHex", {}),
  callback = function(opts)
    _logger.debug("Handling event", opts.event)
    -- Get the current window ID
    local win_id = vim.api.nvim_get_current_win()
    -- -- Get the buffer associated with the current window
    local buf_id = vim.api.nvim_win_get_buf(win_id)

    -- Only create marks on buf enter once
    if opts.event == "BufEnter" and vim.b[buf_id].what_the_hex_initialized then
      return
    end

    vim.b[buf_id].what_the_hex_initialized = 1
    -- Define which events to force refreshing the marks
    local force_refresh_events = { TextChanged = true, InsertLeave = true }
    refresh_marks(win_id, buf_id, force_refresh_events[opts.event])
  end,
  desc = "Refresh plugin's separator marks"
})
