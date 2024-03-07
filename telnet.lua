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
local TERMINAL_TYPE = "ANSI"

local running = true
local socket

-----------------------------------------------

local telnet = libtelnet.new()
telnet.options = {
    [libtelnet.OPCODES.TTYPE] = libtelnet.COMMANDS.WILL,
    [libtelnet.OPCODES.NAWS ] = libtelnet.COMMANDS.WILL
}

telnet.onSendData = function(self, data)
    socket.write(data)
end

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

local escapeSequenceStarted, escapeSequence = false
telnet.onTelnetData = function(self, data)
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

telnet.onTerminalType = function(self, opcode)
    if opcode == libtelnet.OPCODES.SEND then
        telnet:sendTerminalType(TERMINAL_TYPE)
    end
end

telnet.onTelnetDo = function(self, opcode)
    if opcode == libtelnet.OPCODES.NAWS then
        local _, _, width, height = term.getGlobalArea()
        telnet:sendWindowSize(width, height)
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