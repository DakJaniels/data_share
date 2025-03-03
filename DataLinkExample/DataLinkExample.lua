--- @meta DataLinkExample
---
--- DataLinkExample - Example addon demonstrating DataLink usage
--- Shows how to use DataLink for efficient data compression in ESO addons
---
--- @module "DataLinkExample"
--- @author @dack_janiels
--- @version 1.0
--- @dependency DataLink

-- DataLinkExample.lua
--
-- An ESO addon showing how to use DataLink for efficient data compression
-- that avoids profanity filter issues
--
-- Author: @dack_janiels

local ADDON_NAME = "DataLinkExample"

-- Initialize our addon namespace
DataLinkExample = {}

--- @type Schema
DataLinkExample.BuildSchema = nil

--- @type Schema
DataLinkExample.MapPinSchema = nil

--- Initialize the addon
function DataLinkExample.Initialize()
    -- Create some example schemas for common data types
    DataLinkExample.BuildSchema = DataLink.createSchema(
        {
            { name = "allianceId", maxValue = 3 },   -- 2 bits
            { name = "raceId",     maxValue = 10 },  -- 4 bits
            { name = "classId",    maxValue = 7 },   -- 3 bits
            { name = "weaponType", maxValue = 15 },  -- 4 bits
            { name = "armorType",  maxValue = 3 },   -- 2 bits
            { name = "cpLevel",    maxValue = 3600 } -- 12 bits
        })

    DataLinkExample.MapPinSchema = DataLink.createSchema(
        {
            { name = "x",       maxValue = 1000 }, -- 10 bits (scaled by 1000)
            { name = "y",       maxValue = 1000 }, -- 10 bits (scaled by 1000)
            { name = "pinType", maxValue = 127 },  -- 7 bits
            { name = "subType", maxValue = 31 },   -- 5 bits
            { name = "zoneId",  maxValue = 2047 }  -- 11 bits
        })

    -- Register slash commands
    SLASH_COMMANDS["/dltest"] = DataLinkExample.RunTests
    SLASH_COMMANDS["/dllink"] = DataLinkExample.CreateExampleLink

    d("[DataLinkExample] Initialized. Type /dltest to run tests or /dllink to create an example character build link.")
end

--- Generates a link that can be clicked in chat
--- @param linkType string The type of link (e.g., "build", "mappin")
--- @param linkData string The encoded data for the link
--- @return string @The formatted chat link
function DataLinkExample.GenerateLink(linkType, linkData)
    -- Encode the link data as a |H...|h[text]|h link
    -- This uses ZOS's link format: |H<linkType>:<linkData>|h[<displayText>]|h
    return string.format("|H1:DataLink:%s:%s|h[%s]|h", linkType, linkData, "Click to view " .. linkType)
end

--- Handler for link clicks
--- @param linkData string The data from the clicked link
--- @param button number The mouse button used for the click
function DataLinkExample.LinkHandler(linkData, button)
    -- Format: linkType:encodedData
    local linkType, encodedData = string.match(linkData, "^([^:]+):(.+)$")

    if not linkType or not encodedData then
        d("[DataLinkExample] Invalid link format")
        return
    end

    if linkType == "build" then
        -- Decode character build data
        local build = DataLinkExample.BuildSchema.decode(encodedData)
        if not build then
            d("[DataLinkExample] Failed to decode build data")
            return
        end

        -- Display the decoded build information
        d("----------------")
        d("Character Build")
        d("----------------")
        d(string.format("Alliance: %d", build.allianceId))
        d(string.format("Race: %d", build.raceId))
        d(string.format("Class: %d", build.classId))
        d(string.format("Weapon: %d", build.weaponType))
        d(string.format("Armor: %d", build.armorType))
        d(string.format("CP Level: %d", build.cpLevel))
    elseif linkType == "mappin" then
        -- Decode map pin data
        local pin = DataLinkExample.MapPinSchema.decode(encodedData)
        if not pin then
            d("[DataLinkExample] Failed to decode map pin data")
            return
        end

        -- Display the decoded map pin information
        d("----------------")
        d("Map Pin")
        d("----------------")
        d(string.format("Position: (%.3f, %.3f)", pin.x / 1000, pin.y / 1000))
        d(string.format("Type: %d, Subtype: %d", pin.pinType, pin.subType))
        d(string.format("Zone ID: %d", pin.zoneId))

        -- You could also add the pin to the map here
        -- AddCustomPin(pin.pinType, pin.subType, pin.zoneId, pin.x/1000, pin.y/1000)
    else
        d("[DataLinkExample] Unknown link type: " .. linkType)
    end
