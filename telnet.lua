package.loaded.libtelnet = nil

local computer = require("computer")
local component = require("component")
local event = require("event")
local term = require("term")
local shell = require("shell")
local libtelnet = require("libtelnet")
local unicode = require("unicode")

local internet = component.internet

-----------------------------------------------

local XTERM_PALETTE = {0x000000, 0x800000, 0x008000, 0x808000, 0x000080, 0x800080, 0x008080, 0xC0C0C0, 0x808080, 0xFF0000, 0x00FF00, 0xFFFF00, 0x0000FF, 0xFF00FF, 0x00FFFF, 0xFFFFFF, 0x000000, 0x00005F, 0x000087, 0x0000AF, 0x0000D7, 0x0000FF, 0x005F00, 0x005F5F, 0x005F87, 0x005FAF, 0x005FD7, 0x005FFF, 0x008700, 0x00875F, 0x008787, 0x0087AF, 0x0087D7, 0x0087FF, 0x00AF00, 0x00AF5F, 0x00AF87, 0x00AFAF, 0x00AFD7, 0x00AFFF, 0x00D700, 0x00D75F, 0x00D787, 0x00D7AF, 0x00D7D7, 0x00D7FF, 0x00FF00, 0x00FF5F, 0x00FF87, 0x00FFAF, 0x00FFD7, 0x00FFFF, 0x5F0000, 0x5F005F, 0x5F0087, 0x5F00AF, 0x5F00D7, 0x5F00FF, 0x5F5F00, 0x5F5F5F, 0x5F5F87, 0x5F5FAF, 0x5F5FD7, 0x5F5FFF, 0x5F8700, 0x5F875F, 0x5F8787, 0x5F87AF, 0x5F87D7, 0x5F87FF, 0x5FAF00, 0x5FAF5F, 0x5FAF87, 0x5FAFAF, 0x5FAFD7, 0x5FAFFF, 0x5FD700, 0x5FD75F, 0x5FD787, 0x5FD7AF, 0x5FD7D7, 0x5FD7FF, 0x5FFF00, 0x5FFF5F, 0x5FFF87, 0x5FFFAF, 0x5FFFD7, 0x5FFFFF, 0x870000, 0x87005F, 0x870087, 0x8700AF, 0x8700D7, 0x8700FF, 0x875F00, 0x875F5F, 0x875F87, 0x875FAF, 0x875FD7, 0x875FFF, 0x878700, 0x87875F, 0x878787, 0x8787AF, 0x8787D7, 0x8787FF, 0x87AF00, 0x87AF5F, 0x87AF87, 0x87AFAF, 0x87AFD7, 0x87AFFF, 0x87D700, 0x87D75F, 0x87D787, 0x87D7AF, 0x87D7D7, 0x87D7FF, 0x87FF00, 0x87FF5F, 0x87FF87, 0x87FFAF, 0x87FFD7, 0x87FFFF, 0xAF0000, 0xAF005F, 0xAF0087, 0xAF00AF, 0xAF00D7, 0xAF00FF, 0xAF5F00, 0xAF5F5F, 0xAF5F87, 0xAF5FAF, 0xAF5FD7, 0xAF5FFF, 0xAF8700, 0xAF875F, 0xAF8787, 0xAF87AF, 0xAF87D7, 0xAF87FF, 0xAFAF00, 0xAFAF5F, 0xAFAF87, 0xAFAFAF, 0xAFAFD7, 0xAFAFFF, 0xAFD700, 0xAFD75F, 0xAFD787, 0xAFD7AF, 0xAFD7D7, 0xAFD7FF, 0xAFFF00, 0xAFFF5F, 0xAFFF87, 0xAFFFAF, 0xAFFFD7, 0xAFFFFF, 0xD70000, 0xD7005F, 0xD70087, 0xD700AF, 0xD700D7, 0xD700FF, 0xD75F00, 0xD75F5F, 0xD75F87, 0xD75FAF, 0xD75FD7, 0xD75FFF, 0xD78700, 0xD7875F, 0xD78787, 0xD787AF, 0xD787D7, 0xD787FF, 0xD7AF00, 0xD7AF5F, 0xD7AF87, 0xD7AFAF, 0xD7AFD7, 0xD7AFFF, 0xD7D700, 0xD7D75F, 0xD7D787, 0xD7D7AF, 0xD7D7D7, 0xD7D7FF, 0xD7FF00, 0xD7FF5F, 0xD7FF87, 0xD7FFAF, 0xD7FFD7, 0xD7FFFF, 0xFF0000, 0xFF005F, 0xFF0087, 0xFF00AF, 0xFF00D7, 0xFF00FF, 0xFF5F00, 0xFF5F5F, 0xFF5F87, 0xFF5FAF, 0xFF5FD7, 0xFF5FFF, 0xFF8700, 0xFF875F, 0xFF8787, 0xFF87AF, 0xFF87D7, 0xFF87FF, 0xFFAF00, 0xFFAF5F, 0xFFAF87, 0xFFAFAF, 0xFFAFD7, 0xFFAFFF, 0xFFD700, 0xFFD75F, 0xFFD787, 0xFFD7AF, 0xFFD7D7, 0xFFD7FF, 0xFFFF00, 0xFFFF5F, 0xFFFF87, 0xFFFFAF, 0xFFFFD7, 0xFFFFFF, 0x080808, 0x121212, 0x1C1C1C, 0x262626, 0x303030, 0x3A3A3A, 0x444444, 0x4E4E4E, 0x585858, 0x626262, 0x6C6C6C, 0x767676, 0x808080, 0x8A8A8A, 0x949494, 0x9E9E9E, 0xA8A8A8, 0xB2B2B2, 0xBCBCBC, 0xC6C6C6, 0xD0D0D0, 0xDADADA, 0xE4E4E4, 0xEEEEEE}
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
    [libtelnet.OPCODES.ECHO               ] = { libtelnet.COMMANDS.WILL, libtelnet.COMMANDS.DO   },
    [libtelnet.OPCODES.BT                 ] = { libtelnet.COMMANDS.WILL, libtelnet.COMMANDS.DO   },
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
    "[?25l",
    "[3J",
    "[1P", 
    "[2P", 
    "[3P", 
    "[4P", 
    "[5P"
}

