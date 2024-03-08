local component = require("component")
local computer = require("computer")
local shell = require("shell")
local fs = require("filesystem")

local internet = component.internet

local args, options = shell.parse(...)

local CONNECTION_TIMEOUT = 5
local REPO = "https://raw.githubusercontent.com/Smok1e/oc-openos-telnet/" .. (options.branch or "master") .. "/"

-------------------------------------------

-- Downloads whole file
local function download(url)
    checkArg(1, url, "string")

    local request = internet.request(url)
    local connectionStartTime = computer.uptime()

    local success, reason
    while not success do
        success, reason = request.finishConnect()
        
        if success == nil then
            error("unable to download " .. url)
        end

        if computer.uptime() - connectionStartTime > CONNECTION_TIMEOUT then
            error("connection timed out")
        end
    end

    local data, chunk = ""
    repeat
        chunk = request.read(math.huge)
        data = data ..(chunk or "")
    until not chunk
    request.close()

    return data
end

local function install()
    local function status(format, ...)
        if options.q or options.quiet then
            return
        end

        print(format:format(...))
    end

    status("Starting installer...")

    local function downloadAndSave(url, path)
        status("Downloading %s...", path)
        local data, reason = download(url)
        if not data then
            error(reason)
        end

        local file, reason = fs.open(path, 'wb')
        if not file then
            error(reason)
        end

        file:write(data)
        file:close()
    end

    local function mkdir(path)
        status("Creating directory %s", path)

        if not fs.isDirectory(path) then
            if fs.exists(path) then
                io.stderr:write("Failed to create directory '" .. path .. "', because it is an existing file. Delete this file and retry the installation\n")
                os.exit()
            end

            fs.makeDirectory(path)
        end
    end

    -- Installation
    mkdir("/usr")
    mkdir("/usr/bin")
    mkdir("/usr/lib")

    downloadAndSave(REPO .. "libtelnet.lua", "/usr/lib/libtelnet.lua")
    downloadAndSave(REPO .. "telnet.lua",    "/usr/bin/telnet.lua"   )

    status("Installation complete")
    status("Telnet has been installed succesfully!")
end

local function help()
    print("Usage: installer [options]")
    print("Options:")
    print("  -h --help: Print usage and exit")
    print("  -q --quiet: Print only errors")
    print("     --branch=branch: Specify repository branch")
end

if options.h or options.help then
    help()
else
    install()
end

-------------------------------------------