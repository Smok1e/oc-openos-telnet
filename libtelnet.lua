local libtelnet = {}

----------------------------------------------- Debugging

local function getEnumKey(enum, value)
    for enumKey, enumValue in pairs(enum) do
        if value == enumValue then
            return enumKey
        end
    end
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

libtelnet.OPCODES = {
    IS                  = 0x00,  
    SEND                = 0x01,
    SUPPRESS_GO_AHEAD   = 0x03,
    STATUS              = 0x05,
    TTYPE               = 0x18, -- Terminal type
    NAWS                = 0x1F, -- Negotiate about window size
    TSPEED              = 0x20, -- Terminal speed
    REMOTE_FLOW_CONTROL = 0x21,
    X_DISPLAY_LOCATION  = 0x23,
    NEW_ENVIRONMENT     = 0x27
}

-- Handler state codes
local STATE = {
    DATA       = 0x00, -- Expecting data
    COMMAND    = 0x01, -- Expecting command
    SB         = 0x02, -- Expecting subnegotiation opcode
    SB_DATA    = 0x03, -- Expecting subnegotiation data
    SB_COMMAND = 0x04, -- Expecting subnegotiation command
    WILL       = 0x05, -- Expecting will opcode
    WONT       = 0x06, -- Expecting wont opcode
    DO         = 0x07, -- Expecting do opcode
    DONT       = 0x08  -- Expecting dont opcode
}

----------------------------------------------- Telnet instance

local function telnetSend(self, ...)
    local buffer = memoryBufferNew()
    buffer:write(...)
    self:onSendData(buffer:getData())
end

local function telnetSendCommand(self, command, ...)
    self:send(libtelnet.COMMANDS.IAC, command, ...)
end

local function telnetBeginSubnegotiation(self, opcode, ...)
    self:sendCommand(libtelnet.COMMANDS.SB, opcode, ...)
end

local function telnetEndSubnegotiation(self)
    self:sendCommand(libtelnet.COMMANDS.SE)
end

local function telnetSendSubnegotiation(self, opcode, ...)
    self:beginSubnegotiation(opcode, ...)
    self:endSubnegotiation()
end

local function telnetSendTerminalType(self, ttype)
    self:sendSubnegotiation(libtelnet.OPCODES.TTYPE, libtelnet.OPCODES.IS, ttype)
end

local function telnetSendWindowSize(self, width, height)
    self:sendSubnegotiation(libtelnet.OPCODES.NAWS, libtelnet.OPCODES.IS, width, libtelnet.OPCODES.IS, height)
end

-- Process negotiation
local function telnetProcessNegotiation(self, opcode)
    if self.state == STATE.DO then
        if self.options[opcode] ~= nil then
            self:sendCommand(self.options[opcode], opcode)
        else
            self:sendCommand(libtelnet.COMMANDS.WONT, opcode)
        end

        if self.onTelnetDo then
            self:onTelnetDo(opcode)
        end
    end
end

-- Process subnegotiation data
local function telnetProcessSubnegotiation(self)
    local opcode = self.subnegotiationBuffer:readByte()

    if self.subnegotiationOpcode == libtelnet.OPCODES.TTYPE then
        if self.onTerminalType then
            self:onTerminalType(opcode)
        end
    end
end

-- Process data received from the socket
local function telnetReceive(self, data)
    local buffer = memoryBufferNew(data)

    -- Perhaps it's called state machine
    while buffer:hasData() do
        local byte, char = buffer:readByte()

        if self.state == STATE.DATA then
            -- If first bit is set to 1 then we received a telnet command
            if (byte >> 7) & 1 == 0 then
                if self.onTelnetData then
                   self:onTelnetData(char)
                end
            else
                if byte == libtelnet.COMMANDS.IAC then
                    self.state = STATE.COMMAND
                end
            end

        -- Processing telnet command followed after IAC
        elseif self.state == STATE.COMMAND then
            -- Escaping IAC
            if byte == libtelnet.COMMANDS.IAC then
                if self.onTelnetData then
                    self:onTelnetData(char)
                end

                self.state = STATE.DATA

            -- Initiating subnegotiation
            elseif byte == libtelnet.COMMANDS.SB then
                self.state = STATE.SB

            -- Initiating negotiation
            elseif byte == libtelnet.COMMANDS.WILL then
                self.state = STATE.WILL
                
            elseif byte == libtelnet.COMMANDS.WONT then
                self.state = STATE.WONT

            elseif byte == libtelnet.COMMANDS.DO then
                self.state = STATE.DO

            elseif byte == libtelnet.COMMANDS.DONT then
                self.state = STATE.DONT

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
            end

        elseif self.state == STATE.SB_COMMAND then
            -- Subnegotiation done
            if byte == libtelnet.COMMANDS.SE then
                self:processSubnegotiation()
                self.state = STATE.DATA

            -- Escaping IAC
            elseif byte == libtelnet.COMMANDS.IAC then
                self.subnegotiationBuffer:write(char)
                self.state = STATE.SB_DATA
            end

        -- Processing negotiation
        elseif self.state == STATE.WILL
            or self.state == STATE.WONT
            or self.state == STATE.DO
            or self.state == STATE.DONT 
        then
            self:processNegotiation(byte)
            self.state = STATE.DATA
        end
    end
end

-- Create new instance
function libtelnet.new()
    local telnet = {
        state = STATE.DATA
    }

    telnet.send = telnetSend
    telnet.sendCommand = telnetSendCommand
    telnet.beginSubnegotiation = telnetBeginSubnegotiation
    telnet.endSubnegotiation = telnetEndSubnegotiation
    telnet.sendSubnegotiation = telnetSendSubnegotiation
    telnet.sendTerminalType = telnetSendTerminalType
    telnet.sendWindowSize = telnetSendWindowSize
    telnet.receive = telnetReceive
    telnet.processNegotiation = telnetProcessNegotiation
    telnet.processSubnegotiation = telnetProcessSubnegotiation

    return telnet
end

-----------------------------------------------

return libtelnet