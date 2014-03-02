require("moai.compat")
local util = require("util")
local memory = require("memory")
local device = require("device")
local file = require("file")
local color = require("color")
local MOAITexture = MOAITexture
local MOAIImage = MOAIImage
local MOAIGfxQuad2D = MOAIGfxQuad2D
local MOAIGfxQuadListDeck2D = MOAIGfxQuadListDeck2D
local MOAIGfxQuadDeck2D = MOAIGfxQuadDeck2D
local MOAIAnimCurve = MOAIAnimCurve
local MOAIEaseType = MOAIEaseType
local MOAIFont = MOAIFont
local MOAIProp2D = MOAIProp2D
local MOAITransform = MOAITransform
local MOAIColor = MOAIColor
local MOAISimpleShader = MOAISimpleShader
local MOAIShader = MOAIShader
local MOAIPexPlugin = MOAIPexPlugin
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local os = os
local type = type
local ipairs = ipairs
local pairs = pairs
local assert = assert
local pcall = pcall
local tostring = tostring
local string = string
local printfln = util.printfln
local print = print
local util = util
local tostr = util.tostr
local memory = memory
local hasPVRSupport = device.hasPVR
local file_exists = file.exists
local dofile = dofile
local debug = debug
local tonumber = tonumber
local error = error
local unpack = unpack
module(...)
bucket = {}
local buckets = {}
local bucketStack = {}
local currentBucket, currentBucketName
local _yield = function()
end
local function _get(key)
  local res = currentBucket[key]
  if res == nil then
    for name, bucket in pairs(buckets) do
      res = bucket[key]
      if res ~= nil then
        return res
      end
    end
  end
  return res
end
local function _put(key, obj)
  if obj ~= nil and currentBucket[key] ~= nil then
    printfln("WARNING: clobbering bucket [%s] resource: %s", currentBucketName, key)
  end
  currentBucket[key] = obj
end
function get(key)
  _get(key)
end
function put(key)
  _put(key)
