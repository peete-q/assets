local MOAIApp = {}
MOAIApp.DID_REGISTER = 1
MOAIApp.REMOTE_NOTIFICATION = 2
MOAIApp.PAYMENT_QUEUE_TRANSACTION = 3
MOAIApp.PAYMENT_QUEUE_ERROR = 4
MOAIApp.PAYMENT_QUEUE_NOTIFICATION = 5
MOAIApp.PRODUCT_REQUEST_RESPONSE = 6
MOAIApp.RESTORE_TRANSACTION_COMPLETE = 7
MOAIApp.TRANSACTION_STATE_PURCHASING = 0
MOAIApp.TRANSACTION_STATE_PURCHASED = 1
MOAIApp.TRANSACTION_STATE_FAILED = 2
MOAIApp.TRANSACTION_STATE_RESTORED = 3
MOAIApp.TRANSACTION_STATE_CANCELLED = 4
MOAIApp.DOMAIN_APP_SUPPORT = 1
MOAIApp.DOMAIN_CACHES = 2
MOAIApp.DOMAIN_DOCUMENTS = 3
MOAIApp.DIALOG_RESULT_POSITIVE = 0
MOAIApp.DIALOG_RESULT_NEUTRAL = 1
MOAIApp.DIALOG_RESULT_NEGATIVE = 2
MOAIApp.DIALOG_RESULT_CANCEL = 3
local _execWithDelay = function(delay, fn)
  require("timerutil").delaycall(delay, fn)
end
local listeners = {}
function MOAIApp.setListener(evt, listener)
  listeners[evt] = listener
end
function MOAIApp.openURL(url)
end
local _domainPaths = {}
_domainPaths[MOAIApp.DOMAIN_APP_SUPPORT] = "data/support"
_domainPaths[MOAIApp.DOMAIN_CACHES] = "data/cache"
_domainPaths[MOAIApp.DOMAIN_DOCUMENTS] = "data/docs"
function MOAIApp.getDirectoryInDomain(domain)
  local path = _domainPaths[domain]
  if path == nil then
    error("Invalid App Directory Domain: " .. tostring(domain))
  end
  return path
end
function MOAIApp.showDialog(title, message, positive, neutral, negative, cancelable, callback)
  print()
  print(string.rep("-", 70))
  print("App DIALOG: ", title, message, positive, neutral, negative, cancelable)
  print(string.rep("-", 70))
  print()
  if cancelable then
    if callback then
      callback(MOAIApp.DIALOG_RESULT_CANCEL)
    end
  elseif callback then
    callback(MOAIApp.DIALOG_RESULT_POSITIVE)
  end
end
function MOAIApp.canMakePayments()
  return true
end
function MOAIApp.restoreCompletedTransactions()
end
function MOAIApp.requestPaymentForProduct(productId)
  assert(productId ~= nil, "Product ID must not be nil")
  local listener = listeners[MOAIApp.PAYMENT_QUEUE_TRANSACTION]
  if listener == nil then
    return
  end
  local txn = {
    transactionState = MOAIApp.PURCHASING,
    payment = {productIdentifier = productId, quantity = 1}
  }
  _execWithDelay(0.25, function()
    txn.transactionState = MOAIApp.TRANSACTION_STATE_PURCHASING
    listener(txn)
  end)
  _execWithDelay(0.5, function()
    if math.random(10) < 5 then
      txn.transactionState = MOAIApp.TRANSACTION_STATE_FAILED
      txn.error = "Simulated Transaction Error"
    else
      txn.transactionState = MOAIApp.TRANSACTION_STATE_PURCHASED
      txn.transactionReceipt = "Mocked Transaction Receipt: Blah blah blah"
      txn.transactionDate = os.date("!%Y-%m-%d %H:%M:%S")
      txn.transactionIdentifier = math.random(10000000)
    end
    listener(txn)
  end)
end
function MOAIApp.requestProductIdentifiers(productIdOrIds)
  if type(productIdOrIds) ~= "table" then
    productIdOrIds = {productIdOrIds}
  end
  local listener = listeners[MOAIApp.PRODUCT_REQUEST_RESPONSE]
  if listener == nil then
    return
  end
  local response = {}
  local fmt = string.format
  for k, v in ipairs(productIdOrIds) do
    table.insert(response, {
      localizedTitle = fmt("Title of \"%s\"", v),
      localizedDescription = fmt("Desc of \"%s\"", v),
      price = 0.99,
      priceLocale = "en_US@currency=USD",
      priceString = "0.99 USD",
      productIdentifier = v
    })
  end
  _execWithDelay(0.5, function()
    listener(response)
  end)
end
function MOAIApp.registerForRemoteNotifications(kinds)
  local listener = listeners[MOAIApp.DID_REGISTER]
  if listener == nil then
    return
  end
  _execWithDelay(0.5, function()
    listener("1234567890abcdef0987654321")
  end)
end
return MOAIApp
