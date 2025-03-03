--- @meta DataLink
---
--- DataLink - Efficient data compression for ESO
--- that avoids profanity filter issues.
---
--- @module "DataLink"
--- @author @dack_janiels
--- @version 1.0

-- DataLink.lua
--
-- A library for efficient data compression avoiding profanity filter issues
-- Author: @dack_janiels
-- Version: 1.0
--- @class DataLink
DataLink = {}

--- @class DataLink
local DL = DataLink

-- Library version
DL.version = 1.0

--- Safe character set used for encoding.
--- Excludes all vowels (a,e,i,o,u), visually confusing chars (0,O,1,l,I),
--- and characters that might form common profanities when combined.
--- @type string
DL.SAFE_CHARS = "bcdfghjkmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ23456789-_~!@#$%^&*()+={}[]<>"

--- The base size used for encoding (length of SAFE_CHARS).
--- @type integer
DL.BASE = #DL.SAFE_CHARS

--- Maps each character to its index in the safe chars string.
--- @type table<string, integer>
DL.CHAR_TO_INDEX = {}
for i = 1, #DL.SAFE_CHARS do
    local char = DL.SAFE_CHARS:sub(i, i)
    DL.CHAR_TO_INDEX[char] = i - 1
end

-------------------------------------------------
-- Core Encoding/Decoding Functions
-------------------------------------------------

--- Encodes an integer into our custom base.
--- @param num integer The number to encode
--- @return string @The encoded string
function DL.encodeInt(num)
    if num == 0 then return DL.SAFE_CHARS:sub(1, 1) end

    local result = ""
    while num > 0 do
        local remainder = num % DL.BASE
        result = DL.SAFE_CHARS:sub(remainder + 1, remainder + 1) .. result
        num = math.floor(num / DL.BASE)
    end

    return result
end

--- Decodes a custom base string back to an integer.
--- @param str string The string to decode
--- @return integer|nil @The decoded number, or nil if the string contains invalid characters
function DL.decodeInt(str)
    local num = 0
    for i = 1, #str do
        local char = str:sub(i, i)
        local value = DL.CHAR_TO_INDEX[char]
        if value == nil then
            return nil -- Invalid character encountered
        end
        num = num * DL.BASE + value
    end

    return num
end

--- Encodes a binary string (sequence of bits) using our custom base.
--- @param bitString string A string of "0" and "1" characters
--- @return string|nil @The encoded string, or nil if the bitString contains invalid characters
function DL.encodeBits(bitString)
    -- First convert the binary string to a number
    local num = 0
    for i = 1, #bitString do
        local bit = bitString:sub(i, i)
        if bit ~= "0" and bit ~= "1" then
            return nil -- Invalid bit string
        end
        num = num * 2 + (bit == "1" and 1 or 0)
    end

    -- Then encode that number
    return DL.encodeInt(num)
end

