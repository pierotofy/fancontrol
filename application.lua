List = require('list')

ActionPins = {
    light=5,
    stop=6,
    slow=7,
    medium=8,
    high=9
}

ChannelPins = { 0, 1, 2, 3 }

-- Set PINs
for _, pin in pairs(ChannelPins) do
    gpio.mode(pin, gpio.OUTPUT)
end

for _, pin in pairs(ActionPins) do
    gpio.mode(pin, gpio.OUTPUT)
end


-- Action queue
aq = List.new()

parseChannelStr = function(channel)
    if #channel == 4 then
        out = {}
        for idx, v in pairs(ChannelPins) do
            ch = channel:sub(idx, idx)
            out[v] = ch == '1' and gpio.HIGH or gpio.LOW
        end
        return out
    end
end

startQueueMonitor = function()
    print("Starting queue monitor...")
    local t = tmr.create()
    t:register(1000, tmr.ALARM_AUTO, function()
        pinAct = List.popright(aq)
        if pinAct ~= nil then
            for pin, mode in pairs(pinAct) do
                gpio.write(pin, mode)
                print(pin, mode)
            end
        end
    end)
    t:start()
end

startServer = function()
    print("Setting up server...")
    require("httpserver").createServer(80, function(req, res)
        -- analyse method and url
        print("+R", req.method, req.url, node.heap())

        local out = ""
        if req.url == "/push" then
            for a,v in pairs(ActionPins) do
                out = out .. a .. "\n"
            end
        else
            channel, action = string.match(req.url, "/push/(%d%d%d%d)/(%w+)")
            if channel ~= nil and action ~= nil then
                channelPins = parseChannelStr(channel)
                if channelPins ~= nothing then

                    channelPinAct = {}
                    actionPinAct = {}
                    resetActionPinAct = {}

                    for pin, mode in pairs(channelPins) do
                        channelPinAct[pin] = mode
                    end

                    -- Check command
                    actionPin = ActionPins[action]
                    if actionPin ~= nil then

                        -- Current pin high, others low
                        actionPinAct[actionPin] = gpio.HIGH
                        for _, pin in pairs(ActionPins) do
                            if pin ~= actionPin then
                                actionPinAct[pin] = gpio.LOW
                            end
                        end

                        -- Stop actions afterwards
                        for _, pin in pairs(ActionPins) do
                            resetActionPinAct[pin] = gpio.LOW
                        end

                        for _, pin in pairs(ChannelPins) do
                            resetActionPinAct[pin] = gpio.LOW
                        end

                        List.pushleft(aq, channelPinAct)
                        List.pushleft(aq, actionPinAct)
                        List.pushleft(aq, resetActionPinAct)
                    else
                        out = "Invalid action"
                    end
                else
                    out = "Invalid channel"
                end
            else
                if file.open("index.html") then
                    out = file.read()
                    file.close()
                else
                    out = "Cannot load index.html"
                end
            end
        end
        res:finish(out, 200)
    end)
    startQueueMonitor()
    print("Ready!")
end

setupPortal = function()
    print("Setting WIFI")
    --wifi.mode(wifi.SOFTAP)
    print("Enabling captive portal")
    enduser_setup.start(function()
        print("Connected to WiFi as:" .. wifi.sta.getip())
        startServer()
    end,
    function(err, str)
        print("enduser_setup: Err #" .. err .. ": " .. str)
    end)
end

wifi.sta.sethostname("fancontrol")

if (file.exists('eus_params.lua')) then
    -- Try to connect using existing parameters

    p = dofile('eus_params.lua')

    wifi.setmode(wifi.STATION)
    wifi.sta.config({ssid=p.wifi_ssid, pwd=p.wifi_password, auto=true})

    local t = tmr.create()
    t:register(1000, tmr.ALARM_AUTO, function()
        if wifi.sta.getip() == nil then
            print("Connecting to "..p.wifi_ssid.."...")
        else
           print('IP: ',wifi.sta.getip())
           startServer()
           t:unregister() 
        end
    end)
    t:start()
else
    setupPortal()
end



