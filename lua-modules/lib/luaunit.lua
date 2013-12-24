argv = arg
USE_EXPECTED_ACTUAL_IN_ASSERT_EQUALS = true
function assertError(f, ...)
  local has_error, error_msg = not pcall(f, ...), nil
  if has_error then
    return
  end
  error("No error generated", 2)
end
function assertEquals(actual, expected)
  if actual ~= expected then
    local wrapValue = function(v)
      if type(v) == "string" then
        return "'" .. v .. "'"
      end
      return tostring(v)
    end
    if not USE_EXPECTED_ACTUAL_IN_ASSERT_EQUALS then
      expected, actual = actual, expected
    end
    local errorMsg
    if type(expected) == "string" then
      errorMsg = [[

expected: ]] .. wrapValue(expected) .. "\n" .. "actual  : " .. wrapValue(actual) .. "\n"
    else
      errorMsg = "expected: " .. wrapValue(expected) .. ", actual: " .. wrapValue(actual)
    end
    print(errorMsg)
    error(errorMsg, 2)
  end
end
assert_equals = assertEquals
assert_error = assertError
function wrapFunctions(...)
  local testClass, testFunction
  testClass = {}
  local function storeAsMethod(idx, testName)
    testFunction = _G[testName]
    testClass[testName] = testFunction
  end
  table.foreachi({
    ...
  }, storeAsMethod)
  return testClass
end
function __genOrderedIndex(t)
  local orderedIndex = {}
  for key, _ in pairs(t) do
    table.insert(orderedIndex, key)
  end
  table.sort(orderedIndex)
  return orderedIndex
end
function orderedNext(t, state)
  if state == nil then
    t.__orderedIndex = __genOrderedIndex(t)
    key = t.__orderedIndex[1]
    return key, t[key]
  end
  key = nil
  for i = 1, table.getn(t.__orderedIndex) do
    if t.__orderedIndex[i] == state then
      key = t.__orderedIndex[i + 1]
    end
  end
  if key then
    return key, t[key]
  end
  t.__orderedIndex = nil
  return
end
function orderedPairs(t)
  return orderedNext, t, nil
end
UnitResult = {
  failureCount = 0,
  testCount = 0,
  errorList = {},
  currentClassName = "",
  currentTestName = "",
  testHasFailure = false,
  verbosity = 1
}
function UnitResult:displayClassName()
  print(">>>>>>>>> " .. self.currentClassName)
end
function UnitResult:displayTestName()
  if self.verbosity > 0 then
    print(">>> " .. self.currentTestName)
  end
end
function UnitResult:displayFailure(errorMsg)
  if self.verbosity == 0 then
    io.stdout:write("F")
  else
    print(errorMsg)
    print("Failed")
  end
end
function UnitResult:displaySuccess()
  if self.verbosity > 0 then
  else
    io.stdout:write(".")
  end
end
function UnitResult:displayOneFailedTest(failure)
  testName, errorMsg = unpack(failure)
  print(">>> " .. testName .. " failed")
  print(errorMsg)
end
function UnitResult:displayFailedTests()
  if table.getn(self.errorList) == 0 then
    return
  end
  print("Failed tests:")
  print("-------------")
  table.foreachi(self.errorList, self.displayOneFailedTest)
  print()
end
function UnitResult:displayFinalResult()
  print("=========================================================")
  self:displayFailedTests()
  local failurePercent, successCount
  if self.testCount == 0 then
    failurePercent = 0
  else
    failurePercent = 100 * self.failureCount / self.testCount
  end
  successCount = self.testCount - self.failureCount
  print(string.format("Success : %d%% - %d / %d", 100 - math.ceil(failurePercent), successCount, self.testCount))
  return self.failureCount
end
function UnitResult:startClass(className)
  self.currentClassName = className
  self:displayClassName()
end
function UnitResult:startTest(testName)
  self.currentTestName = testName
  self:displayTestName()
  self.testCount = self.testCount + 1
  self.testHasFailure = false
