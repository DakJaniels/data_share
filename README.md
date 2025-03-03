# DataLink

A Lua library for Elder Scrolls Online that provides efficient data compression for in-game links and saved variables, while avoiding profanity filter issues.

## Overview

DataLink solves a specific problem in ESO addons: efficiently encoding numerical data for transmission via in-game links or storage in SavedVariables, without triggering the profanity filter. It uses a custom base encoding with a carefully selected character set that avoids vowels and problematic character combinations.

### Key Features

- Efficient bit-packing for numerical data
- Customized character set to avoid profanity filter triggers
- Schema-based encoding/decoding for common data types
- Works with ESO's Lua 5.1 environment
- Fully annotated for LuaLS (Lua Language Server) support

## Installation

1. Copy the DataLink folder to your AddOns directory
2. Add DataLink as a dependency in your addon's manifest file, with version check (`YourAddon.txt`):

```txt
## DependsOn: DataLink>=1
```

## Usage

### Basic Usage

```lua
-- In your addon's initialization
-- DataLink is available as a global after it loads

-- Encode some numbers with specified bit lengths
local data = {2, 7, 455}              -- Alliance, Race, CP level
local bitLengths = {2, 4, 12}         -- Bit length for each value
local encoded = DataLink.encode(data, bitLengths)

-- Later, decode the data
local decoded = DataLink.decode(encoded, bitLengths)
```

### Schema-Based Usage

```lua
-- Create a schema for character builds
local buildSchema = DataLink.createSchema({
    {name = "alliance", maxValue = 3},    -- 2 bits (max 3)
    {name = "race", maxValue = 10},       -- 4 bits (max 10)
    {name = "class", maxValue = 7},       -- 3 bits (max 7)
    {name = "level", maxValue = 50}       -- 6 bits (max 50)
})

-- Encode using the schema
local buildData = {
    alliance = 2,   -- Daggerfall Covenant
    race = 7,       -- Nord
    class = 3,      -- Dragonknight
    level = 50      -- Level 50
}
local encodedBuild = buildSchema.encode(buildData)

-- Decode using the schema
local decodedBuild = buildSchema.decode(encodedBuild)
```

### Clickable In-Game Links

To create clickable in-game links that transmit data:

```lua
local function createLink(linkType, data)
    return string.format("|H1:DataLink:%s:%s|h[Click me]|h", linkType, data)
end

-- Register a handler for your links
LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, YourLinkHandler, "DataLink")
```

## Technical Details

DataLink works by:

1. Converting numerical values to a compact binary representation with specified bit lengths
2. Combining these binary values into a single bitstring
3. Encoding the bitstring using a custom character set designed to avoid profanity filter issues

The character set excludes vowels (a,e,i,o,u) and potentially problematic combinations to avoid forming words that would trigger the profanity filter.

## LuaLS Support

DataLink has full LuaLS (Lua Language Server) annotation support, providing:

- Type checking
- Code completion
- Function parameter hints
- Return type information

This enhances the development experience in editors that support the Language Server Protocol (LSP), such as Visual Studio Code with the Lua extension.

Example of working with annotated code:

```lua
-- LuaLS will provide auto-completion and type checking
---@type integer[] 
local myData = {1, 2, 3}

---@type integer[]
local bitLengths = {4, 4, 4}

-- Function signature and parameter types are available
local encoded = DataLink.encode(myData, bitLengths)

-- Schema creation with proper type information
local schema = DataLink.createSchema({
    {name = "value1", maxValue = 15},
    {name = "value2", maxValue = 15},
    {name = "value3", maxValue = 15}
})

-- The schema object has properly typed methods
local result = schema.encode({value1 = 1, value2 = 2, value3 = 3})
```

## Use Cases

- Sharing character builds via chat links
- Sharing map pins or locations
- Compact storage of numerical data in SavedVariables
- Efficient transmission of structured data via chat

## Example

See `DataLinkExample` addon for a working demonstration of how to use DataLink in your addon. The example includes:

- Creating schemas for character builds and map pins
- Encoding/decoding data
- Creating clickable in-game links
- Handling link clicks to display the decoded data

## Directory Structure

Proper ESO addon structure:

```txt
ESO/live/AddOns/
  ├── DataLink/               # The library addon
  │   ├── DataLink.txt        # Library manifest
  │   └── DataLink.lua        # Library code
  │
  └── DataLinkExample/        # The example addon
      ├── DataLinkExample.txt # Example manifest
      └── DataLinkExample.lua # Example code
```

## Credits

Inspired by discussions on the ESOUI forums about efficient data encoding for addons.

## License

Public Domain - Use freely in your projects.
