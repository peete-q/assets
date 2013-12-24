local PersistentTable = require("PersistentTable")
local util = require("util")
local timerutil = require("timerutil")
local tostr = util.tostr
local _debug, _warn, _error = require("qlog").loggers("storeiap")
local _M = {}
local purchase_billing_supported
_M.TXN_PURCHASING = "PURCHASING"
_M.TXN_PURCHASED = "PURCHASED"
_M.TXN_RESTORED = "RESTORED"
_M.TXN_FAILED = "FAILED"
_M.TXN_CANCELLED = "CANCELLED"
_M.TXN_REFUNDED = "REFUNDED"
local _TXN_STATE_MAP = {}
local purchase_callback, restore_callback, purchases, product_info_cache_key
local prodcut_info_cache_time = 0
local product_info_cache, product_info_callback
local function _handlePaymentTransactionUpdate(txn)
  _debug("Payment Transaction Update: " .. tostr(txn))
  local callback = purchase_callback
  if txn.transactionState ~= _M.TXN_PURCHASING and txn.transactionState ~= _M.TXN_RESTORED then
    purchase_callback = nil
  end
  local productId = ""
  if txn.payment ~= nil then
    productId = txn.payment.productIdentifier
  end
  if txn.transactionState == _M.TXN_PURCHASED then
    _debug("Product " .. productId .. ": Purchased")
    purchases[productId] = txn
    purchases:save()
    callback(true, productId, txn)
  elseif txn.transactionState == _M.TXN_RESTORED then
    _debug("Product " .. productId .. ": Restored")
    purchases[productId] = txn
    purchases:save()
    callback(true, productId, txn)
  elseif txn.transactionState == _M.TXN_FAILED then
    _error("Product " .. productId .. ": Failed: " .. tostring(txn.error))
    MOAIApp.showDialog(_("Store Error"), txn.error, nil, _("Dismiss"))
    callback(false, productId, txn)
  elseif txn.transactionState == _M.TXN_CANCELLED then
    _debug("Product " .. productId .. ": Cancelled: " .. tostring(txn.error))
    callback(false, productId, txn)
  elseif txn.transactionState == _M.TXN_REFUNDED then
    _error("Product " .. productId .. ": Refunded")
    callback(false, productId, txn)
  elseif txn.transactionState == _M.TXN_PURCHASING then
  else
    assert(false, "invalid transaction state: " .. tostring(txn.transactionState))
  end
end
local function _onIOSPaymentQueueTransaction(txn)
  _debug("Payment Queue Update: " .. tostr(txn))
  local state = _TXN_STATE_MAP[txn.transactionState]
  if state == nil then
    _error("Invalid transaction state (no mapping): " .. tostring(txn.transactionState))
    return
  end
  txn.transactionState = state
  _handlePaymentTransactionUpdate(txn)
end
local function _onIOSRestoreComplete()
  local callback = restore_callback
  purchase_callback = nil
  restore_callback = nil
  if callback then
    callback()
  end
end
local function _onIOSPaymentQueueError(errorString, extraInfo)
  local callback = purchase_callback
  purchase_callback = nil
  restore_callback = nil
  _error("Payment Queue Error: ", errorString, tostr(extraInfo))
end
local function _onIOSProductRequestResponse(products)
  for k, v in ipairs(products) do
    _debug("Product Info Response: " .. tostr(v))
  end
  product_info_cache = products
  product_info_cache_time = os.time()
  local callback = product_info_callback
  product_info_callback = nil
  callback(products)
