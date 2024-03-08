package.loaded.libtelnet = nil

local computer = require("computer")
local component = require("component")
local event = require("event")
local term = require("term")
local shell = require("shell")
local libtelnet = require("libtelnet")

local internet = component.internet

-----------------------------------------------

local CONNECTION_TIMEOUT = 5
local TERMINAL_TYPE = "Linux"

local running = true
local socket

-----------------------------------------------

local function getEnumKey(enum, value)
    for enumKey, enumValue in pairs(enum) do
        if enumValue == value then
            return enumKey
        end
    end

    return "unknown"
end

-----------------------------------------------

local telnet = libtelnet.new()
telnet.options = {
--   Option                                     Local                    Remote
    [libtelnet.OPCODES.TTYPE              ] = { libtelnet.COMMANDS.WILL, libtelnet.COMMANDS.DONT },
    [libtelnet.OPCODES.NAWS               ] = { libtelnet.COMMANDS.WILL, libtelnet.COMMANDS.DONT },
    [libtelnet.OPCODES.SEND               ] = { libtelnet.COMMANDS.WILL, libtelnet.COMMANDS.DO   },
    [libtelnet.OPCODES.TSPEED             ] = { libtelnet.COMMANDS.WONT, libtelnet.COMMANDS.DONT },
    [libtelnet.OPCODES.NEW_ENVIRONMENT    ] = { libtelnet.COMMANDS.WONT, libtelnet.COMMANDS.DONT },
    [libtelnet.OPCODES.REMOTE_FLOW_CONTROL] = { libtelnet.COMMANDS.WONT, libtelnet.COMMANDS.DONT },
    [libtelnet.OPCODES.XDISPLOC           ] = { libtelnet.COMMANDS.WONT, libtelnet.COMMANDS.DONT },
    [libtelnet.OPCODES.STATUS             ] = { libtelnet.COMMANDS.WONT, libtelnet.COMMANDS.DO   }
}

local escapeSequenceStarted, escapeSequence = false
local ignoredEscapeSequences = {
    "[?2004h", 
    "[?2004l", 
    "[?25h", 
    "[?25l"
}

local function processEscapeSequence(sequence)
    for i = 1, #ignoredEscapeSequences do
        if ignoredEscapeSequences[i] == sequence then
            return
        end
    end

    term.write("\x1B" .. sequence)
end

local function processTelnetData(data)
    for i = 1, #data do
        local char = data:sub(i, i)
        if char == "\x1B" then
            escapeSequenceStarted = true
            escapeSequence = ""
        else
            if escapeSequenceStarted then
                escapeSequence = escapeSequence .. char

                if char:match("%a") then
                    escapeSequenceStarted = false
                    processEscapeSequence(escapeSequence)
                end
            else
                if char ~= "\0" then
                    term.write(char)
                end
            end
        end
    end
end

telnet.eventHandler = function(self, code, ...)
    if code == libtelnet.EVENTS.DATA then
        processTelnetData(...)
    elseif code == libtelnet.EVENTS.SEND then
        socket.write(...)
    elseif code == libtelnet.EVENTS.TTYPE then
        if ... == libtelnet.OPCODES.SEND then
            telnet:sendTerminalType(TERMINAL_TYPE)
        end
    elseif code == libtelnet.EVENTS.DO then        
        if ... == libtelnet.OPCODES.NAWS then
            local _, _, width, height = term.getGlobalArea()
            telnet:sendWindowSize(width, height)
        end
    end
end

-----------------------------------------------

local function onKeyDown(eventData)
    local byte, key = eventData[3], eventData[4]

    if byte == 0 then
        if     key == 200 then -- Arrow up
            telnet:send("\x1B[A")
        elseif key == 208 then -- Arrow down
            telnet:send("\x1B[B")
        elseif key == 205 then -- Arrow right
            telnet:send("\x1B[C")
        elseif key == 203 then -- Arrow left
            telnet:send("\x1B[D")
        end
    else
        telnet:send(string.char(byte))
        return true
    end

    return false
end

local function onClipboard(eventData)
    telnet:send(eventData[3])
    return true
end

local function onInternetReady(eventData)
    if eventData[3] ~= socket.id() then
        return false
    end

    local data, reason = socket.read()
    if not data then
        if reason then
            io.stderr:write("Socket error: " .. reason)
        end
        
        running = false
        return true
    end

    telnet:receive(data)
    return true
end

local function onEvent(eventData)
    local eventType = eventData[1]

    if eventType == "key_down" then
        return onKeyDown(eventData)
    elseif eventType == "internet_ready" then
        return onInternetReady(eventData)
    elseif eventType == "clipboard" then
        return onClipboard(eventData)
    end
end

-----------------------------------------------

local args, options = shell.parse(...)
if #args < 1 or options.help or options.h then
    print("Usage: telnet <address> [<port>]")
    return
end

local address = args[1]
local port = tonumber(args[2] or 23)
if not port then
    io.stderr:write("Invalid port number")
    return
end

term.write(string.format("Connecting to %s:%d...\n", address, port))

socket = internet.connect(address, port)
local connectionStartTime = computer.uptime()
while true do
    local success, reason = socket.finishConnect()
    if success then
        term.write("Connection established\n")
        break
    end

    if success == nil then
        io.stderr:write(string.format("Connection failed: %s\n", reason))
        return
    end

    if computer.uptime() - connectionStartTime > CONNECTION_TIMEOUT then
        io.stderr:write("Connection timed out\n")
        return
    end
end

while running do
    onEvent({term.pull()})
end

socket.close()

-----------------------------------------------