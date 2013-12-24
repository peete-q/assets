local luaunit = require("luaunit")
local UnitResult = {
  failureCount = 0,
  testCount = 0,
  errorList = {},
  currentClassName = "",
  currentTestName = "",
  testHasFailure = false,
  verbosity = 1
}
local escapeXML = function(str)
  return str:gsub("&", "&amp;"):gsub("\"", "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end
local function formatAttr(name, value)
  return name .. "=\"" .. escapeXML(value) .. "\""
end
local displayHeader = function(self)
  if self._printedHeader == nil then
    print("<testsuite>")
    self._printedHeader = true
  end
end
function UnitResult:displayClassName()
  displayHeader(self)
end
function UnitResult:displayTestName()
  displayHeader(self)
end
function UnitResult:displayFailure(errorMsg)
  print("\t<testcase " .. formatAttr("classname", self.currentClassName) .. " " .. formatAttr("name", self.currentTestName) .. ">")
  print("\t\t<failure>" .. escapeXML(errorMsg) .. "</failure>")
  print("\t</testcase>")
  self.currentTestName = ""
end
function UnitResult:displaySuccess()
end
function UnitResult:finalizeLastResult()
  if self.currentTestName ~= "" then
    displayHeader(self)
    print("\t<testcase " .. formatAttr("classname", self.currentClassName) .. " " .. formatAttr("name", self.currentTestName) .. "/>")
    self.currentTestName = ""
  end
end
function UnitResult:displayOneFailedTest(failure)
  testName, errorMsg = unpack(failure)
end
function UnitResult:displayFailedTests()
end
function UnitResult:displayFinalResult()
  if self._printedHeader == nil then
    print("<testsuite>")
  end
  print("</testsuite>")
  self._printedHeader = nil
  return self.failureCount
end
function UnitResult:startClass(className)
  self.currentClassName = className
end
function UnitResult:startTest(testName)
  self.currentTestName = testName:gsub(self.currentClassName .. ":", "")
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
  self.currentTestName = ""
end
function UnitResult:endTest()
end
if luaunit.result.currentTestName == "" then
  luaunit.result = UnitResult
end
return luaunit
