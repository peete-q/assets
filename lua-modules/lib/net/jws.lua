local b64url = require("net.base64url")
local json = require("json")
local _M = {}
local breakstr = function(str, splitter)
  local idx = str:find(splitter)
  if idx == nil then
    return str, nil
  end
  return str:sub(1, idx - 1), str:sub(idx + 1, str:len())
end
function _M._selectKey(keyStore, kid)
  local key
  if kid == nil then
    if type(keyStore) ~= "string" then
      return nil, "key selection is ambiguous or invalid"
    end
    key = keyStore
  else
    if type(keyStore) == "table" then
      key = keyStore[kid]
    else
      return nil, "invalid keystore: " .. tostring(keyStore)
    end
    if key == nil then
      return nil, "key not found: " .. kid
    end
  end
  return key
end
_M.ALG_TO_CRYPTO_ALG = {HS1 = "sha1", none = "none"}
function _M.decode(text, keyStore)
  local headerPart, bodyPart, sigPart = text:match("([^.]+)[.]([^.]+)[.]([^.]*)")
  if headerPart == nil then
    return nil, "malformed JWS (no header part)"
  end
  if sigPart == nil then
    return nil, "malformed JWS (no signature part)"
  end
  local header = json.decode(b64url.decode(headerPart))
  if header == nil or header.alg == nil then
    return nil, "invalid JWS header"
  end
  local calg = _M.ALG_TO_CRYPTO_ALG[header.alg]
  if calg == nil then
    return nil, "invalid alg: " .. tostring(header.alg)
  elseif calg == "none" then
    return b64url.decode(bodyPart), header
  end
  local key, err = _M._selectKey(keyStore, header.kid)
  if key == nil then
    return nil, tostring(err)
  end
  local hmac = crypto.hmac.new(calg, key)
  hmac:update(headerPart)
  hmac:update(".")
  hmac:update(bodyPart)
  local mysig = hmac:digest()
  local jsig = b64url.decode(sigPart)
  if mysig ~= jsig then
    return nil, "signature is invalid"
  end
  return b64url.decode(bodyPart), header
end
function _M.encode(header, body, keyStore)
  local str = b64url.encode(json.encode(header)) .. "." .. b64url.encode(body)
  if header.alg == "none" then
    return str .. "."
  end
  local key, err = _M._selectKey(keyStore, header.kid)
  if key == nil then
    return nil, err
  end
  local hmac = crypto.hmac.new(_M.ALG_TO_CRYPTO_ALG[header.alg], key)
  hmac:update(str)
  return str .. "." .. b64url.encode(hmac:digest())
end
return _M
