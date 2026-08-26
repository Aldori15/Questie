---@class ThreadLib
local ThreadLib = QuestieLoader:CreateModule("ThreadLib")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer

--Coroutine functions
local coStatus, coResume, coCreate = coroutine.status, coroutine.resume, coroutine.create
local lType = type
-- local cTimer = C_Timer
local newTicker = C_Timer.NewTicker

---@alias ThreadLibProfilingCallbackName "OnThreadCreated"|"BeforeResume"|"AfterResume"

---@class ThreadLibProfilingCallbacks
---@field OnThreadCreated? fun(thread: thread, submittedFunction: function, callSiteStack: string?, threadName: string?)
---@field BeforeResume? fun(thread: thread)
---@field AfterResume? fun(thread: thread, success: boolean, status: string, resumeValue: any)

local profilingOwner
---@type ThreadLibProfilingCallbacks?
local profilingCallbacks

---@param callbacks ThreadLibProfilingCallbacks?
---@param callbackName ThreadLibProfilingCallbackName
---@param ... any
local function CallProfilingCallback(callbacks, callbackName, ...)
  local callback = callbacks and callbacks[callbackName]
  if not callback then
    return
  end

  -- Lua 5.1 cannot yield across pcall's C boundary. Profiling observers must never yield.
  local success, callbackError = pcall(callback, ...)
  if not success then
    Questie.Error("ThreadLib profiling callback failed", callbackName, callbackError)
  end
end

---@param owner table @Only this owner can clear the callback registration
---@param callbacks ThreadLibProfilingCallbacks?
---@return boolean accepted
function ThreadLib.SetProfilingCallbacks(owner, callbacks)
  if profilingOwner and profilingOwner ~= owner then
    return false
  end

  profilingOwner = owner
  profilingCallbacks = callbacks
  return true
end

---@param owner table
function ThreadLib.ClearProfilingCallbacks(owner)
  if profilingOwner == owner then
    profilingOwner = nil
    profilingCallbacks = nil
  end
end


---Thread a function, callback function is called when the thread is done.
---@param threadFunction function @The function to thread
---@param delay integer @Anything below 0.05 is each frame
---@param errorMessage string? @What is the "Prepend" of the error message
---@param callbackFunction function? @Function to call when the thread is done; receives success and error message
---@param threadName string? @Stable operation name for profiling this job
---@return Ticker Timer @The WoW timer, run Timer:Cancel() and let the handle of the thread become orphaned to cancel
---@return thread Thread @The coroutine thread
function ThreadLib.Thread(threadFunction, delay, errorMessage, callbackFunction, threadName)
  if lType(threadFunction) ~= "function" then
    error("ThreadLib:Thread: threadFunction is not a function")
  end
  if lType(delay) ~= "number" then
    error("ThreadLib:Thread: delay is not a number")
  end
  if errorMessage and lType(errorMessage) ~= "string" then
    error("ThreadLib:Thread: errorMessage is not a string")
  end
  if callbackFunction and lType(callbackFunction) ~= "function" then
    error("ThreadLib:Thread: callbackFunction is not a function")
  end
  if threadName ~= nil and lType(threadName) ~= "string" then
    error("ThreadLib:Thread: threadName is not a string")
  end

  local thread = coCreate(threadFunction)
  if profilingCallbacks and profilingCallbacks.OnThreadCreated then
    local callSiteStack
    if (threadName == nil or threadName == "") and lType(debugstack) == "function" then
      local stackCollected, boundedStack = pcall(debugstack, 2, 12, 0)
      if stackCollected then
        callSiteStack = boundedStack
      end
    end
    CallProfilingCallback(profilingCallbacks, "OnThreadCreated", thread, threadFunction, callSiteStack, threadName)
  end

  local timer
  timer = newTicker(delay or 0, function()
      if(coStatus(thread) == "suspended") then --It's faster not to lookup the value but instead have it here
        local resumeCallbacks = profilingCallbacks
        if resumeCallbacks then
          CallProfilingCallback(resumeCallbacks, "BeforeResume", thread)
        end
        local success, ret = coResume(thread)
        if resumeCallbacks then
          CallProfilingCallback(resumeCallbacks, "AfterResume", thread, success, coStatus(thread), ret)
        end
        -- Something in the coroutine went wrong, print the error and stop the timer
        if not success then
            local stack = debugstack(thread)
            Questie.Error(errorMessage or "Error in thread", ret, "\n", stack)
            timer:Cancel();
            if(callbackFunction) then
              callbackFunction(false, ret)
            end

            timer = nil
            ---@diagnostic disable-next-line: cast-local-type
            thread = nil
        end
      elseif (coStatus(thread) == "dead") then --It's faster not to lookup the value but instead have it here
        timer:Cancel();
        if(callbackFunction) then
          callbackFunction(true)
        end

        --? Is this needed?
        timer = nil
        ---@diagnostic disable-next-line: cast-local-type
        thread = nil
      end
  end)
  return timer, thread
