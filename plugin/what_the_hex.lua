--
-- Copyright (c) Souto
--
-- This source code is licensed under the MIT license found in the
-- LICENSE file in the root directory of this source tree.
--

if vim.g.what_the_hex_enable == nil then
  vim.g.what_the_hex_enable = true
end

local namespace = vim.api.nvim_create_namespace("WhatTheHex")
local hex_pattern = "0[xX]%x+"

-- Options for nvim_buf_set_extmark
local ext_mark_options = {
  virt_text = { {"_", "Normal"} },
  virt_text_pos = "inline"
}

-- Return a tuple with first/last lines being displayed
local function get_first_and_last_lines_being_displayed(win_id)
  local result = vim.api.nvim_win_call(win_id,
    function() return {vim.fn.line('w0'), vim.fn.line('w$')}
  end)

  return result[1] - 1, result[2] - 1
end

-- Function to search for all hex numbers in the text
local function find_hex_numbers(text)
  local positions = {}

  local start_pos, end_pos = 1, 1
  while true do
    start_pos, end_pos = string.find(text, hex_pattern, end_pos)
    if not start_pos then break end
    table.insert(positions, {first=start_pos, last=end_pos})
    end_pos = end_pos + 1
  end

  return positions
end


local function get_marks(lines)
  local marks = {}
  -- Search for hex numbers in the line range and return the positions where
  -- the marks should be placed
  for i, line in pairs(lines) do
    -- print("Searching for marks in line #" .. i .. ": '" .. line .. "'")
    for _, position in ipairs(find_hex_numbers(line)) do
      -- print("Hex number found at (" .. position.first .. ", " .. position.last .. ")")
      -- Work backwards the position and add a mark every 8 characters
      local column = position.last - 8
      while column > position.first + 1 do
        -- print("Found mark at line", i, "column", column)
        table.insert(marks, {line=i - 1, column=column})
        column = column - 8
      end
    end
  end
  return marks
end

-- TODO: We could only delete marks not being displayed
local function delete_marks(buf_id)

  local marks = vim.api.nvim_buf_get_extmarks(buf_id, namespace, 0, -1, {})

  for _, mark in ipairs(marks) do
    local extmark_ids, row, col = mark
    for _, extmark_id in ipairs(extmark_ids) do
      -- print('deleting mark: extmark_id=', extmark_id, 'row=', row, 'col=', col)
      vim.api.nvim_buf_del_extmark(buf_id, namespace, extmark_id)
    end
  end
end

local function get_lines_being_displayed(win_id, buf_id)
  local first, last = get_first_and_last_lines_being_displayed(win_id)

  -- print("First line", first, "last", last)

  -- Get the lines in the specified range
  local lines = vim.api.nvim_buf_get_lines(buf_id, first, last + 1, true)
  local result = {}
  for i, line in ipairs(lines) do
    -- print('result[' .. i + first - 1 .. '] = ' .. line)
    result[i + first] = line
  end

  return result
end

local function create_marks(win_id, buf_id)
  for i, mark in ipairs(get_marks(get_lines_being_displayed(win_id, buf_id))) do
    -- print(i, "mark found at line=" .. mark.line .. ", column=" .. mark.column)
    -- print(i, "mark found: " .. vim.inspect(mark))
    vim.api.nvim_buf_set_extmark(buf_id , namespace , mark.line, mark.column, ext_mark_options)
  end
end

local function refresh_marks()
  -- Get the current window ID
  local win_id = vim.api.nvim_get_current_win()
  -- -- Get the buffer associated with the current window
  local buf_id = vim.api.nvim_win_get_buf(win_id)

  delete_marks(buf_id)
  create_marks(win_id, buf_id)
end

-- Create plugin commands
local command = vim.api.nvim_create_user_command
--
-- Manually refresh
command("WhatTheHexRefresh", function()
  print("Refreshing marks")
  refresh_marks()
end, { nargs = 0 })

-- -- Toggle plugin enable. This clears or creates marks as needed
-- command("WhatTheHexToggle", function()
--   vim.g.what_the_hex_enable = not vim.g.what_the_hex_enable

--   if vim.g.what_the_hex_enable then
--     create_marks()
--   else
--     delete_marks()
--   end
-- end, { nargs = 0 })

-- Toggle plugin enable for the current buffer only. This clears or creates
-- marks as needed
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
    delete_marks(buf_id)
  end
end, { nargs = 0 })

-- Clear all marks
command("WhatTheHexClear", function()
  print("Deleting marks")
  -- Get the current window ID
  local win_id = vim.api.nvim_get_current_win()
  -- -- Get the buffer associated with the current window
  local buf_id = vim.api.nvim_win_get_buf(win_id)

  delete_marks(buf_id)
end, { nargs = 0 })


-- Create plugin auto commands

-- Refresh marks when window has scrolled or when entering a buffer
local augroup = vim.api.nvim_create_augroup("WhatTheHex", {})

vim.api.nvim_create_autocmd({ "WinScrolled", "BufEnter" },  {
  group = augroup,
  callback = function(opts)
    refresh_marks()
  end,
  desc = "Refresh plugin's separator marks",
})
