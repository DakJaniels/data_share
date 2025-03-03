--- @meta DataLinkExample
---
--- DataLinkExample - Example addon demonstrating DataLink usage
--- Shows how to use DataLink for efficient data compression in ESO addons
---
--- @module "DataLinkExample"
--- @author @dack_janiels
--- @version 1.0
--- @dependency DataLink
--- @dependency LibChatMessage

local ADDON_NAME = "DataLinkExample"

-- Define our custom link type
local DATALINK_LINK_TYPE = "DataLink"

-- Initialize LibChatMessage
local LCM = LibChatMessage

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

    -- Register our custom link type with LibChatMessage
    LCM:RegisterCustomChatLink(DATALINK_LINK_TYPE)

    d("[DataLinkExample] Initialized. Type /dltest to run tests or /dllink to create an example character build link.")
end

--- Generates a link that can be clicked in chat using ESO's link handler API
--- @param linkSubType string The subtype of link (e.g., "build", "mappin")
--- @param linkData string The encoded data for the link
--- @return string The formatted chat link
function DataLinkExample.GenerateLink(linkSubType, linkData)
    -- Create display text
    local displayText = "Click to view " .. linkSubType

    -- Use ZO_LinkHandler_CreateLink to create a properly formatted ESO chat link
    -- Format: ZO_LinkHandler_CreateLink(text, color, linkType, ...)
    -- where ... is additional data passed to the link handler
    return ZO_LinkHandler_CreateLink(displayText, nil, DATALINK_LINK_TYPE, linkSubType, linkData)
end

--- Handler for link clicks
--- Used with LINK_HANDLER:RegisterCallback
--- @param linkData string The raw link data
--- @param mouseButton number The mouse button used for the click
--- @param linkText string The text displayed in the link
--- @param color string|nil The link color
--- @param linkType string The link type (should be "DataLink")
--- @param linkSubType string The link subtype (e.g., "build", "mappin")
--- @param encodedData string The encoded data included in the link
--- @return boolean Returns true if the link was handled, false otherwise
function DataLinkExample.LinkHandler(linkData, mouseButton, linkText, color, linkType, linkSubType, encodedData)
    -- Only handle our custom link type
    if linkType ~= DATALINK_LINK_TYPE then
        return false
    end

    if not linkSubType or not encodedData then
        d("[DataLinkExample] Invalid link format")
        return true -- Still return true to prevent errors
    end

    if linkSubType == "build" then
        -- Decode character build data
        local build = DataLinkExample.BuildSchema.decode(encodedData)
        if not build then
            d("[DataLinkExample] Failed to decode build data")
            return true -- Still return true to prevent errors
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

        -- Return true to indicate we handled this link
        return true
    elseif linkSubType == "mappin" then
        -- Decode map pin data
        local pin = DataLinkExample.MapPinSchema.decode(encodedData)
        if not pin then
            d("[DataLinkExample] Failed to decode map pin data")
            return true -- Still return true to prevent errors
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

        -- Return true to indicate we handled this link
        return true
    else
        d("[DataLinkExample] Unknown link type: " .. linkSubType)
        return true -- Still return true to prevent errors
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

    -- Insert the link into the chat box for easy sharing
    -- This is more reliable than directly setting the text
    StartChatInput(ZO_LinkHandler_InsertLink(buildLink))
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
        d(string.format("Test %d:", i))
        d("Original: " .. table.concat(values, ", "))

        -- Show bit requirements for each number
        local bitsRequired = {}
        for j, value in ipairs(values) do
            local bits = DataLink.bitsRequired(value)
            table.insert(bitsRequired, bits)
        end
        d("Bits required: " .. table.concat(bitsRequired, ", "))
        d("Bits allocated: " .. table.concat(bitLengths[i], ", "))

        -- Perform encoding
        local encoded = DataLink.encode(values, bitLengths[i])
        d("Encoded: " .. encoded .. " (length: " .. #encoded .. ")")

        -- Perform decoding
        local decoded = DataLink.decode(encoded, bitLengths[i])

        -- Verify results
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

        d("") -- Empty line for readability
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

    -- Register for link handler events with our simpler handler function
    LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, DataLinkExample.LinkHandler)

    -- Initialize the addon
    DataLinkExample.Initialize()
end

-- Register for the addon loaded event
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, DataLinkExample.OnAddOnLoaded)