local function processEscapeSequence(sequence)
    local gpu = term.gpu()

    -- Color palette
    local govno, colorId = sequence:match("%[(%d+);5;(%d+)m")
    if govno ~= nil then
        colorId = tonumber(colorId)
        if not colorId then
            return
        end

        local color = XTERM_PALETTE[colorId + 1]
        if not color then
            return
        end

        if     govno == "38" then gpu.setForeground(color)
        elseif govno == "48" then gpu.setBackground(color)
        end

        return
    end

    -- Truecolor
    local govno, r, g, b = sequence:match("%[(%d+);2;(%d+);(%d+);(%d+)m")
    if govno ~= nil then
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if not r or not g or not b then
            return
        end

        local color = (r << 16 | g << 8 | b)
        if     govno == "38" then gpu.setForeground(color)
        elseif govno == "48" then gpu.setBackground(color)
        end

        return
    end

    -- Ignored zalupa
    for i = 1, #ignoredEscapeSequences do
        if ignoredEscapeSequences[i] == sequence then
            return
        end
    end

    term.write("\x1B" .. sequence)
end

local function processTelnetData(data)
    for i = 1, unicode.wlen(data) do
        local char = unicode.sub(data, i, i)
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
        telnet:sendTextData(utf8.char(byte))
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

local function info(format, ...)
    if not options.q and not options.quiet then
        term.write(format:format(...))
    end
end

if #args < 1 or options.help or options.h then
    print("Usage: telnet <address> [<port>]")
    print("  -h --help: Print usage and exit")
    print("  -q --quiet: Print only errors")
    print("     --ttype=<ttype>: Set terminal type; Default is " .. TERMINAL_TYPE)
    return
end

if options.ttype then
    TERMINAL_TYPE = options.ttype
    info("Terminal is %s\n", TERMINAL_TYPE)
end

local address = args[1]
local port = tonumber(args[2] or 23)
if not port then
    io.stderr:write("Invalid port number")
    return
end

info("Connecting to %s:%d...\n", address, port)

socket = internet.connect(address, port)
local connectionStartTime = computer.uptime()
while true do
    local success, reason = socket.finishConnect()
    if success then
        info("Connection established\n")
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

telnet:setBinaryMode(true)

while running do
    onEvent({term.pull()})
end

socket.close()

-----------------------------------------------