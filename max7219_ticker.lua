
-- Set module name as parameter of require

require("font8x8");

local M = {}

--------------------------------------------------------------------------------
-- Local variables
--------------------------------------------------------------------------------

local numberOfModules

--Array for every module shift data
local arr = {
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
 { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
 }


-- ESP8266 pin which is connected to CS of the MAX7219
local slaveSelectPin = 8



local function sendByte(module, register, data)
  spiRegister = {}
  spiData = {}
 local i
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




--Write 8-byte array to module
local function WriteModule(module,data)
local i
    for i = 1, 8 do
        sendByte(module, i, data[i])
    end
        
    collectgarbage()
end


--Shift to right one byte of char
local function Shift(data)

local i
local m
    
--For each row
for  i=1,8 do  

    --Shift first module
    arr[1][i] = bit.lshift(arr[1][i] , 1)
        
    --Get data for first row
    if  bit.isset(data,i-1) == true then
         arr[1][i] = bit.set(arr[1][i],0)
    else
         arr[1][i] = bit.clear(arr[1][i],0)
    end

    --Shift data on each modules
    for m=numberOfModules , 1, -1 do
    
        --First module
        if m == 1 then
            if bit.isset(arr[m][i],8) == true then
                 arr[m+1][i] = bit.set(arr[m+1][i],0)
                 arr[m][i] = bit.clear(arr[m][i],8)
            end
            
        --Last module
        elseif m == numberOfModules then
            
            if bit.isset(arr[m][i],7) == true then
                arr[m][i] = bit.clear(arr[m][i],7) 
            end
            arr[m][i] = bit.lshift(arr[m][i] , 1) 
            
        --Other moduls
        else

             if bit.isset(arr[m][i],7) == true then
                 arr[m+1][i] = bit.set(arr[m+1][i],0)
                 arr[m][i] = bit.clear(arr[m][i],7)
            end

            arr[m][i] = bit.lshift(arr[m][i] , 1) 
        
        end

    end --Shift data on each modules

    --collectgarbage()

end --For each row

for m=numberOfModules , 1, -1 do
    WriteModule(m, arr[numberOfModules-m+1])
end




end

--Print one char 
local function PrintChar(char)

local i

for i=1 , 8 do
    Shift(char[i])
end
    collectgarbage()
    tmr.wdclr()
end




function M.setup(config)
 
  local config = config or {}

 numberOfModules = config.numberOfModules
  slaveSelectPin = config.slaveSelectPin

  local MAX7219_REG_DECODEMODE = 0x09
  local MAX7219_REG_INTENSITY = 0x0A
  local MAX7219_REG_SCANLIMIT = 0x0B
  local MAX7219_REG_SHUTDOWN = 0x0C
  local MAX7219_REG_DISPLAYTEST = 0x0F

  spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 16, 8)

  for i = 1, numberOfModules do
    sendByte(i, MAX7219_REG_SCANLIMIT, 7)
    sendByte(i, MAX7219_REG_DECODEMODE, 0x00)
    sendByte(i, MAX7219_REG_DISPLAYTEST, 0)
    sendByte(i, MAX7219_REG_INTENSITY, 1)
    sendByte(i, MAX7219_REG_SHUTDOWN, 1)
  end
  gpio.mode(slaveSelectPin, gpio.OUTPUT)

end


--Print string 
function M.Print(str)
    for i=1, string.len(str) do
        PrintChar(GetChar(str:sub(i,i)))
    end

end




return M