end
function UnitResult:addFailure(errorMsg)
  self.failureCount = self.failureCount + 1
  self.testHasFailure = true
  table.insert(self.errorList, {
    self.currentTestName,
    errorMsg
  })
  self:displayFailure(errorMsg)
end
function UnitResult:endTest()
  if not self.testHasFailure then
    self:displaySuccess()
  end
end
LuaUnit = {result = UnitResult}
function LuaUnit.strsplit(delimiter, text)
  local list = {}
  local pos = 1
  if string.find("", delimiter, 1) then
    error("delimiter matches empty string!")
  end
  while true do
    do
      local first, last = string.find(text, delimiter, pos)
      if first then
        table.insert(list, string.sub(text, pos, first - 1))
        pos = last + 1
      else
        table.insert(list, string.sub(text, pos))
        break
      end
    end
  end
  return list
end
function LuaUnit.isFunction(aObject)
  return "function" == type(aObject)
end
function LuaUnit.strip_luaunit_stack(stack_trace)
  stack_list = LuaUnit.strsplit("\n", stack_trace)
  strip_end = nil
  for i = table.getn(stack_list), 1, -1 do
    if string.find(stack_list[i], "[C]: in function `xpcall'", 0, true) then
      strip_end = i - 2
    end
  end
  if strip_end then
    table.setn(stack_list, strip_end)
  end
  stack_trace = table.concat(stack_list, "\n")
  return stack_trace
end
function LuaUnit:runTestMethod(aName, aClassInstance, aMethod)
  local ok, errorMsg
  LuaUnit.result:startTest(aName)
  if self.isFunction(aClassInstance.setUp) then
    aClassInstance:setUp()
  end
  local err_handler = function(e)
    return e .. "\n" .. debug.traceback()
  end
  ok, errorMsg = xpcall(aMethod, err_handler)
  if not ok then
    errorMsg = self.strip_luaunit_stack(errorMsg)
    LuaUnit.result:addFailure(errorMsg)
  end
  if self.isFunction(aClassInstance.tearDown) then
    aClassInstance:tearDown()
  end
  self.result:endTest()
end
function LuaUnit:runTestMethodName(methodName, classInstance)
  local methodInstance = loadstring(methodName .. "()")
  LuaUnit:runTestMethod(methodName, classInstance, methodInstance)
end
function LuaUnit:runTestClassByName(aClassName)
  local hasMethod, methodName, classInstance
  hasMethod = string.find(aClassName, ":")
  if hasMethod then
    methodName = string.sub(aClassName, hasMethod + 1)
    aClassName = string.sub(aClassName, 1, hasMethod - 1)
  end
  classInstance = _G[aClassName]
  if not classInstance then
    error("No such class: " .. aClassName)
  end
  LuaUnit.result:startClass(aClassName)
  if hasMethod then
    if not classInstance[methodName] then
      error("No such method: " .. methodName)
    end
    LuaUnit:runTestMethodName(aClassName .. ":" .. methodName, classInstance)
  else
    for methodName, method in orderedPairs(classInstance) do
      if LuaUnit.isFunction(method) and string.sub(methodName, 1, 4) == "test" then
        LuaUnit:runTestMethodName(aClassName .. ":" .. methodName, classInstance)
      end
    end
  end
end
function LuaUnit:run(...)
  args = {
    ...
  }
  if #args > 0 then
    table.foreachi(args, LuaUnit.runTestClassByName)
  elseif argv and 0 < #argv then
    table.foreachi(argv, LuaUnit.runTestClassByName)
  else
    testClassList = {}
    for key, val in pairs(_G) do
      if string.sub(key, 1, 4) == "Test" then
        table.insert(testClassList, key)
      end
    end
    for i, val in orderedPairs(testClassList) do
      LuaUnit:runTestClassByName(val)
    end
  end
  return LuaUnit.result:displayFinalResult()
end
return LuaUnit