end
local active_purchase_txns = {}
local complete_purchase_txns = {}
local android_purchaseLoop = {}
local _androidBillingResponseStr = function(code)
  if code == MOAIApp.BILLING_RESULT_OK then
    return "OK"
  elseif code == MOAIApp.BILLING_RESULT_USER_CANCELED then
    return "User Cancelled operation"
  elseif code == MOAIApp.BILLING_RESULT_SERVICE_UNAVAILABLE then
    return "Service Unavailable"
  elseif code == MOAIApp.BILLING_RESULT_BILLING_UNAVAILABLE then
    return "Billing Unavailable"
  elseif code == MOAIApp.BILLING_RESULT_ITEM_UNAVAILABLE then
    return "Invalid item or item unavailable"
  elseif code == MOAIApp.BILLING_RESULT_DEVELOPER_ERROR then
    return "Internal error"
  elseif code == MOAIApp.BILLING_RESULT_ERROR then
    return "Generic error"
  else
    return "Unknown response [" .. tostring(code) .. "]"
  end
end
local function _androidPurchaseResponseLoop()
  while #complete_purchase_txns > 0 do
    local productId = complete_purchase_txns[#complete_purchase_txns][1]
    local code = complete_purchase_txns[#complete_purchase_txns][2]
    local txn = active_purchase_txns[productId]
    if txn == nil then
      error("no txn found for product: '" .. productId .. "'")
    end
    if code == MOAIApp.BILLING_RESULT_OK then
      _debug("Product " .. productId .. ": Purchased")
      txn.transactionState = _M.TXN_PURCHASED
      _handlePaymentTransactionUpdate(txn)
      active_purchase_txns[productId] = nil
    elseif code == MOAIApp.BILLING_RESULT_USER_CANCELED then
      _debug("Product " .. productId .. ": Cancelled")
      txn.transactionState = _M.TXN_CANCELLED
      _handlePaymentTransactionUpdate(txn)
      active_purchase_txns[productId] = nil
    else
      txn.error = _androidBillingResponseStr(code)
      txn.transactionState = _M.TXN_FAILED
      _debug("Product " .. productId .. ": Failed: " .. txn.error)
      _handlePaymentTransactionUpdate(txn)
      active_purchase_txns[productId] = nil
    end
    table.remove(complete_purchase_txns, #complete_purchase_txns)
  end
end
local function _onAndroidPurchaseResponseReceived(productId, code)
  _debug("Purchase Response: " .. tostring(code) .. ", " .. _androidBillingResponseStr(code) .. ": '" .. productId .. "'")
  local txn = active_purchase_txns[productId]
  if txn == nil then
    error("no txn found for product: '" .. productId .. "'")
  end
  complete_purchase_txns[#complete_purchase_txns + 1] = {productId, code}
end
local _onAndroidPurchaseStateChanged = function(productId, state, orderId, notificationId, payload)
end
local function _onAndroidRestoreResponseReceived(code)
end
function _M.info(productIds, callback, cacheDuration)
  assert(type(callback) == "function", "invalid product info handler")
  assert(type(productIds) == "table", "invalid product ID table")
  if MOAIApp.requestProductIdentifiers == nil then
    error("product info request is not supported")
  end
  if product_info_callback ~= nil then
    error("cannot have multiple product requests at one time")
  end
  local cache_key = table.concat(productIds, "\t")
  if cacheDuration == nil then
    cacheDuration = 1200
  end
  if cacheDuration > 0 and product_info_cache_key == cache_key and cacheDuration >= os.time() - product_info_cache_time then
    _debug("Using cached product info results")
    callback(product_info_cache)
    return
  end
  product_info_cache_key = cache_key
  product_info_cache = nil
  product_info_cache_time = 0
  product_info_callback = callback
  MOAIApp.requestProductIdentifiers(productIds)
end
function _M.infoSupported()
  return MOAIApp.requestProductIdentifiers ~= nil
end
function _M.enabled()
  if MOAIApp.canMakePayments ~= nil then
    return MOAIApp.canMakePayments()
  end
  return purchase_billing_supported
end
function _M.purchased(prodId)
  if prodId == true then
    return next(purchases) ~= nil
  end
  return purchases[prodId]
end
function _M.buy(prodId, callback)
  assert(type(callback) == "function", "must provide a callback")
  if not _M.enabled() then
    MOAIApp.showDialog(_("Store Error"), "Payment processing is unavailable.", nil, _("Dismiss"))
    callback(false, prodId, {
      transactionState = _M.TXN_FAILED,
      payment = {productIdentifier = prodId, quantity = 1},
      transactionDate = os.date("!%Y-%m-%d %H:%M:%S"),
      error = "Payment processing is unavailable."
    })
    return
  end
  if purchase_callback ~= nil then
    error("concurrent purchase requests not allowed")
    return
  end
  purchase_callback = callback
  _debug("Requesting purchase of " .. prodId)
  if MOAIApp.requestPaymentForProduct ~= nil then
    MOAIApp.requestPaymentForProduct(prodId)
  else
    local txn = active_purchase_txns[prodId]
    if txn ~= nil then
      error("incorrect purchase state for " .. prodId .. ": " .. tostr(txn))
    end
    txn = {
      transactionState = _M.TXN_PURCHASING,
      payment = {productIdentifier = prodId, quantity = 1},
      transactionDate = os.date("!%Y-%m-%d %H:%M:%S")
    }
    active_purchase_txns[prodId] = txn
    _handlePaymentTransactionUpdate(txn)
    MOAIApp.requestPurchase(prodId)
  end
end
function _M.purchasing()
  return purchase_callback ~= nil
end
function _M.restore(item_callback, complete_callback)
  if purchase_callback ~= nil or restore_callback ~= nil then
    error("concurrent purchase requests not allowed")
    return
  end
  purchase_callback = item_callback
  restore_callback = complete_callback
  MOAIApp.restoreCompletedTransactions()
end
function _M.init()
  purchases = PersistentTable.new("store_purchase_cache", true)
  if MOAIApp.requestProductIdentifiers ~= nil then
    _TXN_STATE_MAP[MOAIApp.TRANSACTION_STATE_CANCELLED] = _M.TXN_CANCELLED
    _TXN_STATE_MAP[MOAIApp.TRANSACTION_STATE_FAILED] = _M.TXN_FAILED
    _TXN_STATE_MAP[MOAIApp.TRANSACTION_STATE_PURCHASED] = _M.TXN_PURCHASED
    _TXN_STATE_MAP[MOAIApp.TRANSACTION_STATE_PURCHASING] = _M.TXN_PURCHASING
    _TXN_STATE_MAP[MOAIApp.TRANSACTION_STATE_RESTORED] = _M.TXN_RESTORED
    MOAIApp.setListener(MOAIApp.PAYMENT_QUEUE_TRANSACTION, _onIOSPaymentQueueTransaction)
    MOAIApp.setListener(MOAIApp.PAYMENT_QUEUE_ERROR, _onIOSPaymentQueueError)
    MOAIApp.setListener(MOAIApp.PRODUCT_REQUEST_RESPONSE, _onIOSProductRequestResponse)
    MOAIApp.setListener(MOAIApp.RESTORE_TRANSACTION_COMPLETE, _onIOSRestoreComplete)
  else
    _TXN_STATE_MAP[MOAIApp.BILLING_STATE_PURCHASE_CANCELED] = _M.TXN_CANCELLED
    _TXN_STATE_MAP[MOAIApp.BILLING_STATE_ITEM_PURCHASED] = _M.TXN_PURCHASED
    _TXN_STATE_MAP[MOAIApp.BILLING_STATE_ITEM_REFUNDED] = _M.TXN_REFUNDED
    MOAIApp.setListener(MOAIApp.CHECK_BILLING_SUPPORTED, function(result)
      purchase_billing_supported = result
    end)
    MOAIApp.setListener(MOAIApp.PURCHASE_RESPONSE_RECEIVED, _onAndroidPurchaseResponseReceived)
    MOAIApp.checkBillingSupported()
    timerutil.repeatcall(0.5, function()
      if not purchase_billing_supported then
        MOAIApp.checkBillingSupported()
      end
    end)
    timerutil.repeatcall(0.5, _androidPurchaseResponseLoop)
  end
end
return _M
