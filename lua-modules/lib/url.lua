local util = require("util")
local sub = string.sub
local gsub = string.gsub
local char = string.char
local tonumber = tonumber
local format = string.format
local byte = string.byte
local sortedpairs = util.sortedpairs
local type = type
local table_concat = table.concat
local table_insert = table.insert
local tostring = tostring
local print = print
local strsplit = util.strsplit
local crypto = crypto
local select = select
local util = util
local string = string
local math = math
local url = {}
local function _char_from_hex(h)
  return char(tonumber(h, 16))
end
local function _char_to_hex(c)
  return format("%%%02X", byte(c))
end
function url.decode(str)
  str = gsub(str, "+", " ")
  str = gsub(str, "%%(%x%x)", _char_from_hex)
  str = gsub(str, "\r\n", "\n")
  return str
end
local url_decode = url.decode
function url.encode(str)
  if str then
    str = gsub(str, "\n", "\r\n")
    str = gsub(str, "([^%w %.%-])", _char_to_hex)
    str = gsub(str, " ", "+")
  end
  return str
end
local url_encode = url.encode
function url.parse(urlstr)
  local first, last = urlstr:find(":")
  local scheme, chunk, authority, path, query, fragment
  if not first then
    return nil, "malformed url: " .. urlstr
  end
  scheme = urlstr:sub(1, first - 1)
  chunk = urlstr:sub(last + 1)
  if chunk:sub(1, 2) == "//" then
    local first, last = chunk:find("/", 3)
    if first then
      authority = chunk:sub(3, first - 1)
      chunk = chunk:sub(last)
    else
      authority = chunk
      chunk = ""
    end
  end
  local first, last = chunk:find("#")
  if first then
    fragment = chunk:sub(last + 1)
    chunk = chunk:sub(1, first - 1)
  end
  local first, last = chunk:find("?")
  if first then
    query = chunk:sub(last + 1)
    path = chunk:sub(1, first - 1)
  else
    query = nil
    path = chunk
  end
  return scheme, authority, path, query, fragment
end
function url.format_post_vars(vars)
  if type(vars) == "table" then
    do
      local str = {}
      local tostring = tostring
      local format = string.format
      for k, v in util.sortedpairs(vars) do
        table_insert(str, format("%s=%s", url_encode(tostring(k)), url_encode(tostring(v))))
      end
      return table_concat(str, "&")
    end
  else
    return tostring(vars)
  end
end
function url.encode_multipart_formdata(fields, files)
  local suffix = math.random(100000)
  local BOUNDARY = "----------MULTIPART-FORM-BOUNDARY-OF-DOOOOOM-" .. suffix
  local BOUNDARY2 = "--" .. BOUNDARY .. "\r\n"
  local S = {}
  for i, e in ipairs(fields) do
    table_insert(S, BOUNDARY2)
    table_insert(S, format("Content-Disposition: form-data; name=\"%s\"\r\n", e[1]))
    table_insert(S, "\r\n")
    table_insert(S, e[2])
    table_insert(S, "\r\n")
  end
  for i, e in ipairs(files) do
    table_insert(S, BOUNDARY2)
    table_insert(S, format("Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n", e[1], e[2]))
    local mimetype = e[4] or "application/octet-stream"
    table_insert(S, format("Content-Type: %s\r\n", mimetype))
    table_insert(S, "\r\n")
    table_insert(S, e[3])
    table_insert(S, "\r\n")
  end
  table_insert(S, format([[
--%s--

]], BOUNDARY))
  return "multipart/form-data; boundary=" .. BOUNDARY, table_concat(S, "")
end
function url.hmac(algo, key, ...)
  local hmac = crypto.hmac.new(algo, key)
  local n = select("#", ...)
  for i = 1, n do
    hmac:update(select(i, ...))
  end
  return hmac:digest()
end
local function _parsequerypart(parsed, qstr)
  local first, last = qstr:find("=")
  if first then
    parsed[url_decode(sub(qstr, 0, first - 1))] = url_decode(sub(qstr, first + 1))
  end
end
function url.parse_query(query)
  local parsed = {}
  local pos = 0
  query = gsub(query, "&amp;", "&")
  query = gsub(query, "&lt;", "<")
  query = gsub(query, "&gt;", ">")
  while true do
    do
      local first, last = query:find("&", pos)
      if first then
        _parsequerypart(parsed, sub(query, pos, first - 1))
        pos = last + 1
      else
        _parsequerypart(parsed, sub(query, pos))
        break
      end
    end
  end
  return parsed
end
return url
