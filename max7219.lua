--------------------------------------------------------------------------------
-- MAX7229 module for NodeMCU
-- SOURCE: https://github.com/marcelstoer/nodemcu-max7219
-- AUTHOR: marcel at frightanic dot com
-- LICENSE: http://opensource.org/licenses/MIT
--------------------------------------------------------------------------------

-- Set module name as parameter of require
local modname = ...
local M = {}
_G[modname] = M
--------------------------------------------------------------------------------
-- Local variables
--------------------------------------------------------------------------------
local debug = false
local numberOfModules
local numberOfColumns
-- ESP8266 pin which is connected to CS of the MAX7219
local slaveSelectPin
-- numberOfModules * 8 bytes for the char representation, left-to-right
local columns = {}

dofile("reverseBytes.lua")

--------------------------------------------------------------------------------
-- Local/private functions
--------------------------------------------------------------------------------
local reverse = function(byte)
  -- tables in Lua are 1-based -> the reverse of 0 is at index 1
  return reverseBytes[byte + 1]
end

local function sendByte(module, register, data)
  -- out("module: " .. module .. " register: " .. register .. " data: " .. data)
  spiRegister = {}
  spiData = {}

  -- set all to 0 by default
  for i = 1, numberOfModules do
    spiRegister[i] = 0
    spiData[i] = 0
  end

  -- set the values for just the affected display
  spiRegister[module] = register
  spiData[module] = data

  -- enble sending data
  gpio.write(slaveSelectPin, gpio.LOW)

  for i = 1, numberOfModules do
    spi.send(1, spiRegister[i] * 256 + spiData[i])
  end

  -- make the chip latch data into the registers
  gpio.write(slaveSelectPin, gpio.HIGH)
end

local function numberToTable(number, base, minLen)
  local t = {}
  repeat
    local remainder = number % base
    table.insert(t, 1, remainder)
    number = (number - remainder) / base
  until number == 0
  if #t < minLen then
    for i = 1, minLen - #t do table.insert(t, 1, 0) end
  end
  return t
end

local function rotate(char, rotateleft)
  local matrix = {}
  local newMatrix = {}

  for _, v in ipairs(char) do table.insert(matrix, numberToTable(v, 2, 8)) end

  if rotateleft then
    for i = 8, 1, -1 do
      local s = ""
      for j = 1, 8 do
        s = s .. matrix[j][i]
      end
      table.insert(newMatrix, tonumber(s, 2))
    end
  else
    for i = 1, 8 do
      local s = ""
      for j = 8, 1, -1 do
        s = s .. matrix[j][i]
      end
      table.insert(newMatrix, tonumber(s, 2))
    end
  end
  return newMatrix
end

local function commit()
  -- for every module (1 to numberOfModules) send registers 1 - 8
  -- since Lua uses 1-based indexes it's a bit of a +-1 dance here, sample:
  --    module: 1 register: 1 data: 64
  --    module: 1 register: 2 data: 66
  --    ...
  --    module: 1 register: 8 data: 0
  --    module: 2 register: 1 data: 98
  --    ...
  --    module: 2 register: 8 data: 0
  --    module: 3 register: 1 data: 34
  --    ...
  --    module: 3 register: 8 data: 0
  for i = 1, numberOfColumns do
    local module = math.floor(((i - 1) / 8) + 1)
    local register = math.floor(((i - 1) % 8) + 1)
    sendByte(module, register, columns[i])
  end
end

local function out(msg)
  if debug then
    print("[MAX7219] " .. msg)
  end
end

