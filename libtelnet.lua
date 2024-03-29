local libtelnet = {}

-----------------------------------------------

local function getEnumKey(enum, value)
    for enumKey, enumValue in pairs(enum) do
        if enumValue == value then
            return enumKey
        end
    end

    return "unknown"
end

----------------------------------------------- Memory buffer

-- Check if some unread data remains in buffer
local function memoryBufferHasData(self)
    return self.offset < #self.data
end

-- Get next byte from buffer and advance the offset
local function memoryBufferReadByte(self)
    self.offset = self.offset + 1
    
    local char = self.data:sub(self.offset, self.offset)
    return char:byte(), char
end

-- Get all remainig unread data from buffer as string
local function memoryBufferGetData(self)
    return self.data:sub(self.offset + 1)
end

-- Append data to the buffer
local function memoryBufferWrite(self, ...)
    local args = {...}
    for i = 1, #args do
        local arg = args[i]
        local argType = type(arg)

        if argType == "string" then
            self.data = self.data .. arg
        elseif argType == "number" then
            self.data = self.data .. string.char(arg)
        else 
            error("Can't append value of type " .. argType)
        end
    end
end

-- Create new memory buffer
local function memoryBufferNew(data)
    local memoryBuffer = {
        data = data or "",
        offset = 0
    }

    memoryBuffer.hasData = memoryBufferHasData
    memoryBuffer.readByte = memoryBufferReadByte
    memoryBuffer.getData = memoryBufferGetData
    memoryBuffer.write = memoryBufferWrite

    return memoryBuffer
end

----------------------------------------------- Constants

-- Telnet commands
libtelnet.COMMANDS = {
    SE                  = 0xF0, -- Subnegotiation end
    NOP                 = 0xF1, -- No operation
    DM                  = 0xF2, -- Data mark
    BREAK               = 0xF3, 
    IP                  = 0xF4, -- Interrupt process 
    AO                  = 0xF5, -- Abort output
    AYT                 = 0xF6, -- Are you there
    EC                  = 0xF7, -- Erase character
    EL                  = 0xF8, -- Erase line
    GA                  = 0xF9, -- Go ahead
    SB                  = 0xFA, -- Subnegotiation begin
    WILL                = 0xFB, -- Will (opcode)
    WONT                = 0xFC, -- Wont (opcode)
    DO                  = 0xFD, -- Do (opcode)
    DONT                = 0xFE, -- Don't (opcode)
    IAC                 = 0xFF  -- Interpret as command
}

-- Telnet opcodes
libtelnet.OPCODES = {
    IS                  = 0x00,
    BT                  = 0x00,   -- Binary transmission
    SEND                = 0x01,
    ECHO                = 0x01,
    SUPPRESS_GO_AHEAD   = 0x03,
    STATUS              = 0x05,
    TTYPE               = 0x18, -- Terminal type
    NAWS                = 0x1F, -- Negotiate about window size
    TSPEED              = 0x20, -- Terminal speed
    REMOTE_FLOW_CONTROL = 0x21,
    XDISPLOC            = 0x23, -- X Display location
    NEW_ENVIRONMENT     = 0x27
}

-- Telnet events passed to user-defined event handler
libtelnet.EVENTS = {
    DATA                = 0x00, -- Raw text data has been received
    SEND                = 0x01, -- Data needs to be sent over the network
    TTYPE               = 0x02, -- TTYPE command has been received
    WILL                = 0x03, -- WILL command has been received
    WONT                = 0x04, -- WONT command has been received
    DO                  = 0x05, -- DO command has been received
    DONT                = 0x06, -- DONT command has been received
    SUBNEGOTIATION      = 0x07, -- Subnegotiation data has been received
    COMMAND             = 0x08  -- Unhandled command
}

-- Internal handler state codes
local STATE = {
    DATA                = 0x00, -- Expecting data
    COMMAND             = 0x01, -- Expecting command
    SB                  = 0x02, -- Expecting subnegotiation opcode
    SB_DATA             = 0x03, -- Expecting subnegotiation data
    SB_COMMAND          = 0x04, -- Expecting subnegotiation command
    WILL                = 0x05, -- Expecting will opcode
    WONT                = 0x06, -- Expecting wont opcode
    DO                  = 0x07, -- Expecting do opcode
    DONT                = 0x08  -- Expecting dont opcode
}

