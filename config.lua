local module = {}

--[[ WiFi Setup ]]--
module.SSID = {}
module.SSID["***REMOVED***"] = "***REMOVED***"
-- add more WiFi networks if needed

--[[ MQTT setup ]]--
module.MQTT = {}
module.MQTT.FRIENDLYNAME = "MH-Z19_Bedroom"
module.MQTT.HOST         = "raspberrypi4.fritz.box"
module.MQTT.PORT         = 1883
module.MQTT.USER         = "mqtt_home"
module.MQTT.PASSWORD     = "***REMOVED***"
module.MQTT.ENDPOINT     = "nodemcu/" .. module.MQTT.FRIENDLYNAME .. "_" .. node.chipid() .. "/"
module.MQTT.ID           = node.chipid()

--[[ Hardware wiring setup ]]--
module.HW = {}
module.HW.MHZ19_PIN  = 2    -- Pin where the PWM output of the MH-Z19 is connected
module.HW.MZZ19_MAX  = 5000 -- Maximum ppm measurement of the sensor (there is a 2000ppm and a 5000pm type) 
module.HW.DHT_PIN    = 4    -- Pin where the output of the DHT is connected
module.HW.LED_PIN    = 4    -- Pin where the on-board LED is connected

--[[ Telnet setup ]]--
module.TELNET = {}
module.TELNET.PORT       = 2323

-- convenient function for dumping data structs
-- see https://stackoverflow.com/a/27028488
function module.dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. module.dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

return module