--- Decodes a string back to binary format with specified length.
--- @param str string The string to decode
--- @param bitLength integer The expected bit length for padding
--- @return string|nil @The binary string, or nil if the string contains invalid characters
function DL.decodeToBits(str, bitLength)
    local num = DL.decodeInt(str)
    if not num then return nil end

    local bits = ""
    while num > 0 do
        bits = (num % 2 == 1 and "1" or "0") .. bits
        num = math.floor(num / 2)
    end

    -- Pad with leading zeros to reach desired bit length
    bits = string.rep("0", bitLength - #bits) .. bits
    return bits
end

-------------------------------------------------
-- Data Table Encoding/Decoding
-------------------------------------------------

--- Pack a table of numbers into a bit string according to specified bit lengths.
--- @param data integer[] Table of numbers to encode
--- @param bitLengths integer[] Table of bit lengths for each number
--- @return string|nil @The packed bit string, or nil if data and bitLengths have different lengths
function DL.packBits(data, bitLengths)
    if #data ~= #bitLengths then
        return nil -- Mismatch between data and bit lengths
    end

    local bitString = ""
    for i = 1, #data do
        local num = data[i]
        local bits = ""

        -- Convert number to binary representation
        for j = 1, bitLengths[i] do
            bits = (num % 2 == 1 and "1" or "0") .. bits
            num = math.floor(num / 2)
        end

        -- Ensure correct bit length
        bits = string.rep("0", bitLengths[i] - #bits) .. bits
        bitString = bitString .. bits
    end

    return bitString
end

--- Unpack a bit string into a table of numbers according to specified bit lengths.
--- @param bitString string The bit string to unpack
--- @param bitLengths integer[] Table of bit lengths for each number
--- @return integer[]|nil @Table of unpacked numbers, or nil if the bit string is too short
function DL.unpackBits(bitString, bitLengths)
    local data = {}
    local pos = 1

    for i = 1, #bitLengths do
        if pos + bitLengths[i] - 1 > #bitString then
            return nil -- Bit string too short
        end

        local bits = bitString:sub(pos, pos + bitLengths[i] - 1)
        local num = 0

        for j = 1, #bits do
            local bit = bits:sub(j, j)
            num = num * 2 + (bit == "1" and 1 or 0)
        end

        data[i] = num
        pos = pos + bitLengths[i]
    end

    return data
end

-------------------------------------------------
-- High-Level API Functions
-------------------------------------------------

--- Encodes a table of numbers according to specified bit lengths.
--- Returns a compressed string safe for in-game links.
--- @param data integer[] Table of numbers to encode
--- @param bitLengths integer[] Table of bit lengths for each number
--- @return string|nil @The encoded string, or nil if encoding failed
function DL.encode(data, bitLengths)
    local bitString = DL.packBits(data, bitLengths)
    if not bitString then return nil end

    return DL.encodeBits(bitString)
end

--- Decodes a compressed string back to a table of numbers.
--- @param str string The string to decode
--- @param bitLengths integer[] Table of bit lengths for each number
--- @return integer[]|nil @Table of decoded numbers, or nil if decoding failed
function DL.decode(str, bitLengths)
    local totalBits = 0
    for _, bits in ipairs(bitLengths) do
        totalBits = totalBits + bits
    end

    local bitString = DL.decodeToBits(str, totalBits)
    if not bitString then return nil end

    return DL.unpackBits(bitString, bitLengths)
end

-------------------------------------------------
-- Utility Functions
-------------------------------------------------

--- Calculates the minimum number of bits needed to represent a value.
--- @param maxValue integer The maximum value to represent
--- @return integer @The number of bits required
function DL.bitsRequired(maxValue)
    if maxValue <= 0 then return 1 end
    return math.ceil(math.log(maxValue + 1) / math.log(2))
end

--- @class SchemaField
--- @field name string The field name
--- @field maxValue integer The maximum value this field can have

--- @class Schema
--- @field encode fun(data: table): string|nil Encode data according to the schema
--- @field decode fun(str: string): table|nil Decode a string according to the schema

--- Create a schema for common data types to simplify encoding.
--- @param schema SchemaField[] Array of schema field definitions
--- @return Schema @The schema object with encode and decode methods
function DL.createSchema(schema)
    local bitLengths = {}

    for _, field in ipairs(schema) do
        table.insert(bitLengths, DL.bitsRequired(field.maxValue))
    end

    return
    {
        --- Encode data according to the schema.
        --- @param data table Table with named fields matching the schema
        --- @return string|nil @The encoded string, or nil if encoding failed
        encode = function (data)
            local values = {}
            for i, field in ipairs(schema) do
                table.insert(values, data[field.name] or 0)
            end
            return DL.encode(values, bitLengths)
        end,

        --- Decode a string according to the schema.
        --- @param str string The string to decode
        --- @return table|nil @Table with named fields matching the schema, or nil if decoding failed
        decode = function (str)
            local values = DL.decode(str, bitLengths)
            if not values then return nil end

            local result = {}
            for i, field in ipairs(schema) do
                result[field.name] = values[i]
            end

            return result
        end
    }
end

-------------------------------------------------
-- Test Functions
-------------------------------------------------

--- Run tests for the DataLink library.
--- This function will test various encoding/decoding scenarios.
function DL.test()
    -- Test integer encoding/decoding
    local testInts = { 0, 42, 1000, 123456, 9876543 }
    for _, num in ipairs(testInts) do
        local encoded = DL.encodeInt(num)
        local decoded = DL.decodeInt(encoded)
        assert(decoded == num, "Integer encode/decode failed for: " .. num)
        d(string.format("Int %d encoded as: %s (length: %d)", num, encoded, #encoded))
    end

    -- Test the example from the forum post, https://www.esoui.com/forums/showpost.php?p=51190&postcount=3
    local allianceId = 2 -- 2 bits (max 3)
    local raceId = 7     -- 4 bits (max 10)
    local cpLevel = 455  -- 12 bits (max 3600)

    local schema = DL.createSchema(
        {
            { name = "alliance", maxValue = 3 },
            { name = "race",     maxValue = 10 },
            { name = "cpLevel",  maxValue = 3600 }
        })

    local testData =
    {
        alliance = allianceId,
        race = raceId,
        cpLevel = cpLevel
    }

    local encoded = schema.encode(testData)
    local decoded = schema.decode(encoded)

    d("Example test:")
    d(string.format("Original: Alliance=%d, Race=%d, CP=%d", testData.alliance, testData.race, testData.cpLevel))
    d("Encoded: " .. encoded)
    d(string.format("Decoded: Alliance=%d, Race=%d, CP=%d", decoded.alliance, decoded.race, decoded.cpLevel))

    d("DataLink tests passed!")
end

-- Return the library as a global
return DataLink