----------------------------------------------- Telnet send methods

local function telnetSendTextData(self, textData)
    if self:getLocalOptionState(libtelnet.OPCODES.ECHO) then
        self:eventHandler(libtelnet.EVENTS.DATA, textData)
    end

    self:eventHandler(libtelnet.EVENTS.SEND, textData)
end

local function telnetSend(self, ...)
    local buffer = memoryBufferNew()
    buffer:write(...)

    self:eventHandler(libtelnet.EVENTS.SEND, buffer:getData())
end

-- Send simple telnet command
local function telnetSendCommand(self, command, ...)
    self:send(libtelnet.COMMANDS.IAC, command, ...)
end

-- Begin subnegotiation process
local function telnetBeginSubnegotiation(self, opcode, ...)
    self:sendCommand(libtelnet.COMMANDS.SB, opcode, ...)
end

-- Complete subnegotiation process
local function telnetEndSubnegotiation(self)
    self:sendCommand(libtelnet.COMMANDS.SE)
end

-- Shortcut for begin/end subnegotiation
local function telnetSendSubnegotiation(self, opcode, ...)
    self:beginSubnegotiation(opcode, ...)
    self:endSubnegotiation()
end

-- Send terminal type information to the remote end
local function telnetSendTerminalType(self, ttype)
    self:sendSubnegotiation(libtelnet.OPCODES.TTYPE, libtelnet.OPCODES.IS, ttype)
end

-- Send window size information to the remote end
local function telnetSendWindowSize(self, width, height)
    self:sendSubnegotiation(libtelnet.OPCODES.NAWS, libtelnet.OPCODES.IS, width, libtelnet.OPCODES.IS, height)
end

-- Request remote end to enable or disable binary transmission mode
local function telnetSetBinaryMode(self, binaryMode)
    self:sendCommand(binaryMode and libtelnet.COMMANDS.DO or libtelnet.COMMANDS.DONT, libtelnet.OPCODES.BT)
end

----------------------------------------------- Telnet options methods

local function telnetGetLocalOptionState(self, opcode)
    return (self.optionsState[opcode] or {})[1] or false
end

local function telnetGetRemoteOptionState(self, opcode)
    return (self.optionsState[opcode] or {})[2] or false
end

local function telnetSetLocalOptionState(self, opcode, state)
    self.optionsState[opcode] = self.optionsState[opcode] or {}
    self.optionsState[opcode][1] = state
end

local function telnetSetRemoteOptionState(self, opcode, state)
    self.optionsState[opcode] = self.optionsState[opcode] or {}
    self.optionsState[opcode][2] = state
end

----------------------------------------------- Incoming data processing

-- Process negotiation
local function telnetProcessNegotiation(self, opcode)
    if self.state == STATE.WILL then
        self:setRemoteOptionState(opcode, true)

        if self.options[opcode] == nil or self.options[opcode][2] == libtelnet.COMMANDS.DONT then
            self:sendCommand(libtelnet.COMMANDS.DONT, opcode)
        end

        self:eventHandler(libtelnet.EVENTS.WILL, opcode)

    elseif self.state == STATE.WONT then
        self:setRemoteOptionState(opcode, false)
        self:eventHandler(libtelnet.EVENTS.WONT, opcode)

    elseif self.state == STATE.DO then
        if self.options[opcode] == nil or self.options[opcode][1] == libtelnet.COMMANDS.WONT then
            self:sendCommand(libtelnet.COMMANDS.WONT, opcode)
            self:setLocalOptionState(opcode, false)
        else
            self:sendCommand(libtelnet.COMMANDS.WILL, opcode)
            self:setLocalOptionState(opcode, true)
        end

        self:eventHandler(libtelnet.EVENTS.DO, opcode)
        
    elseif self.state == STATE.DONT then
        self:setLocalOptionState(opcode, false)

        self:eventHandler(libtelnet.EVENTS.DONT, opcode)

    end
end

-- Process subnegotiation data
local function telnetProcessSubnegotiation(self)
    local opcode = self.subnegotiationBuffer:readByte()

    if self.subnegotiationOpcode == libtelnet.OPCODES.TTYPE then
        -- Opcode can be SEND (peer requests terminal type) or IS (peer sends terminal type)
        self:eventHandler(libtelnet.EVENTS.TTYPE, opcode, self.subnegotiationBuffer:getData())
    end

    self:eventHandler(
        libtelnet.EVENTS.SUBNEGOTIATION,
        self.subnegotiationOpcode,
        opcode,
        self.subnegotiationBuffer:getData()
    )
