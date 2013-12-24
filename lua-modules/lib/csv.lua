local _M = {}
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local tostring = tostring
local function escapeCSV(s)
  s = tostring(s)
  if string_find(s, "[,\"]") then
    return "\"" .. string_gsub(s, "\"", "\"\"") .. "\""
  else
    return s
  end
end
function _M.toCSV(tab)
  if type(tab) ~= "table" then
    return escapeCSV(tab)
  end
  local table_insert = table.insert
  local s = {}
  for _, v in ipairs(tab) do
    table_insert(s, escapeCSV(v))
  end
  return table.concat(s, ",")
end
local function tonumberorstring(s)
  local n = tonumber(s)
  if n ~= nil then
    return n
  end
  return tostring(s)
end
function _M.fromCSV(line, sep, detectnums)
  local sub = string_sub
  local find = string_find
  local table_insert = table.insert
  detectnums = detectnums or false
  local castfn
  if detectnums then
    castfn = tonumberorstring
  else
    castfn = tostring
  end
  local res = {}
  local pos = 1
  sep = sep or ","
  while true do
    do
      local c = sub(line, pos, pos)
      if c == "" then
        break
      end
      if c == "\"" then
        do
          local txt = ""
          repeat
            local startp, endp = find(line, "^%b\"\"", pos)
            txt = txt .. sub(line, startp + 1, endp - 1)
            pos = endp + 1
            c = sub(line, pos, pos)
            if c == "\"" then
              txt = txt .. "\""
            end
          until c ~= "\""
          table_insert(res, castfn(txt))
          pos = pos + 1
        end
      else
        local startp, endp = find(line, sep, pos)
        if startp then
          table_insert(res, castfn(sub(line, pos, startp - 1)))
          pos = endp + 1
        else
          table_insert(res, castfn(sub(line, pos)))
          break
        end
      end
    end
  end
  return res
end
function _M.rowiter(text, sep, detectnums)
  local sub = string_sub
  local find = string_find
  local table_insert = table.insert
  local len = text:len()
  local pos = 1
  detectnums = detectnums or false
  local castfn
  if detectnums then
    castfn = tonumberorstring
  else
    castfn = tostring
  end
  if sep ~= nil then
    sep = "[" .. sep .. "]"
  else
    sep = ","
  end
  local function iter()
    if pos > len then
      return nil
    end
    local res = {}
    while true do
      if pos > len then
        break
      end
      do
        local c = sub(text, pos, pos)
        if c == "\"" then
          do
            local endrow = false
            local txt = ""
            repeat
              local startp, endp = find(text, "^%b\"\"", pos)
              txt = txt .. sub(text, startp + 1, endp - 1)
              pos = endp + 1
              c = sub(text, pos, pos)
              if c == "\"" then
                txt = txt .. "\""
              end
            until c ~= "\""
            table_insert(res, castfn(txt:gsub("\r\n", "\n"):gsub("\r", "\n")))
            pos = pos + 1
            if c == "\n" then
              return res
            elseif c == "\r" then
              if sub(text, pos + 1, pos + 1) == "\n" then
                pos = pos + 1
              end
              return res
            end
          end
        else
          local startp, endp = find(text, sep, pos, true)
          if startp then
            table_insert(res, castfn(sub(text, pos, startp - 1)))
            pos = endp + 1
            do
              local s = sub(text, startp, endp)
              if s == "\n" then
                return res
              elseif s == "\r" then
                if sub(text, startp + 1, endp + 1) == "\n" then
                  pos = endp + 2
                end
                return res
              end
            end
          else
            table_insert(res, castfn(sub(text, pos)))
            pos = len + 1
            break
          end
        end
      end
    end
    return res
  end
  return iter
end
function _M.file_rowiter(filename, sep, detectnums)
  local f, err = io.open(filename, "rb")
  if not f then
    error(err)
  end
  local content = f:read("*all")
  f:close()
  return _M.rowiter(content, sep, detectnums)
end
function _M.file_totable(filenameOrIter, sep, detectnums)
  local rowIter
  if type(filenameOrIter) == "function" then
    rowIter = filenameOrIter
  else
    rowIter = _M.file_rowiter(filenameOrIter, sep, detectnums)
  end
  local rows = {}
  local ncols
  local table_insert = table.insert
  for row in rowIter, nil, nil do
    if ncols == nil then
      ncols = #row
    else
      for i = #row + 1, ncols do
        table_insert(row, "")
      end
    end
    table_insert(rows, row)
  end
  return rows
end
function _M.file_torecordset(filename, sep, detectnums)
  local data = _M.file_totable(filename, sep, detectnums)
  local headers = table.remove(data, 1)
  local setmetatable = setmetatable
  for i, v in ipairs(headers) do
    headers[tostring(v)] = i
  end
  headers.__index = headers
  local accessor = {
    __index = function(t, k)
      local i = rawget(headers, k)
      if i ~= nil then
        return rawget(t, i)
      else
        return nil
      end
    end
  }
  for i, row in pairs(data) do
    setmetatable(row, accessor)
  end
  setmetatable(data, headers)
  return data
end
function _M.file_listrows(filenameOrIter, reqFields, sparseFields, sep, detectnums)
  local rowIter
  if type(filenameOrIter) == "function" then
    rowIter = filenameOrIter
  else
    rowIter = _M.file_rowiter(filenameOrIter, sep, detectnums)
  end
  local row = rowIter()
  if row == nil then
    error("csv file is empty (no header row)")
  end
  local headers = {}
  local headerMap = {}
  for i, f in ipairs(row) do
    if f ~= "" then
      headerMap[f] = i
      table.insert(headers, f)
    end
  end
  if reqFields ~= nil then
    for i = 1, #reqFields do
      local h = reqFields[i]
      if headerMap[h] == nil then
        error("csv file does not appear valid, missing header: " .. h)
      end
    end
  end
  row = {}
  local lastRow
  local rowCount = 0
  local function iter()
    rowCount = rowCount + 1
    lastRow = row
    row = rowIter()
    if row == nil then
      return nil
    end
    local tmp = {}
    for i = 1, #headers do
      tmp[headers[i]] = row[i] or ""
    end
    row = tmp
    if sparseFields ~= nil then
      for i = 1, #sparseFields do
        local f = sparseFields[i]
        if row[f] == "" then
          row[f] = lastRow[f]
        end
      end
    end
    return row, rowCount
  end
  return iter
end
return _M
