List = require('list')

ActionPins = {
    light=5,
    stop=6,
    low=7,
    medium=8,
    high=9
}

ChannelPins = { 0, 1, 2, 4 }

-- Set PINs
for _, pin in pairs(ChannelPins) do
    gpio.mode(pin, gpio.OUTPUT)
end
gpio.write(4, gpio.HIGH)

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
    t:register(250, tmr.ALARM_AUTO, function()
        pinAct = List.popright(aq)
        if pinAct ~= nil then
            for pin, mode in pairs(pinAct) do
                if pin ~= 4 then
                    gpio.write(pin, mode)
                else
                    gpio.write(pin, mode == gpio.HIGH and gpio.LOW or gpio.HIGH)
                end
            end
        end
    end)
    t:start()
end

startServer = function()
    print("Setting up server...")
    dofile('httpServer.lua')

    httpServer:use('.*', function(req, res)
        local err = ""
        local channel, action = string.match(req.path, "(%d%d%d%d)/(%w+)")
        if channel ~= nil and action ~= nil then
            local channelPins = parseChannelStr(channel)
            if channelPins ~= nothing then

                local channelPinAct = {}
                local actionPinAct = {}
                local resetActionPinAct = {}

                for pin, mode in pairs(channelPins) do
                    channelPinAct[pin] = mode
                end

                -- Check command
                local actionPin = ActionPins[action]
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
                    err = "Invalid action"
                end
            else
                err = "Invalid channel"
            end
        elseif req.path == "/ping" then
        else
            err = "Invalid path"
        end

        res:type('application/json')
        if (err == "") then
            res:send('{"success": true}')
        else
            res:send('{"error" : "' .. err .. '"}')
        end
    end)

    httpServer:listen(80)

    startQueueMonitor()
    print("* READY")
end

setupPortal = function()
    print("Enabling captive portal")
    enduser_setup.start(function()
        print("Connected as:" .. wifi.sta.getip())
        startServer()
    end,
    function(err, str)
        print("Err #" .. err .. ": " .. str)
    end)
end

wifi.sta.sethostname("fancontrol")

if (file.exists('eus_params.lua')) then
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