end

-- Process data received from the socket
local function telnetReceive(self, data)
    local buffer = memoryBufferNew(data)

    local offset = buffer.offset
    local function resetOffset()
        offset = buffer.offset + 1
    end

    -- Perhaps it's called state machine
    while buffer:hasData() do
        local byte, char = buffer:readByte()

        if self.state == STATE.DATA then
            if byte == libtelnet.COMMANDS.IAC then
                self.state = STATE.COMMAND
            end

        -- Processing telnet command followed after IAC
        elseif self.state == STATE.COMMAND then
            -- Escaping IAC
            if byte == libtelnet.COMMANDS.IAC then
                self:eventHandler(libtelnet.EVENTS.DATA, char)

                resetOffset()
                self.state = STATE.DATA

            -- Initiating subnegotiation
            elseif byte == libtelnet.COMMANDS.SB then
                self.state = STATE.SB

            -- Initiating WILL/WONT/DO/DONT negotiation
            elseif byte == libtelnet.COMMANDS.WILL then
                self.state = STATE.WILL
                 
            elseif byte == libtelnet.COMMANDS.WONT then
                self.state = STATE.WONT

            elseif byte == libtelnet.COMMANDS.DO then
                self.state = STATE.DO

            elseif byte == libtelnet.COMMANDS.DONT then
                self.state = STATE.DONT

            -- Unhandled command
            else
                self:eventHandler(libtelnet.COMMANDS.COMMAND, byte)

                resetOffset()
                self.state = STATE.DATA

            end

        -- Expecting subnegotiation opcode
        elseif self.state == STATE.SB then
            self.subnegotiationOpcode = byte
            self.subnegotiationBuffer = memoryBufferNew()
            self.state = STATE.SB_DATA

        elseif self.state == STATE.SB_DATA then
            if byte == libtelnet.COMMANDS.IAC then
                self.state = STATE.SB_COMMAND
            else
                self.subnegotiationBuffer:write(byte)
                resetOffset()
            end

        elseif self.state == STATE.SB_COMMAND then
            -- Subnegotiation done
            if byte == libtelnet.COMMANDS.SE then
                self:processSubnegotiation()
                
                resetOffset()
                self.state = STATE.DATA

            -- Escaping IAC
            elseif byte == libtelnet.COMMANDS.IAC then
                self.subnegotiationBuffer:write(char)

                resetOffset()
                self.state = STATE.SB_DATA
            end

        -- Processing negotiation
        elseif self.state == STATE.WILL
            or self.state == STATE.WONT
            or self.state == STATE.DO
            or self.state == STATE.DONT 
        then
            self:processNegotiation(byte)

            resetOffset()
            self.state = STATE.DATA
        end
    end

    -- Process any remaining bytes as text
    if self.state == STATE.DATA and offset ~= buffer.offset then
        buffer.offset = offset
        self:eventHandler(libtelnet.EVENTS.DATA, buffer:getData())
    end
end

----------------------------------------------- Instance

-- Create new instance
function libtelnet.new()
    local telnet = {
        state = STATE.DATA,
        optionsState = {}
    }

    telnet.sendTextData          = telnetSendTextData
    telnet.send                  = telnetSend
    telnet.sendCommand           = telnetSendCommand
    telnet.beginSubnegotiation   = telnetBeginSubnegotiation
    telnet.endSubnegotiation     = telnetEndSubnegotiation
    telnet.sendSubnegotiation    = telnetSendSubnegotiation
    telnet.sendTerminalType      = telnetSendTerminalType
    telnet.sendWindowSize        = telnetSendWindowSize
    telnet.setBinaryMode         = telnetSetBinaryMode

    telnet.getLocalOptionState   = telnetGetLocalOptionState
    telnet.getRemoteOptionState  = telnetGetRemoteOptionState
    telnet.setLocalOptionState   = telnetSetLocalOptionState
    telnet.setRemoteOptionState  = telnetSetRemoteOptionState

    telnet.processNegotiation    = telnetProcessNegotiation
    telnet.processSubnegotiation = telnetProcessSubnegotiation
    telnet.receive               = telnetReceive

    return telnet
end

-----------------------------------------------

return libtelnet