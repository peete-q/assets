require("logging")
local lastFileNameDatePattern, lastFileHandler
local function openFileLogger(filename, datePattern)
  local filename = string.format(filename, os.date(datePattern))
  if lastFileNameDatePattern ~= filename then
    do
      local f = io.open(filename, "a")
      if f then
        f:setvbuf("line")
        lastFileNameDatePattern = filename
        lastFileHandler = f
        return f
      else
        return nil, string.format("file `%s' could not be opened for writing", filename)
      end
    end
  else
    return lastFileHandler
  end
end
function logging.file(filename, datePattern, logPattern)
  if type(filename) ~= "string" then
    filename = "lualogging.log"
  end
  return logging.new(function(self, level, message)
    local f, msg = openFileLogger(filename, datePattern)
    if not f then
      return nil, msg
    end
    local s = logging.prepareLogMsg(logPattern, os.date(), level, message)
    f:write(s)
    return true
  end)
end
return logging.file
