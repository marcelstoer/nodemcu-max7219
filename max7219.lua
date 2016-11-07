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

local reverseBytes = {
  0x00, 0x80, 0x40, 0xc0, 0x20, 0xa0, 0x60, 0xe0,
  0x10, 0x90, 0x50, 0xd0, 0x30, 0xb0, 0x70, 0xf0,
  0x08, 0x88, 0x48, 0xc8, 0x28, 0xa8, 0x68, 0xe8,
  0x18, 0x98, 0x58, 0xd8, 0x38, 0xb8, 0x78, 0xf8,
  0x04, 0x84, 0x44, 0xc4, 0x24, 0xa4, 0x64, 0xe4,
  0x14, 0x94, 0x54, 0xd4, 0x34, 0xb4, 0x74, 0xf4,
  0x0c, 0x8c, 0x4c, 0xcc, 0x2c, 0xac, 0x6c, 0xec,
  0x1c, 0x9c, 0x5c, 0xdc, 0x3c, 0xbc, 0x7c, 0xfc,
  0x02, 0x82, 0x42, 0xc2, 0x22, 0xa2, 0x62, 0xe2,
  0x12, 0x92, 0x52, 0xd2, 0x32, 0xb2, 0x72, 0xf2,
  0x0a, 0x8a, 0x4a, 0xca, 0x2a, 0xaa, 0x6a, 0xea,
  0x1a, 0x9a, 0x5a, 0xda, 0x3a, 0xba, 0x7a, 0xfa,
  0x06, 0x86, 0x46, 0xc6, 0x26, 0xa6, 0x66, 0xe6,
  0x16, 0x96, 0x56, 0xd6, 0x36, 0xb6, 0x76, 0xf6,
  0x0e, 0x8e, 0x4e, 0xce, 0x2e, 0xae, 0x6e, 0xee,
  0x1e, 0x9e, 0x5e, 0xde, 0x3e, 0xbe, 0x7e, 0xfe,
  0x01, 0x81, 0x41, 0xc1, 0x21, 0xa1, 0x61, 0xe1,
  0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1,
  0x09, 0x89, 0x49, 0xc9, 0x29, 0xa9, 0x69, 0xe9,
  0x19, 0x99, 0x59, 0xd9, 0x39, 0xb9, 0x79, 0xf9,
  0x05, 0x85, 0x45, 0xc5, 0x25, 0xa5, 0x65, 0xe5,
  0x15, 0x95, 0x55, 0xd5, 0x35, 0xb5, 0x75, 0xf5,
  0x0d, 0x8d, 0x4d, 0xcd, 0x2d, 0xad, 0x6d, 0xed,
  0x1d, 0x9d, 0x5d, 0xdd, 0x3d, 0xbd, 0x7d, 0xfd,
  0x03, 0x83, 0x43, 0xc3, 0x23, 0xa3, 0x63, 0xe3,
  0x13, 0x93, 0x53, 0xd3, 0x33, 0xb3, 0x73, 0xf3,
  0x0b, 0x8b, 0x4b, 0xcb, 0x2b, 0xab, 0x6b, 0xeb,
  0x1b, 0x9b, 0x5b, 0xdb, 0x3b, 0xbb, 0x7b, 0xfb,
  0x07, 0x87, 0x47, 0xc7, 0x27, 0xa7, 0x67, 0xe7,
  0x17, 0x97, 0x57, 0xd7, 0x37, 0xb7, 0x77, 0xf7,
  0x0f, 0x8f, 0x4f, 0xcf, 0x2f, 0xaf, 0x6f, 0xef,
  0x1f, 0x9f, 0x5f, 0xdf, 0x3f, 0xbf, 0x7f, 0xff,
}

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

return M