end

--- Create an example character build link and output to chat
function DataLinkExample.CreateExampleLink()
    -- Example character build data
    --- @type table<string, integer>
    local buildData =
    {
        allianceId = 2, -- Daggerfall Covenant
        raceId = 7,     -- Nord
        classId = 3,    -- Dragonknight
        weaponType = 5, -- Two-handed sword
        armorType = 2,  -- Heavy armor
        cpLevel = 810   -- Champion points
    }

    -- Example map pin data
    --- @type table<string, integer>
    local mapPinData =
    {
        x = 324,      -- x coordinate (scaled by 1000)
        y = 756,      -- y coordinate (scaled by 1000)
        pinType = 27, -- Pin type (e.g., treasure chest)
        subType = 3,  -- Pin subtype (e.g., advanced chest)
        zoneId = 534  -- Eastmarch
    }

    -- Encode the data
    local encodedBuild = DataLinkExample.BuildSchema.encode(buildData)
    local encodedMapPin = DataLinkExample.MapPinSchema.encode(mapPinData)

    -- Create the links
    local buildLink = DataLinkExample.GenerateLink("build", encodedBuild)
    local mapPinLink = DataLinkExample.GenerateLink("mappin", encodedMapPin)

    -- Output to chat
    d("Example build link: " .. buildLink)
    d("Example map pin link: " .. mapPinLink)
    d("Click these links to decode and display the data!")

    -- Copy to chat input to make it easy to share with others
    StartChatInput(buildLink)
end

--- Run various tests of the DataLink library
function DataLinkExample.RunTests()
    -- Basic test of the DataLink library functions
    DataLink.test()

    -- Test with potentially problematic data
    --- @type integer[][]
    local testValues =
    {
        { 69,     420,    1337 },                            -- "Meme" numbers
        { 0,      0,      0,      0,     0, 0, 0, 0, 0, 0 }, -- All zeros
        { 999999, 888888, 777777, 666666 }                   -- Very large numbers
    }

    -- Test bitLengths
    --- @type integer[][]
    local bitLengths =
    {
        { 20, 20, 20 },                      -- For test 1
        { 1,  1,  1,  1, 1, 1, 1, 1, 1, 1 }, -- For test 2
        { 24, 24, 24, 24 }                   -- For test 3
    }

    for i, values in ipairs(testValues) do
        local encoded = DataLink.encode(values, bitLengths[i])
        local decoded = DataLink.decode(encoded, bitLengths[i])

        d(string.format("Test %d:", i))
        d("Original: " .. table.concat(values, ", "))
        d("Encoded: " .. encoded .. " (length: " .. #encoded .. ")")

        local success = true
        for j, value in ipairs(values) do
            if decoded[j] ~= value then
                success = false
                d(string.format("Mismatch at position %d: expected %d, got %d", j, value, decoded[j]))
            end
        end

        if success then
            d("Decoded successfully!")
        end
    end

    -- Compare size with simple concatenation
    --- @type integer[]
    local simpleData = { 2, 7, 455 } -- Alliance, Race, CP level
    local simpleStr = "2070455"

    local schema = DataLink.createSchema(
        {
            { name = "alliance", maxValue = 3 },
            { name = "race",     maxValue = 10 },
            { name = "cp",       maxValue = 3600 }
        })

    --- @type integer[]
    local values = { simpleData[1], simpleData[2], simpleData[3] }
    local encoded = schema.encode({ alliance = simpleData[1], race = simpleData[2], cp = simpleData[3] })

    d("Comparison test:")
    d("Simple concatenation: " .. simpleStr .. " (length: " .. #simpleStr .. ")")
    d("DataLink encoding: " .. encoded .. " (length: " .. #encoded .. ")")
    d(string.format("Compression ratio: %.2f%%", (#encoded / #simpleStr) * 100))
end

--- Event handler for addon loaded
--- @param event string The event name
--- @param addonName string The name of the loaded addon
function DataLinkExample.OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end

    -- Register for link handler events
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, DataLinkExample.LinkHandler, "DataLink")

    -- Initialize the addon
    DataLinkExample.Initialize()
end

-- Register for the addon loaded event
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, DataLinkExample.OnAddOnLoaded)

return DataLinkExample