--------------------------------------------------------------------------------
-- Public functions
--------------------------------------------------------------------------------
-- Configures both the SoC and the MAX7219 modules.
-- @param config table with the following keys (* = mandatory)
--               - numberOfModules*
--               - slaveSelectPin*, ESP8266 pin which is connected to CS of the MAX7219
--               - debug
function M.setup(config)
  local config = config or {}

  numberOfModules = assert(config.numberOfModules, "'numberOfModules' is a mandatory parameter")
  slaveSelectPin = assert(config.slaveSelectPin, "'slaveSelectPin' is a mandatory parameter")
  numberOfColumns = numberOfModules * 8

  if config.debug then debug = config.debug end

  out("number of modules: " .. numberOfModules .. ", SS pin: " .. slaveSelectPin)

  local MAX7219_REG_DECODEMODE = 0x09
  local MAX7219_REG_INTENSITY = 0x0A
  local MAX7219_REG_SCANLIMIT = 0x0B
  local MAX7219_REG_SHUTDOWN = 0x0C
  local MAX7219_REG_DISPLAYTEST = 0x0F

  spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 16, 8)
  -- Must NOT be done _before_ spi.setup() because that function configures all HSPI* pins for SPI. Hence,
  -- if you want to use one of the HSPI* pins for slave select spi.setup() would overwrite that.
  gpio.mode(slaveSelectPin, gpio.OUTPUT)
  gpio.write(slaveSelectPin, gpio.HIGH)

  for i = 1, numberOfModules do
    sendByte(i, MAX7219_REG_SCANLIMIT, 7)
    sendByte(i, MAX7219_REG_DECODEMODE, 0x00)
    sendByte(i, MAX7219_REG_DISPLAYTEST, 0)
    sendByte(i, MAX7219_REG_INTENSITY, 1)
    sendByte(i, MAX7219_REG_SHUTDOWN, 1)
  end

  M.clear()
end

function M.clear()
  for i = 1, numberOfColumns do
    columns[i] = 0
  end
  commit()
end

function M.write(chars, transformation)
  local transformation = transformation or {}

  local c = {}
  for i = 1, #chars do
    local char = chars[i]

    if transformation.rotate ~= nil then
      char = rotate(char, transformation.rotate == "left")
    end

    for k, v in ipairs(char) do
      if transformation.invert == true then
        -- module offset + inverted register + 1
        -- to produce 8, 7 .. 1, 16, 15 ... 9, 24, 23 ...
        local index = ((i - 1) * 8) + 8 - k + 1
        c[index] = reverse(v)
      else
        table.insert(c, v)
      end
    end
  end

  columns = c
  commit()
end

-- Sets the brightness of the display.
-- intensity: 0x00 - 0x0F (0 - 15)
function M.setIntensity(intensity)
	local MAX7219_REG_INTENSITY = 0x0A
  
  for i = 1, numberOfModules do
    sendByte(i, MAX7219_REG_INTENSITY, intensity)
  end
end

-- Turns the display on or off.
-- shutdown: true=turn off, false=turn on
function M.shutdown(shutdown)
	local MAX7219_REG_SHUTDOWN = 0x0C
	
	for i = 1, numberOfModules do
		if (shutdown) then 
			sendByte(i, MAX7219_REG_SHUTDOWN, 0) 
		else 
			sendByte(i, MAX7219_REG_SHUTDOWN, 1) 
		end
	end
end

-- add scrolling support
function M.write7segment(text, padLeft)
    local tab = {}

    local lenNoDots = text:gsub("%.", ""):len()
    
    -- pad with spaces to turn off not required digits
    if (lenNoDots < (8 * numberOfModules)) then
    	if (padLeft) then
    		text = string.rep(" ", (8 * numberOfModules) - lenNoDots) .. text
    	else
    		text = text .. string.rep(" ", (8 * numberOfModules) - lenNoDots)
    	end
    end
    
    local wasdot = false
    
    local font7seg = require("font7seg")
    
    for i=string.len(text), 1, -1 do
    		
    		local currentChar = text:sub(i,i)
    		
    		if (currentChar == ".") then
    			wasdot = true
    		else
	    		if (wasdot) then
	    			wasdot = false
	    			-- take care of the decimal point
	    			table.insert(tab, font7seg.GetChar(currentChar) + 0x80)
	    		else
	    			table.insert(tab, font7seg.GetChar(currentChar))
	    		end    		
    		end
    end
    
    package.loaded[font7seg] = nil
		_G[font7seg] = nil
    font7seg = nil
    
		-- todo 1 table per module is required
    max7219.write( { tab } , { invert = false })
end

return M