end
local function _setBucket(name)
  local bucket = buckets[name]
  if bucket == nil then
    bucket = {}
    buckets[name] = bucket
  end
  currentBucket = bucket
  currentBucketName = name
  if name ~= bucketStack[#bucketStack] then
    printfln("--- RESOURCE BUCKET (M: %4.2f MB): [%s] -->  %s", memory.usage(), table_concat(bucketStack, " >> "), name)
  else
    printfln("--- RESOURCE BUCKET (M: %4.2f MB): %s", memory.usage(), table_concat(bucketStack, " >> "))
  end
end
function bucket.current()
  return currentBucketName
end
function bucket.push(name)
  assert(name ~= nil, "Resource bucket identifier must not be nil")
  table_insert(bucketStack, name)
  _setBucket(name)
end
function bucket.pop()
  if #bucketStack == 1 then
    return
  end
  local name = bucketStack[#bucketStack]
  table_remove(bucketStack)
  _setBucket(bucketStack[#bucketStack])
  return name
end
function bucket.dump(name)
  if name == nil then
    name = bucketStack[#bucketStack]
  end
  local bucket = buckets[name]
  if bucket == nil then
    return 0
  end
  printfln("--- LISTING RESOURCE BUCKET: %s", name)
  local count = 0
  for k, v in pairs(bucket) do
    printfln("  %s", k)
    count = count + 1
  end
  printfln("---")
  return count
end
function bucket.release(name, releaseBatchCount)
  releaseBatchCount = releaseBatchCount or 25
  local batch = 0
  local bucket = buckets[name]
  if bucket ~= nil then
    printfln("--- RELEASING RESOURCE BUCKET: [%s]", name)
    local count = 0
    for key, obj in pairs(bucket) do
      count = count + 1
      bucket[key] = nil
      do
        local _type = type(obj)
        if _type == "table" and obj.release ~= nil and type(obj.release) == "function" then
          obj.release()
          for k, v in pairs(obj) do
            obj[k] = nil
          end
        elseif _type == "userdata" and key:find("TX-", 1, true) == 1 then
          local success, result = pcall(function()
            return obj:release()
          end)
          if not success then
            printfln("  warning: error calling release() on %s: %s", key, tostr(obj))
          end
        end
        batch = batch + 1
        if releaseBatchCount > 0 and releaseBatchCount <= batch then
          _yield()
        end
      end
    end
    printfln("--- RELEASED %d Objects, New Memory Total = %.1f MB", count, memory.usage())
  end
  buckets[name] = nil
end
local function bucket_softrelease(name, age)
  if age == nil then
    age = 10
  end
  if name == nil then
    local m0 = memory.usage()
    for name, bucket in pairs(buckets) do
      bucket_softrelease(name, age)
    end
    local m1 = memory.usage()
    return
  end
  local bucket = buckets[name]
  if bucket ~= nil then
    for key, obj in pairs(bucket) do
      do
        local _type = type(obj)
        if _type == "userdata" and key:find("TX-", 1, true) == 1 then
          local success, result = pcall(function()
            return obj:softRelease(age)
          end)
          if not success then
            printfln("  warning: error calling softRelease(%d) on %s: %s", age, key, tostr(obj))
          end
        end
      end
    end
  end
end
bucket.softrelease = bucket_softrelease
function printfln()
end
bucket.push("default")
printfln = util.printfln
path = {}
local paths = {}
local pathStack = {}
local currentPath, currentPathName
local function _setPath(dir)
  local path = paths[dir]
  if path == nil then
    path = {}
    paths[dir] = path
  end
  currentPath = path
  currentPathName = dir
end
function path.push(dir)
  assert(dir ~= nil, "Path directory identifier must not be nil")
  table_insert(pathStack, dir)
  _setPath(dir)
end
function path.pop()
  if #pathStack == 2 then
    return
  end
  local dir = pathStack[#pathStack]
  table_remove(pathStack)
  _setPath(pathStack[#pathStack])
  return dir
end
function path.clear()
  for i = #pathStack, 3, -1 do
    local path = pathStack[i]
    table_remove(pathStack, i)
  end
  _setPath(pathStack[#pathStack])
end
local PATH_PNG_EXT_TABLE
if hasPVRSupport then
  PATH_PNG_EXT_TABLE = {".pvr"}
else
  PATH_PNG_EXT_TABLE = {".q.png"}
end
local function _resolve_path(file, file_ext, opt_exts, mustExist)
  for i = #pathStack, 1, -1 do
    local dir = pathStack[i] .. file
    if file_exists(dir) then
      return dir
    end
    if opt_exts ~= nil then
      if file_ext ~= nil then
        for j, ext in ipairs(opt_exts) do
          local fname = dir:gsub(file_ext, ext)
          if file_exists(fname) then
            return fname
          end
        end
      else
        for j, ext in ipairs(opt_exts) do
          local fname = dir .. ext
          if file_exists(fname) then
            return fname
          end
        end
      end
    end
  end
  if file_exists(file) then
    return file
  end
  if opt_exts ~= nil then
    if file_ext ~= nil then
      for j, ext in ipairs(opt_exts) do
        local fname = file:gsub(file_ext, ext)
        if file_exists(fname) then
          return fname
        end
      end
    else
      for j, ext in ipairs(opt_exts) do
        local fname = file .. ext
        if file_exists(fname) then
          return fname
        end
      end
    end
  end
  if mustExist == nil or mustExist then
    if #pathStack > 0 then
      error("unable to resolve file: " .. tostring(file) .. [[

using path:
	]] .. table_concat(pathStack, [[

	]]))
    else
      error("unable to resolve path: " .. tostring(file))
    end
  end
  return nil
end
function path.resolvepath(file)
  return _resolve_path(file)
end
path.push("fonts/")
path.push("img/")
if device.ui_assetrez == device.ASSET_MODE_LO then
  path.push("img/ldpi/")
  path.push("img/ldpi-override/")
elseif device.ui_assetrez == device.ASSET_MODE_HI then
  path.push("img/hdpi/")
elseif device.ui_assetrez == device.ASSET_MODE_X_HI then
  path.push("img/hdpi/")
  path.push("img/xhdpi/")
end
if device.ui_idiom == device.IDIOM_TABLET then
  path.push("img/tablet/")
end
local DEFAULT_FONT_CHARCODES = " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:,;'\"(!?)+-=*/@#$%^&_[]<>`~\\{}|"
local _bakeFont = function(font, base)
  if font.saveToBMFont ~= nil then
    local img = font:getImage()
    img:writePNG(base .. ".png")
    font:saveToBMFont(base .. ".fnt")
  end
end
local function _loadBakedFont(filename)
  local imgfile = filename:gsub("%.fnt$", ".png")
  local font = MOAIFont.new()
  font:loadFromBMFont(filename)
  font:setTexture(texture(imgfile))
  return font
end
function font(face, size, nobake)
  local key = "FONT-" .. face .. "-" .. size
  local font = _get(key)
  if font == nil then
    if face:find(".fnt$") then
      do
        local file = _resolve_path(face)
        if file == nil then
          error("Cannot find font file: " .. face)
        end
        local tex = face:gsub(".fnt$", ".png")
        font = MOAIFont.new()
        font:loadFromBMFont(file)
        font:setTexture(texture(tex))
      end
    else
      local bakeBase = string.format("%s-%d-ttf", face, size)
      local loadBaked = false
      local file
      if not BAKE_TTF then
      end
      if not nobake then
        file = _resolve_path(bakeBase .. ".fnt", nil, nil, false)
        if file then
          loadBaked = true
        end
      end
      if file == nil then
        file = _resolve_path(face .. ".ttf")
        if file == nil then
          error("Cannot find font file: " .. face .. ".ttf")
        end
      end
      if loadBaked then
        font = _loadBakedFont(file)
        if font == nil then
          error("Error loading baked font: " .. file)
        end
      else
        if os.getenv("NO_TTF") then
          error("Forcibly not loading TTF file: " .. file)
        end
        font = MOAIFont.new()
        font:loadFromTTF(file, DEFAULT_FONT_CHARCODES, size, 132)
        if not BAKE_TTF then
        end
        _bakeFont(font, bakeBase)
      end
    end
    _put(key, font)
  end
  return font
end
local function SAFE_MOAITexture_getOriginalSize(tex)
  local succes, w, h = pcall(function()
    return tex:getOriginalSize()
  end)
  if not success then
    return tex:getSize()
  end
  return w, h
end
function texture(file, transform)
  local key = "TX-" .. file
  local tex = _get(key)
  if tex == nil then
    local isQuantized = false
    tex = MOAITexture.new()
    local file_old = file
    file = _resolve_path(file, ".png", PATH_PNG_EXT_TABLE)
    local quantize = false
    if file ~= nil then
      if file:find(".q") ~= nil then
        quantize = true
      end
    else
      printfln("warning: Texture not found: %s", file_old)
    end
    if quantize then
      tex:load(file, MOAIImage.TRUECOLOR + MOAIImage.QUANTIZE + MOAIImage.PREMULTIPLY_ALPHA)
    elseif transform ~= nil then
      tex:load(file, transform)
    else
      tex:load(file)
    end
    tex:setFilter(MOAITexture.GL_LINEAR)
    _put(key, tex)
  end
  return tex
end
local function spritedeck_getSize(self, name, time)
  local curves = self._animCurves
  if curves ~= nil then
    local curve = curves[name]
    if curve ~= nil then
      return unpack(curve._sizes)
    end
    return nil
  end
  return nil
end
local spritedeck_indexOf = function(self, name, time)
  local curves = self._animCurves
  if curves ~= nil then
    local curve = curves[name]
    if curve ~= nil then
      return curve._frames[1]
    end
    return nil
  end
end
local function spritedeck_new(filename, textureFilename, data)
  local fileData = data
  fileData = fileData or dofile(_resolve_path(filename))
  local sd = fileData.spriteDeck
  local deck = MOAIGfxQuadListDeck2D.new()
  deck:reserveUVQuads(#sd.uvRects)
  for i, uvRect in ipairs(sd.uvRects) do
    if uvRect.r then
      deck:setUVQuad(i, uvRect.u1, uvRect.v0, uvRect.u1, uvRect.v1, uvRect.u0, uvRect.v1, uvRect.u0, uvRect.v0)
    else
      deck:setUVRect(i, uvRect.u0, uvRect.v1, uvRect.u1, uvRect.v0)
    end
  end
  local sizes = {}
  deck:reserveQuads(#sd.sizes)
  for i, size in ipairs(sd.sizes) do
    if size.x0 then
      deck:setRect(i, size.x0, size.y0, size.x1, size.y1)
      sizes[i] = {
        size.x1 - size.x0,
        size.y1 - size.y0
      }
    else
      local halfW = size.w / 2
      local halfH = size.h / 2
      deck:setRect(i, -halfW, -halfH, halfW, halfH)
      sizes[i] = {
        size.w,
        size.h
      }
    end
  end
  deck:reservePairs(#sd.prims)
  for i, prim in ipairs(sd.prims) do
    deck:setPair(i, prim.uv, prim.s)
  end
  deck:reserveLists(#sd.sprites)
  for i, sprite in ipairs(sd.sprites) do
    deck:setList(i, sprite.base, sprite.size)
  end
  deck._numSprites = #sd.sprites
  local animCurves = {}
  local step = 1 / fileData.fps
  for i, layers in ipairs(fileData.timeline.layers) do
    animCurves[layers.name] = MOAIAnimCurve.new()
    local curve = animCurves[layers.name]
    curve:reserveKeys(#layers.frames)
    local frames = {}
    local curveSizes = {}
    for j, frame in pairs(layers.frames) do
      local t = frame.start * step
      curve:setKey(j, t, frame.id, MOAIEaseType.FLAT)
      frames[j] = frame.id
      curveSizes[j] = sizes[frame.id]
    end
    curve._frames = frames
    curve._sizes = curveSizes
  end
  deck._animCurves = animCurves
  local textureName = filename:gsub(".fla.lua", ".fla.png")
  local tex = texture(textureName)
  deck:setTexture(tex)
  deck.getSize = spritedeck_getSize
  deck.indexOf = spritedeck_indexOf
  deck.type = "spritedeck"
  return deck
end
local tweendeck_getSize = function(self, name, time)
  return nil
end
local tweendeck_indexOf = function(self, name, time)
  local frames = self._frames
  if frames ~= nil then
    local frame = frames[name]
    if frame ~= nil then
      return frame._frames[1]
    end
    return nil
  end
end
local function tween_createCurve(keyCount)
  local val
  if keyCount and keyCount > 1 then
    val = MOAIAnimCurve.new()
    val:reserveKeys(keyCount)
  end
  return val
end
local tween_setKey = function(transform, curve, count, timeStep, const, mode, weight)
  if transform then
    if curve then
      curve:setKey(count, timeStep, transform, mode, weight)
      count = count + 1
    else
      const = transform
    end
  end
  return count, const
end
local function tweendeck_new(filename, textureFilename, data)
  local fileData = data
  fileData = fileData or dofile(_resolve_path(filename))
  local step = 1 / fileData.fps
  local bd = fileData.brushDeck
  local isAtlas = false
  if not bd then
    bd = fileData.atlasDeck
    isAtlas = true
  end
  local deck = MOAIGfxQuadDeck2D.new()
  deck:reserve(#bd)
  local halfWidth = fileData.width / 2
  local halfHeight = fileData.height / 2
  if isAtlas then
    for i, object in ipairs(bd) do
      local uvRect = object.uvRect
      local bounds = object.spriteRect
      local originalSize = object.sourceSize
      if object.r then
        deck:setUVQuad(i, uvRect.u1, uvRect.v0, uvRect.u1, uvRect.v1, uvRect.u0, uvRect.v1, uvRect.u0, uvRect.v0)
      else
        deck:setUVRect(i, uvRect.u0, uvRect.v1, uvRect.u1, uvRect.v0)
      end
      local halfW = bounds.width / 2
      local halfH = bounds.height / 2
      local offsetX = bounds.x - (originalSize.width / 2 - halfW)
      local offsetY = -bounds.y + (originalSize.height / 2 - halfH)
      deck:setRect(i, -halfW + offsetX, -halfH + offsetY, halfW + offsetX, halfH + offsetY)
    end
  else
    for i, brush in pairs(bd) do
      deck:setUVRect(i, brush.u0, brush.v1, brush.u1, brush.v0)
      local w = brush.w * 0.5
      local h = brush.h * 0.5
      if brush.r then
        deck:setQuad(i, -h, -w, -h, w, h, w, h, -w)
      else
        deck:setRect(i, -w, -h, w, h)
      end
    end
  end
  local timeline = fileData.timeline
  local curves = {}
  local consts = {}
  local _frames = {}
  local _sizes = {}
  local _numCurves = {}
  local xUsed = false
  local YUsed = false
  for i, layer in pairs(timeline.layers) do
    local idCurve, idConst
    idCurve = tween_createCurve(layer.idKeys)
    local xCurve, xConst
    xCurve = tween_createCurve(layer.xKeys)
    local yCurve, yConst
    yCurve = tween_createCurve(layer.yKeys)
    local rCurve, rConst
    rCurve = tween_createCurve(layer.rKeys)
    local sxCurve, sxConst
    sxCurve = tween_createCurve(layer.sxKeys)
    local syCurve, syConst
    syCurve = tween_createCurve(layer.syKeys)
    local aCurve, aConst
    aCurve = tween_createCurve(layer.aKeys)
    local frames = {}
    local sizes = {}
    local idCount = 1
    local xCount = 1
    local yCount = 1
    local rCount = 1
    local sxCount = 1
    local syCount = 1
    local aCount = 1
    for j, frame in ipairs(layer.frames) do
      local t = frame.start * step
      if frame.id then
        if idCurve then
          idCurve:setKey(idCount, t, frame.id, MOAIEaseType.FLAT)
          frames[idCount] = frame.id
          idCount = idCount + 1
        else
          idConst = frame.id
        end
      end
      if not frame.id or frame.id > -1 then
        local transform = frame.transform
        local mode = MOAIEaseType.LINEAR
        local weight = frame.ease / 100
        if not frame.isTween then
          mode = MOAIEaseType.FLAT
        elseif weight > 0 then
          mode = MOAIEaseType.EASE_IN
        elseif weight < 0 then
          mode = MOAIEaseType.EASE_OUT
          weight = -weight
        end
        xCount, xConst = tween_setKey(transform.x, xCurve, xCount, t, xConst, mode, weight)
        yCount, yConst = tween_setKey(transform.y, yCurve, yCount, t, yConst, mode, weight)
        rCount, rConst = tween_setKey(transform.r, rCurve, rCount, t, rConst, mode, weight)
        sxCount, sxConst = tween_setKey(transform.sx, sxCurve, sxCount, t, sxConst, mode, weight)
        syCount, syConst = tween_setKey(transform.sy, syCurve, syCount, t, syConst, mode, weight)
        aCount, aConst = tween_setKey(transform.a, aCurve, aCount, t, aConst, mode, weight)
      end
    end
    local curveSet = {}
    local constSet = {}
    curveSet[MOAIProp2D.ATTR_INDEX] = idCurve
    curveSet[MOAITransform.ATTR_X_LOC] = xCurve
    curveSet[MOAITransform.ATTR_Y_LOC] = yCurve
    curveSet[MOAITransform.ATTR_Z_ROT] = rCurve
    curveSet[MOAITransform.ATTR_X_SCL] = sxCurve
    curveSet[MOAITransform.ATTR_Y_SCL] = syCurve
    curveSet[MOAIColor.ATTR_A_COL] = aCurve
    constSet.id = idConst
    constSet.x = xConst
    constSet.y = yConst
    constSet.r = rConst
    constSet.xs = sxConst
    constSet.ys = syConst
    constSet.a = aConst
    curves[layer.name] = curveSet
    consts[layer.name] = constSet
    _frames[layer.name] = frames
    _sizes[layer.name] = sizes
    _numCurves[layer.name] = layer.numCurves
  end
  local textureName = filename:gsub(".fla.lua", ".fla.png")
  local tex = texture(textureName)
  deck:setTexture(tex)
  deck._animCurves = curves
  deck._animConsts = consts
  deck._numCurves = _numCurves
  deck._frames = _frames
  deck.width = fileData.width
  deck.height = fileData.height
  deck.type = "tweendeck"
  return deck
end
local function atlasdeck_getSize(self, name)
  return unpack(self._sizes[name])
end
local atlasdeck_indexOf = function(self, name)
  return self._map[name]
end
local function atlasdeck_new(filename, textureFilename)
  local fileData = dofile(_resolve_path(filename))
  local deck = MOAIGfxQuadDeck2D.new()
  deck:reserve(#fileData.frames)
  deck._map = {}
  deck._sizes = {}
  local frames
  local animCurves = {}
  local useCurve
  for i, object in ipairs(fileData.frames) do
    local name = object.name
    local start, len = name:find("_%x+[fF][pP][sS]_")
    local animName, fps
    if start then
      fps = tonumber(name:sub(start + 1, len - 4))
      animName = name:sub(1, start - 1)
    end
    if animName and fps then
      local curve = animCurves[animName]
      if curve then
        curve.frames = curve.frames + 1
      else
        animCurves[animName] = MOAIAnimCurve.new()
        curve = animCurves[animName]
        curve.frames = 1
        curve.step = 1 / fps
        useCurve = true
      end
      object.curve = animCurves[animName]
    end
  end
  for k, v in pairs(animCurves) do
    v:reserveKeys(v.frames + 1)
    v._frames = {}
    v.curFrame = 1
  end
  for i, object in ipairs(fileData.frames) do
    local uvRect = object.uvRect
    local bounds = object.spriteColorRect
    local originalSize = object.spriteSourceSize
    if object.textureRotated then
      deck:setUVQuad(i, uvRect.u1, uvRect.v0, uvRect.u1, uvRect.v1, uvRect.u0, uvRect.v1, uvRect.u0, uvRect.v0)
    else
      deck:setUVRect(i, uvRect.u0, uvRect.v1, uvRect.u1, uvRect.v0)
    end
    local halfW = bounds.width / 2
    local halfH = bounds.height / 2
    local offsetX = bounds.x - (originalSize.width / 2 - halfW)
    local offsetY = -bounds.y + (originalSize.height / 2 - halfH)
    deck:setRect(i, -halfW + offsetX, -halfH + offsetY, halfW + offsetX, halfH + offsetY)
    if object.name ~= nil then
      deck._map[object.name] = i
      deck._sizes[object.name] = {
        bounds.width,
        bounds.height
      }
    end
    if object.curve then
      local curve = object.curve
      local curFrame = curve.curFrame
      local t = (curFrame - 1) * curve.step
      curve:setKey(curFrame, t, i, MOAIEaseType.FLAT)
      if curFrame == curve.frames then
        curve:setKey(curFrame + 1, t + curve.step, i, MOAIEaseType.FLAT)
      end
      curve._frames[curFrame] = curFrame
      curve.curFrame = curFrame + 1
      object.curve = nil
    end
  end
  if useCurve then
    deck._animCurves = animCurves
  end
  local tex = texture(textureFilename)
  deck:setTexture(tex)
  deck.getSize = atlasdeck_getSize
  deck.indexOf = atlasdeck_indexOf
  deck.type = "atlasdeck"
  deck.numFrames = #fileData.frames
  return deck
end
local function singledeck_getSize(self, name)
  return unpack(self._size)
end
local singledeck_indexOf = function(self, name)
  return nil
end
local function singledeck_new(filename)
  local deck = MOAIGfxQuad2D.new()
  local tex = texture(filename)
  deck:setTexture(tex)
  local w, h = tex:getSize()
  local oW, oH = SAFE_MOAITexture_getOriginalSize(tex)
  deck:setRect(-oW / 2, -oH / 2, oW / 2, oH / 2)
  if (w ~= oW or h ~= oH) and h ~= 0 and w ~= 0 then
    deck:setUVRect(0, oH / h, oW / w, 0)
  end
  deck._size = {oW, oH}
  deck.getSize = singledeck_getSize
  deck.indexOf = singledeck_indexOf
  deck.type = "singledeck"
  return deck
end
function deck(filename)
  local key = "DK-" .. filename
  local deck = _get(key)
  if deck == nil then
    if string.find(filename, ".fla.png") ~= nil then
      do
        local newFileName = filename:gsub(".fla.png", ".fla.lua")
        local fileData = dofile(_resolve_path(newFileName))
        if fileData.brushDeck or fileData.atlasDeck then
          deck = tweendeck_new(newFileName, filename, fileData)
        else
          deck = spritedeck_new(newFileName, filename, fileData)
        end
      end
    elseif string.find(filename, ".atlas.png") ~= nil then
      deck = atlasdeck_new(filename:gsub(".atlas.png", ".atlas.lua"), filename)
    else
      deck = singledeck_new(filename)
    end
    _put(key, deck)
  end
  return deck
end
function pexparticle(filename)
  local key = "PEX-" .. filename
  local plugin = _get(key)
  if plugin == nil then
    plugin = MOAIPexPlugin.load(_resolve_path(filename))
    _put(key, plugin)
  end
  return plugin
end
local StandardShaders = {
  xyuv = function()
    local s = MOAIShader.new()
    s:reserveUniforms(1)
    s:declareUniform(1, "Transform", MOAIShader.UNIFORM_WORLD_VIEW_PROJ)
    s:setVertexAttribute(1, "position")
    s:setVertexAttribute(2, "uv")
    s:load([[
				uniform mat4 Transform;
				
				attribute vec4 position;
				attribute vec2 uv;
				
				varying MEDP vec2 uvVarying;
				
				void main () {
					gl_Position = position * Transform;
					uvVarying = uv;
				}
			]], [[
				uniform sampler2D sampler;
				
				varying MEDP vec2 uvVarying;
				
				void main () {
					gl_FragColor = texture2D( sampler, uvVarying );
				}
			]])
    return s
  end
}
function shader(shadername)
  local key = "SHADER-" .. shadername
  local s = _get(key)
  if s == nil then
    if MOAISimpleShader == nil and string.find(shadername, ".shader.lua") then
      do
        local shaderData = dofile(_resolve_path(filename .. ".shader.lua"))
        s = MOAIShader.new()
        if shaderData.uniforms ~= nil then
          s:reserveUniforms(#shaderData.uniforms)
          for i, e in ipairs(shaderData.uniforms) do
            s:declareUniform(i, e[1], e[2])
          end
        end
        if shaderData.vertexAttributes ~= nil then
          for i, a in ipairs(shaderData.vertexAttributes) do
            s:setVertexAttribute(i, a)
          end
        end
        s:load(shaderData.vert, shaderData.frag)
      end
    elseif StandardShaders[shadername] ~= nil then
      s = StandardShaders[shadername]()
    else
      local r, g, b, a = color.parse(shadername)
      if r == nil then
        error("invalid shader: " .. tostring(shadername))
      end
      if MOAISimpleShader ~= nil then
        s = MOAISimpleShader.new()
        s:setColor(r, g, b, a)
      else
        s = MOAIShader.new()
        s:reserveUniforms(1)
        s:declareUniform(1, "Transform", MOAIShader.UNIFORM_WORLD_VIEW_PROJ)
        s:setVertexAttribute(1, "position")
        s:load([[
						uniform mat4 Transform;
						attribute vec4 position;
						void main () {
							gl_Position = position * Transform;
						}
					]], string.format([[
						void main () {
							gl_FragColor = vec4(%f,%f,%f,%f);
						}
					]], r, g, b, a))
      end
    end
    _put(key, s)
  end
  return s
end
