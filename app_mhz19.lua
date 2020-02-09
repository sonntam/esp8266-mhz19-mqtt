local module = {}
m = nil

print("Loading MH-Z19 CO2 Sensor app")

local led_state     = false

local lowDuration   = 0
local highDuration  = 0
local lastTimestamp = 0

local latestMeasurements = {}

local function wemos_d1_toggle_led()
    led_state = not led_state
    if led_state then
        gpio.write(config.HW.LED_PIN, gpio.HIGH)
    else
        gpio.write(config.HW.LED_PIN, gpio.LOW)
    end
end

local function mhz19_calculate_value(highDuration, lowDuration)
    return config.HW.MZZ19_MAX * (1002.0 * highDuration - 2.0 * lowDuration) / 1000.0 / (highDuration + lowDuration);
end

local function mhz19InterruptHandler(level, timestamp)
    if (level == gpio.LOW) then
        highDuration = timestamp - lastTimestamp
    else
        lowDuration = timestamp - lastTimestamp
        local co2 = mhz19_calculate_value(highDuration, lowDuration)
        table.insert(latestMeasurements, co2)
    end
    lastTimestamp = timestamp
end

local function mhz19_median_value()
        
    -- get a median of the latest CO2 readings
    local measurements = latestMeasurements
    latestMeasurements = {}
    if (#measurements > 0) then
        table.sort(measurements)
        local median = measurements[math.ceil(#measurements / 2 + 1)]
        return median
    else
        return nil
    end
end

-- Sends a simple ping to the broker
local function mqtt_send_ping()
    local rssi   = wifi.sta.getrssi()
    local median = mhz19_median_value()
    m:publish(config.MQTT.ENDPOINT .. "id", config.MQTT.ID,0,0)
    m:publish(config.MQTT.ENDPOINT .. "value", median or "null",0,0)
    m:publish(config.MQTT.ENDPOINT .. "unit", "ppm",0,0)
    m:publish(config.MQTT.ENDPOINT .. "rssi", rssi,0,0)
    print("id:", config.MQTT.ID, "; rssi:", rssi, "dBm; CO2 median:", median,"ppm" )
end

-- Sends my id to the broker for registration
local function mqtt_register_myself()
    m:subscribe(config.MQTT.ENDPOINT .. config.MQTT.ID,0,function(conn)
        print("Successfully subscribed to data endpoint")
    end)
end

local function mqtt_stop()
    m:close()
    m = nil
end

local function mqtt_start()
    m = mqtt.Client(config.MQTT.ID, 120, config.MQTT.USER, config.MQTT.PASSWORD)
    -- register message callback beforehand
    m:on("message", function(conn, topic, data) 
      if data ~= nil then
        print(topic .. ": " .. data)
        -- do something, we have received a message
      end
    end)
    
    m:on("offline", function(conn)
        print("Mqtt client gone offline - reconnecting in 30 seconds")
        tmr.stop(6)
        tmr.alarm(6, 30000, tmr.ALARM_SINGLE, function()
            mqtt_stop()
            mqtt_start()
        end)
    end)
    
    -- Connect to broker
    m:connect(config.MQTT.HOST, config.MQTT.PORT, 0, 0, function(con) 
        mqtt_register_myself()
        -- And then pings each 5000 milliseconds
        tmr.stop(6)
        tmr.alarm(6, 5000, tmr.ALARM_AUTO, mqtt_send_ping)
    end, function(con,reason)
        print("Connection failed with reason: " .. reason .. " - reconnecting in 30 seconds")
        tmr.stop(6)
        tmr.alarm(6, 30000, tmr.ALARM_SINGLE, function()
            mqtt_stop()
            mqtt_start()
        end)
    end) 

end

local function mhz19_attach_interrupt()
  gpio.mode(config.HW.MHZ19_PIN, gpio.INT)
  gpio.trig(config.HW.MHZ19_PIN, "both", mhz19InterruptHandler)
  tmr.stop(4)
  gpio.write(config.HW.LED_PIN, gpio.HIGH)
  print("MH-Z19 is ready")
end

function module.start()
  --get reset reason. If we powered on then we need to wait 120 seconds for
  --the MH-Z19 to be warmed up
  _, reset_reason = node.bootreason()
  
  print("Running app... Reset reason = ", reset_reason)
  
  -- configure LED
  gpio.mode(config.HW.LED_PIN, gpio.OUTPUT)
  gpio.write(config.HW.LED_PIN, gpio.HIGH)
  
  -- blink reset reason
  gpio.serout(config.HW.LED_PIN, gpio.LOW, {750000,250000},reset_reason+1, function()
    -- configure reading MH-Z19
    if (reset_reason == 0 or reset_reason == 6) then
      print("Warming up sensor...")
      tmr.alarm(5,120000, tmr.ALARM_SINGLE, mhz19_attach_interrupt)
      tmr.alarm(4,   200, tmr.ALARM_AUTO, wemos_d1_toggle_led)
    else
      mhz19_attach_interrupt()
    end
  
    --telnet:open(nil, nil, config.TELNET.PORT)
  
    mqtt_start()
  end)
  
end

return module
