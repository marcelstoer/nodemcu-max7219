# NodeMCU MAX7219
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](https://github.com/marcelstoer/nodemcu-max7219/blob/master/LICENSE)

### A NodeMCU library to write to MAX7219 8x8 matrix displays using SPI

[http://frightanic.com/iot/max7219-library-nodemcu-making/](http://frightanic.com/iot/max7219-library-nodemcu-making/)


```Lua
max7219 = require("max7219")
max7219.setup({debug = true, numberOfModules = 4, slaveSelectPin = 8})
max7219.write({
    { 0x20, 0x74, 0x54, 0x54, 0x3C, 0x78, 0x40, 0x00 },
    { 0x41, 0x7F, 0x3F, 0x48, 0x48, 0x78, 0x30, 0x00 },
    { 0x38, 0x7C, 0x44, 0x44, 0x6C, 0x28, 0x00, 0x00 },
    { 0x30, 0x78, 0x48, 0x49, 0x3F, 0x7F, 0x40, 0x00 }
  }, { rotate = "left" })
```

For using scrolling:
```Lua
max7219 = require("max7219_ticker")
max7219.setup({numberOfModules = 4, slaveSelectPin = 8})
max7219.Print("Hello World!    ")
```


All missing features are tracked as issues on GitHub.