end

---Thread a function, callback function is called when the thread is done.
---@param threadFunction function @The function to thread
---@param delay integer @Anything below 0.05 is each frame
---@param callbackFunction function @Function to call when the thread is done; receives success and error message
---@param threadName string?
---@return Ticker Timer @The WoW timer, run Timer:Cancel() and let the handle of the thread become orphaned to cancel
---@return thread Thread @The coroutine thread
function ThreadLib.ThreadCallback(threadFunction, delay, callbackFunction, threadName)
  return ThreadLib.Thread(threadFunction, delay, nil, callbackFunction, threadName)
end

---Thread a function, using a specific error message.
---@param threadFunction function @The function to thread
---@param delay integer @Anything below 0.05 is each frame
---@param errorMessage string @What is the "Prepend" of the error message
---@param threadName string?
---@return Ticker Timer @The WoW timer, run Timer:Cancel() and let the handle of the thread become orphaned to cancel
---@return thread Thread @The coroutine thread
function ThreadLib.ThreadError(threadFunction, delay, errorMessage, threadName)
  return ThreadLib.Thread(threadFunction, delay, errorMessage, nil, threadName)
end

---Thread a function
---@param threadFunction function @The function to thread
---@param delay integer @Anything below 0.05 is each frame
---@param threadName string?
---@return Ticker Timer @The WoW timer, run Timer:Cancel() and let the handle of the thread become orphaned to cancel
---@return thread Thread @The coroutine thread
function ThreadLib.ThreadSimple(threadFunction, delay, threadName)
  return ThreadLib.Thread(threadFunction, delay, nil, nil, threadName)
end

---Thread a function and start it on the next timer tick.
---@param threadFunction function @The function to thread
---@param threadName string?
---@return Ticker Timer @The WoW timer
---@return thread Thread @The coroutine thread
function ThreadLib.ThreadInstant(threadFunction, threadName)
  return ThreadLib.Thread(threadFunction, 0, nil, nil, threadName)
end

---Thread a function and invoke a callback when it completes.
---@param threadFunction function @The function to thread
---@param callbackFunction function @Function to call when the thread is done; receives success and error message
---@param threadName string?
---@return Ticker Timer @The WoW timer
---@return thread Thread @The coroutine thread
function ThreadLib.ThreadCallbackInstant(threadFunction, callbackFunction, threadName)
  return ThreadLib.Thread(threadFunction, 0, nil, callbackFunction, threadName)
end


--? This was kind of a halv baked idea, that i questioned was even good, but i don't really want to delete it yet.
--[[

  ---@class Thread
  ---@field private _thread thread
  ---@field private _timer Ticker
  ---@field private _callback function?
  ---@field Kill fun()
  local newThread = {
    _thread = coCreate(threadFunction),
    _callback = callbackFunction,

    Continue = ThreadContinue,

    ---@param self Thread
    Kill = function(self)
      print(Questie.DEBUG_CRITICAL, "[ThreadLib] Thread cancelled")
      self._timer:Cancel()
      self._thread = nil
      self._timer = nil
      self.Kill = nil
      self.Continue = nil
    end
  }

  newThread._timer = newTicker(delay or 0, function()
      if(coStatus(newThread._thread) == "suspended") then --It's faster not to lookup the value but instead have it here
        local success, ret = coResume(newThread._thread)
        -- Something in the coroutine went wrong, print the error and stop the timer
        if not success then
            Questie.Error(errorMessage or "Error in thread", ret)
            newThread._timer:Cancel();
        end
      elseif (coStatus(newThread._thread) == "dead") then --It's faster not to lookup the value but instead have it here
        newThread._timer:Cancel();
        if(newThread._callback) then
          callbackFunction()
        end
        newThread._thread = nil
        newThread._timer = nil
        wipe(newThread)
      end
  end)

  return newThread

]]--
