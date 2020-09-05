startServer = function()
    print("Setting up server...")
    require("httpserver").createServer(80, function(req, res)
        -- analyse method and url
        print("+R", req.method, req.url, node.heap())

        local out = ""
        if req.url == "/push" then
            out = "light\nstop\nslow\nmedium\nhigh"
        else
            channel, action = string.match(req.url, "/push/(%d%d%d%d)/(%w+)")
            if channel ~= nil and action ~= nil then
                print("ACTIVATE! " .. channel)
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



