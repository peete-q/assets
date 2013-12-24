local MOAIActionMgr = {}
local rootAction
function MOAIActionMgr.getRoot(action)
  if rootAction == nil then
    rootAction = MOAIAction.new()
  end
  return rootAction
end
function MOAIActionMgr.setRoot(action)
  rootAction = action
end
return MOAIActionMgr
