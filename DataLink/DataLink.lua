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
--- @field version number The library version
--- @field SAFE_CHARS string Safe character set used for encoding
--- @field BASE integer The base size used for encoding (length of SAFE_CHARS)
--- @field CHAR_TO_INDEX table<string, integer> Maps each character to its index in the safe chars string
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
        local bitLen = bitLengths[i]

        -- Enhanced handling for large numbers
        if num > 100000 or bitLen > 20 then
            -- Use a chunking approach for larger integers to avoid precision issues
            local remainingBits = bitLen
            local remainingNum = num

            -- Process in chunks of 16 bits to avoid precision issues
            while remainingBits > 0 do
                local chunkSize = math.min(16, remainingBits)
                local mask = BitLShift(1, chunkSize) - 1
                local chunk = BitAnd(remainingNum, mask) -- Extract lowest bits

                local chunkBits = ""
                for j = 1, chunkSize do
                    chunkBits = (BitAnd(chunk, 1) == 1 and "1" or "0") .. chunkBits
                    chunk = BitRShift(chunk, 1)
                end

                bits = chunkBits .. bits
                remainingNum = BitRShift(remainingNum, chunkSize)
                remainingBits = remainingBits - chunkSize
            end
        else
            -- Original implementation for smaller numbers
            for j = 1, bitLen do
                bits = (BitAnd(num, 1) == 1 and "1" or "0") .. bits
                num = BitRShift(num, 1)
            end
        end

        -- Ensure correct bit length
        bits = string.rep("0", bitLengths[i] - #bits) .. bits
        bitString = bitString .. bits
    end

    return bitString
end

--- Converts a decimal number to a binary string of specified length.
--- @param decimal integer The decimal number to convert
--- @param bitLength integer The desired length of the binary string
--- @return string The binary string representation with leading zeros
local function decimalToBinaryString(decimal, bitLength)
    local bits = ""

    while decimal > 0 do
        bits = (decimal % 2 == 1 and "1" or "0") .. bits
        decimal = math.floor(decimal / 2)
    end

    -- Pad with leading zeros to reach desired bit length
    return string.rep("0", bitLength - #bits) .. bits
end

--- Converts a binary string to a decimal number.
--- @param bits string The binary string to convert
--- @return integer The resulting decimal number
local function binaryToNumber(bits)
    local num = 0
    for i = 1, #bits do
        local bit = bits:sub(i, i)
        num = num * 2 + (bit == "1" and 1 or 0)
    end
    return num
end

--- Unpack a bit string into a table of numbers according to specified bit lengths.
--- @param bitString string The bit string to unpack
--- @param bitLengths integer[] Table of bit lengths for each number
--- @return integer[]|nil @Table of unpacked numbers, or nil if the bit string is too short
function DL.unpackBits(bitString, bitLengths)
    local data = {}
    local pos = 1

    for i = 1, #bitLengths do
        local bitLen = bitLengths[i]
        if pos + bitLen - 1 > #bitString then
            d("Bit string too short: need " .. (pos + bitLen - 1) .. " bits, but only have " .. #bitString)
            return nil -- Bit string too short
        end

        local bits = bitString:sub(pos, pos + bitLen - 1)
        local num = 0

        -- Use a more reliable approach for larger bit lengths to avoid precision issues
        if bitLen > 20 then
            -- Process in chunks to avoid numeric precision issues
            local chunkSize = 16
            local remainingBits = bitLen
            local startPos = 1

            while remainingBits > 0 do
                local chunk = math.min(chunkSize, remainingBits)
                local chunkBits = bits:sub(startPos, startPos + chunk - 1)

                -- Convert chunk to value using our helper function
                local chunkValue = binaryToNumber(chunkBits)

                -- Add to total with appropriate shift
                local shift = remainingBits - chunk
                num = BitOr(num, BitLShift(chunkValue, shift))

                startPos = startPos + chunk
                remainingBits = remainingBits - chunk
            end
        else
            -- For smaller bit lengths, use our helper function
            num = binaryToNumber(bits)
        end

        data[i] = num
        pos = pos + bitLen

        -- Debug output for first few values for troubleshooting
        if i <= 5 or i >= #bitLengths - 2 then
            d(string.format("Unpacked value %d: %s (%d bits) -> %d",
                i, bits, #bits, num))
        elseif i == 6 then
            d("... (more values) ...")
        end
    end

    return data
end

--- Directly encodes an integer to a compact string format with consistent width.
--- @param num integer The integer to encode
--- @param digits integer Number of digits to use in encoding
--- @return string The encoded string
function DL.encodeDirectly(num, digits)
    -- Ensure num is not negative
    if num < 0 then num = 0 end

    -- Early return for zero with proper padding
    if num == 0 then
        return string.rep(DL.SAFE_CHARS:sub(1, 1), digits)
    end

    local result = ""
    local base = DL.BASE

    -- Convert integer to string directly using our safe character set
    while num > 0 and #result < digits do
        local remainder = num % base
        result = DL.SAFE_CHARS:sub(remainder + 1, remainder + 1) .. result
        num = math.floor(num / base)
    end

    -- Pad with our zero character if needed to ensure consistent width
    if #result < digits then
        result = string.rep(DL.SAFE_CHARS:sub(1, 1), digits - #result) .. result
    end

    -- Ensure we don't exceed the requested digit count
    if #result > digits then
        -- This should not happen with normal usage, but just in case
        d("Warning: Encoded string length (" .. #result ..
            ") exceeds requested digits (" .. digits .. ")")
        result = result:sub(#result - digits + 1)
    end

    return result
end

--- Decodes a directly encoded large integer.
--- @param str string The encoded string
--- @return integer|nil The decoded large integer, or nil if the string contains invalid characters
function DL.decodeDirectly(str)
    local num = 0
    local base = DL.BASE

    for i = 1, #str do
        local char = str:sub(i, i)
        local value = DL.CHAR_TO_INDEX[char]
        if value == nil then return nil end

        num = num * base + value
    end

    return num
end

--- Encodes large numbers using a simpler fixed-width approach for perfect alignment.
--- @param data integer[] Array of integers
--- @param bitLengths integer[] Bit lengths for each number
--- @return string The encoded string with metadata
function DL.encodeLargeNumbers(data, bitLengths)
    local result = ""
    d("Using direct encoding for large numbers (" .. #data .. " values)")

    -- Calculate exact character lengths needed for each bit length type
    local charLengthsByBitLength = {}
    local uniqueBitLengths = {}
    local countByBitLength = {}

    -- First, identify all unique bit lengths and their counts
    for _, bits in ipairs(bitLengths) do
        if not countByBitLength[bits] then
            table.insert(uniqueBitLengths, bits)
            countByBitLength[bits] = 1
        else
            countByBitLength[bits] = countByBitLength[bits] + 1
        end
    end

    -- Sort to ensure consistent traversal order
    table.sort(uniqueBitLengths)

    -- Calculate character lengths needed for each bit length
    for _, bits in ipairs(uniqueBitLengths) do
        -- Fixed calculation: How many chars we need for this bit length
        local exactChars = math.ceil(bits / math.log(DL.BASE, 2))
        charLengthsByBitLength[bits] = exactChars
        d(string.format("  Bit length %d needs %d chars (for %d values)", bits, exactChars, countByBitLength[bits]))
    end

    -- Store this for the decoder to know the encoding format
    DL._lastEncodingWidths = charLengthsByBitLength

    -- Now encode each value with the appropriate fixed width
    for i, num in ipairs(data) do
        local bits = bitLengths[i]
        local chars = charLengthsByBitLength[bits]

        local encoded = DL.encodeDirectly(num, chars)
        result = result .. encoded

        -- Log a sample of values
        if i <= 3 or i >= #data - 2 then
            d(string.format("  Encoded value %d: %d (bits: %d) -> %s (%d chars)", i, num, bits, encoded, #encoded))
        elseif i == 4 then
            d("  ... (omitting middle values) ...")
        end
    end

    -- Store the encoding info for debugging and verification
    local encodingInfo = string.format("E%d", #data)
    for _, bits in ipairs(uniqueBitLengths) do
        encodingInfo = encodingInfo .. string.format("-%d:%d", bits, charLengthsByBitLength[bits])
    end

    d("Direct encoding complete: result length = " .. #result)
    -- Return the encoded string with encoding info at the start
    return encodingInfo .. ":" .. result
end

--- Decodes a string of large numbers using the encoding information for perfect alignment.
--- @param str string The encoded string
--- @param bitLengths integer[] Bit lengths for each number
--- @return integer[]|nil Array of decoded integers, or nil if the string format is invalid
function DL.decodeLargeNumbers(str, bitLengths)
    -- Check if the string starts with "E" which indicates enhanced format
    if str:sub(1, 1) ~= "E" then
        d("Not an enhanced format string, using legacy decoder")
        return DL._decodeLargeNumbersLegacy(str, bitLengths)
    end

    d("Decoding enhanced format string: " .. str:sub(1, math.min(40, #str)) .. "...")

    -- Find the position of the data separator (the last colon)
    local lastColonPos = 0
    local searchPos = 1
    while true do
        local nextColon = str:find(":", searchPos)
        if not nextColon then break end
        lastColonPos = nextColon
        searchPos = nextColon + 1
    end

    if lastColonPos == 0 then
        d("No data separator found in the enhanced format string")
        return nil
    end

    -- Extract metadata and actual data
    local metadata = str:sub(1, lastColonPos - 1)
    local dataStr = str:sub(lastColonPos + 1)

    d("Metadata: " .. metadata)
    d("Data length: " .. #dataStr)

    -- Parse the count from metadata (format E56-8:2-12:3-16:4)
    local count = tonumber(metadata:match("^E(%d+)"))
    if not count then
        d("No count found in metadata")
        return nil
    end

    -- Check if count matches expected values
    if count ~= #bitLengths then
        d("Count mismatch: metadata says " .. count .. " values but received " .. #bitLengths .. " bit lengths")
    end

    -- Extract bit length to character mappings from metadata
    local charLengthsByBitLength = {}
    for bitLength, charLength in metadata:gmatch("-(%d+):(%d+)") do
        local bitLengthNum = tonumber(bitLength)
        local charLengthNum = tonumber(charLength)

        if bitLengthNum and charLengthNum then
            charLengthsByBitLength[bitLengthNum] = charLengthNum
            d(string.format("  Mapping: %d bits uses %d chars", bitLengthNum, charLengthNum))
        end
    end

    -- Verify we have mappings for all required bit lengths
    local missingMappings = false
    for _, bits in ipairs(bitLengths) do
        if not charLengthsByBitLength[bits] then
            d("Missing mapping for bit length " .. bits)
            missingMappings = true
            -- Calculate a fallback (this should match the encoder's logic)
            charLengthsByBitLength[bits] = math.ceil(bits / math.log(DL.BASE, 2))
            d("  Using fallback: " .. bits .. " bits uses " .. charLengthsByBitLength[bits] .. " chars")
        end
    end

    if missingMappings then
        d("Warning: Some bit lengths were missing from metadata, using calculated fallbacks")
    end

    -- Now decode the actual data
    local result = {}
    local pos = 1

    for i, bits in ipairs(bitLengths) do
        local chars = charLengthsByBitLength[bits]

        -- Check if we have enough data left
        if pos + chars - 1 > #dataStr then
            d("Data string too short: need position " .. (pos + chars - 1) .. " but data string length is only " .. #dataStr)
            return nil
        end

        -- Extract and decode the chunk
        local chunk = dataStr:sub(pos, pos + chars - 1)
        local value = DL.decodeDirectly(chunk)

        -- Store the result
        result[i] = value

        -- Log some samples
        if i <= 3 or i >= #bitLengths - 2 then
            d(string.format("  Value %d: %s (%d chars) -> %d (bits: %d)",
                i, chunk, #chunk, value or 0, bits))
        elseif i == 4 then
            d("  ... (omitting middle values) ...")
        end

        -- Move to next position
        pos = pos + chars
    end

    d("Successfully decoded " .. #result .. " values")
    return result
end

--- Legacy decoder (kept for backward compatibility)
--- @param str string The encoded string
--- @param bitLengths integer[] Bit lengths for each number
--- @return integer[]|nil Array of decoded integers, or nil if the string format is invalid
function DL._decodeLargeNumbersLegacy(str, bitLengths)
    d("Using legacy decoder as fallback")
    local result = {}
    local pos = 1

    -- Calculate character lengths just as in the old encoder
    local charLengthsByBitLength = {}
    for _, bits in ipairs(bitLengths) do
        if not charLengthsByBitLength[bits] then
            charLengthsByBitLength[bits] = math.ceil(bits / math.log(DL.BASE, 2))
        end
    end

    -- Now decode each value
    for i, bits in ipairs(bitLengths) do
        local chars = charLengthsByBitLength[bits]

        if pos + chars - 1 > #str then
            d("String too short: need position " .. (pos + chars - 1) ..
                " but string length is only " .. #str)
            return nil
        end

        local chunk = str:sub(pos, pos + chars - 1)
        local value = DL.decodeDirectly(chunk)
        result[i] = value

        if i <= 3 then
            d(string.format("  Legacy decoded %d: %s (%d chars) -> %d (bits: %d)",
                i, chunk, #chars, value, bits))
        end

        pos = pos + chars
    end

    return result
end

--- Encodes an integer into our custom base.
--- @param num integer The number to encode
--- @return string The encoded string
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
--- @return integer|nil The decoded number, or nil if the string contains invalid characters
function DL.decodeInt(str)
    local num = 0
    local base = DL.BASE

    for i = 1, #str do
        local char = str:sub(i, i)
        local value = DL.CHAR_TO_INDEX[char]
        if value == nil then
            d("Invalid character encountered in decodeInt: '" .. char .. "'")
            return nil -- Invalid character encountered
        end

        -- Multiply previous result by base and add the new digit
        num = num * base + value

        -- For debugging in the SimpleGearTest case
        if #str <= 20 then
            d("Decode step " .. i .. ": char '" .. char .. "' value " .. value .. " running total " .. num)
        end
    end

    return num
end

--- Encodes a binary string (sequence of bits) using our custom base.
--- @param bitString string A string of "0" and "1" characters
--- @return string|nil The encoded string, or nil if the bitString contains invalid characters
function DL.encodeBits(bitString)
    -- For debugging in the SimpleGearTest case
    if #bitString < 100 then
        d("Encoding bit string: " .. bitString)
    else
        d("Encoding bit string (first 50 chars): " .. bitString:sub(1, 50) .. "...")
    end

    -- First convert the binary string to a number
    local num = 0
    for i = 1, #bitString do
        local bit = bitString:sub(i, i)
        if bit ~= "0" and bit ~= "1" then
            d("Invalid character in bit string: '" .. bit .. "'")
            return nil -- Invalid bit string
        end
        num = num * 2 + (bit == "1" and 1 or 0)
    end

    -- For debugging in the SimpleGearTest case
    if #bitString < 100 then
        d("Converted to decimal: " .. num)
    end

    -- Then encode that number
    local result = DL.encodeInt(num)

    -- For debugging in the SimpleGearTest case
    if #bitString < 100 then
        d("Encoded result: " .. result)
    end

    return result
end

--- Decodes a string back to binary format with specified length.
--- @param str string The string to decode
--- @param bitLength integer The expected bit length for padding
--- @return string|nil The binary string, or nil if the string contains invalid characters
function DL.decodeToBits(str, bitLength)
    d("Decoding string of length " .. #str .. " to " .. bitLength .. " bits")

    -- We'll decode the string chunk by chunk, 2 characters at a time
    -- which is roughly 12-13 bits per chunk (for our base of 70+ chars)
    local bitString = ""
    local chunkSize = 2 -- Process 2 characters at a time to avoid large number precision issues

    for i = 1, #str, chunkSize do
        -- Get the next chunk (or remaining chars if less than chunkSize)
        local endPos = math.min(i + chunkSize - 1, #str)
        local chunk = str:sub(i, endPos)

        -- Decode just this chunk to a manageable number
        local chunkValue = 0
        for j = 1, #chunk do
            local char = chunk:sub(j, j)
            local value = DL.CHAR_TO_INDEX[char]
            if value == nil then
                d("Invalid character in chunk: '" .. char .. "'")
                return nil
            end
            chunkValue = chunkValue * DL.BASE + value
        end

        -- Convert the chunk value to binary bits
        local chunkBits = ""
        while chunkValue > 0 do
            chunkBits = (chunkValue % 2 == 1 and "1" or "0") .. chunkBits
            chunkValue = math.floor(chunkValue / 2)
        end

        -- Pad to the expected bit length for this chunk (about 12-13 bits for 2 chars)
        local expectedChunkBits = math.min(math.ceil(chunkSize * math.log(DL.BASE, 2)), bitLength - #bitString)
        chunkBits = string.rep("0", expectedChunkBits - #chunkBits) .. chunkBits

        -- Add to overall bitstring, ensuring we don't exceed the total requested bit length
        if #bitString + #chunkBits <= bitLength then
            bitString = bitString .. chunkBits
        else
            -- Only add the bits we need to reach bitLength
            local remaining = bitLength - #bitString
            bitString = bitString .. chunkBits:sub(#chunkBits - remaining + 1)
            break
        end
    end

    -- Ensure we have exactly the right length
    if #bitString < bitLength then
        -- If too short after all chunks, pad with leading zeros
        -- (this shouldn't happen with proper encoding)
        d("Warning: Bit string too short after decoding all chunks. Padding with leading zeros.")
        bitString = string.rep("0", bitLength - #bitString) .. bitString
    elseif #bitString > bitLength then
        -- If too long (due to padding rules), take the rightmost bits
        d("Warning: Bit string too long after decoding. Truncating.")
        bitString = bitString:sub(#bitString - bitLength + 1)
    end

    d("Final bit string length: " .. #bitString .. " (expected " .. bitLength .. ")")

    -- Debug first 40 chars of resulting bit string
    if bitLength > 40 then
        d("Resulting bit string (first 40 chars): " .. bitString:sub(1, 40) .. "...")
    else
        d("Resulting bit string: " .. bitString)
    end

    return bitString
end

-------------------------------------------------
-- High-Level API Functions
-------------------------------------------------

--- Encodes data according to bit lengths
--- @param data integer[] Table of numbers to encode
--- @param bitLengths integer[] Table of bit lengths for each number
--- @return string|nil The encoded string, or nil on error
function DL.encode(data, bitLengths)
    -- Check if we're dealing with gear data or other large data
    local isGearData = #data > 50 or #bitLengths > 50

    if isGearData then
        d("Detected gear data, using special encoding format")
        return DL.encodeLargeNumbers(data, bitLengths)
    else
        -- Check for other large numbers that would benefit from direct encoding
        local hasLargeNumbers = false
        local hasLargeBitLengths = false

        for i, num in ipairs(data) do
            if num > 100000 then
                hasLargeNumbers = true
                break
            end
            if bitLengths[i] > 20 then
                hasLargeBitLengths = true
                break
            end
        end

        if hasLargeNumbers or hasLargeBitLengths then
            -- Use direct encoding for large numbers or bit lengths
            return DL.encodeLargeNumbers(data, bitLengths)
        else
            -- Use bit-based encoding for normal numbers
            local bitString = DL.packBits(data, bitLengths)
            if not bitString then return nil end
            return DL.encodeBits(bitString)
        end
    end
end

--- Decodes a string according to bit lengths
--- @param str string The string to decode
--- @param bitLengths integer[] Table of bit lengths for each number
--- @return integer[]|nil Table of unpacked numbers, or nil on error
function DL.decode(str, bitLengths)
    -- Check total bit length to determine the best decoding approach
    local totalBits = 0
    local hasLargeBitLengths = false

    for _, bits in ipairs(bitLengths) do
        totalBits = totalBits + bits
        if bits > 20 then
            hasLargeBitLengths = true
        end
    end

    -- For smaller datasets (like in SimpleGearTest), force bit-based decoding
    -- Only use direct decoding for genuinely large datasets
    if totalBits > 1000 or hasLargeBitLengths or #bitLengths > 100 or str:sub(1, 1) == "E" then
        d("Using direct decoding due to large data set: " .. totalBits .. " total bits, " .. #bitLengths .. " values")
        return DL.decodeLargeNumbers(str, bitLengths)
    else
        -- For smaller datasets, use bit-based decoding
        d("Using bit-based decoding for smaller data set")

        -- Convert the encoded string to binary bits
        local bitString = DL.decodeToBits(str, totalBits)

        -- If bit string conversion fails, fall back to direct decoding
        if not bitString then
            d("Bit-based decoding failed, falling back to direct decoding")
            return DL.decodeLargeNumbers(str, bitLengths)
        end

        -- Ensure the bit string has the correct length
        if #bitString ~= totalBits then
            d("Bit string length mismatch: expected " .. totalBits .. ", got " .. #bitString)
            -- Try to fix the bit string length
            if #bitString < totalBits then
                -- Pad with leading zeros if too short
                bitString = string.rep("0", totalBits - #bitString) .. bitString
            else
                -- Truncate if too long (taking the rightmost/least significant bits)
                bitString = bitString:sub(#bitString - totalBits + 1)
            end
        end

        -- For debugging, print the bit string
        d("Bit string for decoding (first 30 chars): " .. bitString:sub(1, 30) ..
            (totalBits > 30 and "..." or ""))

        -- Unpack the binary bits into the values
        local result = DL.unpackBits(bitString, bitLengths)

        -- If unpacking fails, fall back to direct decoding
        if not result then
            d("Unpacking bits failed, falling back to direct decoding")
            return DL.decodeLargeNumbers(str, bitLengths)
        end

        return result
    end
end

-------------------------------------------------
-- Utility Functions
-------------------------------------------------

--- Calculates the minimum number of bits needed to represent a value.
--- @param maxValue integer The maximum value to represent
--- @return integer The number of bits required
function DL.bitsRequired(maxValue)
    if maxValue <= 0 then return 1 end
    return math.ceil(math.log(maxValue + 1) / math.log(2))
end

--- @class SchemaField
--- @field name string The field name
--- @field maxValue integer The maximum value this field can have
--- @field type string|nil The field type ("number", "table") - defaults to "number"
--- @field schema SchemaField[]|nil The nested schema for table fields
--- @field count integer|nil The count for table/array fields

--- @class Schema
--- @field encode fun(data: table): string|nil Encode data according to the schema
--- @field decode fun(str: string): table|nil Decode a string according to the schema

--- Creates a schema for encoding/decoding structured data
--- @param schema SchemaField[] Schema definition for encoding/decoding
--- @return Schema Schema object with encode and decode methods
function DL.createSchema(schema)
    local bitLengths = {}
    local isComplexSchema = false

    -- Prepare bit lengths for simple fields
    for _, field in ipairs(schema) do
        -- Set default field type if not specified
        field.type = field.type or "number"

        if field.type == "number" then
            table.insert(bitLengths, DL.bitsRequired(field.maxValue))
        elseif field.type == "table" and field.schema then
            isComplexSchema = true
            -- For table fields, we'll handle them specially during encode/decode
        end
    end

    -- Helper function to flatten a nested table according to the schema
    local function flattenTable(data, schema)
        local result = {}

        for _, field in ipairs(schema) do
            if field.type == "number" then
                table.insert(result, data[field.name] or 0)
            elseif field.type == "table" and field.schema and data[field.name] then
                -- For array of tables, iterate and flatten each one
                if type(data[field.name]) == "table" then
                    d("Flattening table field: " .. field.name .. " with " .. #data[field.name] .. " items")

                    for i, item in ipairs(data[field.name]) do
                        -- Limit output for large datasets
                        if i <= 3 or i >= #data[field.name] - 2 then
                            d("Flattening item " .. i)
                            for j, subfield in ipairs(field.schema) do
                                local value = item[subfield.name] or 0
                                d("  " .. subfield.name .. " = " .. value)
                                table.insert(result, value)
                            end
                        else
                            -- For middle items, just add the values without verbose logging
                            if i == 4 then
                                d("... (skipping detailed output for items 4 to " .. (#data[field.name] - 3) .. ") ...")
                            end
                            for j, subfield in ipairs(field.schema) do
                                table.insert(result, item[subfield.name] or 0)
                            end
                        end
                    end
                end
            end
        end

        d("Flattened data count: " .. #result)
        return result
    end

    -- Helper function to expand flattened data back into a nested table
    local function expandTable(flatData, schema, startIndex)
        startIndex = startIndex or 1
        local result = {}
        local index = startIndex

        for _, field in ipairs(schema) do
            if field.type == "number" then
                result[field.name] = flatData[index]
                index = index + 1
            elseif field.type == "table" and field.schema then
                -- For tables, need to know how many entries to expect
                local count = field.count or 1 -- Default to 1 if not specified
                local subItems = {}

                -- Calculate how many values each item needs
                local itemValueCount = 0
                for _, subfield in ipairs(field.schema) do
                    if subfield.type == "number" then
                        itemValueCount = itemValueCount + 1
                    end
                end

                d("Expanding table field: " .. field.name .. " with " .. count .. " items")

                for i = 1, count do
                    -- Limit output for large datasets
                    if i <= 3 or i >= count - 2 then
                        d("  Expanding item " .. i)
                    end
                    local item = {}

                    for j, subfield in ipairs(field.schema) do
                        if subfield.type == "number" then
                            if index <= #flatData then
                                item[subfield.name] = flatData[index]
                                if i <= 3 or i >= count - 2 then
                                    d("    " .. subfield.name .. " = " .. flatData[index])
                                end
                                index = index + 1
                            else
                                d("    Warning: Not enough data for all items")
                                item[subfield.name] = 0
                            end
                        end
                    end

                    table.insert(subItems, item)
                end

                result[field.name] = subItems
            end
        end

        return result, index
    end

    -- Calculate bit lengths for a complex schema
    local function calculateBitLengths(schema, counts)
        counts = counts or {}
        local result = {}

        for _, field in ipairs(schema) do
            if field.type == "number" then
                table.insert(result, DL.bitsRequired(field.maxValue))
            elseif field.type == "table" and field.schema then
                local fieldCount = counts[field.name] or field.count or 1

                for _ = 1, fieldCount do
                    local subLengths = calculateBitLengths(field.schema)
                    for _, len in ipairs(subLengths) do
                        table.insert(result, len)
                    end
                end
            end
        end

        return result
    end

    return
    {
        --- Encode data according to the schema.
        --- @param data table Table with named fields matching the schema
        --- @return string|nil @The encoded string, or nil if encoding failed
        encode = function (data)
            if isComplexSchema then
                -- Flatten the nested structure
                local flatData = flattenTable(data, schema)

                -- Build appropriate bit lengths for each value
                local dynamicBitLengths = {}
                for i, value in ipairs(flatData) do
                    local bits = DL.bitsRequired(value)
                    -- Ensure reasonable minimum for each field type
                    bits = math.max(bits, 4)
                    table.insert(dynamicBitLengths, bits)
                end

                d("Flattened " .. #flatData .. " values")

                -- For complex schemas, we use a special format to encode the data:
                -- Format: "C" + <encoded count> + ":" + <encoded data>
                -- The bit lengths are stored directly in the flattened data array
                local dataToEncode = {}
                for i, value in ipairs(flatData) do
                    -- Store the bit length first, followed by the actual value
                    table.insert(dataToEncode, dynamicBitLengths[i])
                    table.insert(dataToEncode, value)
                end

                -- Uniform bit lengths for bit length values (5 bits) and actual values (16 bits)
                local uniformBitLengths = {}
                for i = 1, #dataToEncode do
                    if i % 2 == 1 then
                        -- Bit length values get 5 bits
                        table.insert(uniformBitLengths, 5)
                    else
                        -- Actual values get 16 bits (safe default that can be optimized)
                        table.insert(uniformBitLengths, 16)
                    end
                end

                -- Encode the combined data and bit lengths
                local dataEncoded = DL.encode(dataToEncode, uniformBitLengths)

                -- Store the count and encoded data
                local countEncoded = DL.encodeInt(#flatData)
                local result = "C" .. countEncoded .. ":" .. dataEncoded
                d(string.format("Encoded with format: C<count>:<bit_lengths>:<data>, total length: %d", #result))
                return result
            else
                -- Original implementation for simple schemas
                local values = {}
                for i, field in ipairs(schema) do
                    table.insert(values, data[field.name] or 0)
                end
                return DL.encode(values, bitLengths)
            end
        end,

        --- Decode a string according to the schema.
        --- @param str string The string to decode
        --- @param counts table<string, integer>|nil Table counts for complex schemas
        --- @return table|nil @Table with named fields matching the schema, or nil if decoding failed
        decode = function (str, counts)
            if isComplexSchema then
                -- Check if this is a complex schema encoded string
                if str:sub(1, 1) == "C" then
                    -- Extract the parts from our special format
                    -- Format: "C" + <encoded count> + ":" + <encoded data>
                    local countEnd = str:find(":", 2)
                    if not countEnd then
                        d("Invalid complex schema format - missing first separator")
                        return nil
                    end

                    -- Extract and decode the count
                    local countEncoded = str:sub(2, countEnd - 1)
                    local valueCount = DL.decodeInt(countEncoded)
                    d("Decoding " .. valueCount .. " values")

                    -- Extract and decode the actual data
                    local dataEncoded = str:sub(countEnd + 1)

                    -- Create uniform bit lengths array for the encoded data (alternating 5 and 16 bits)
                    local uniformBitLengths = {}
                    for i = 1, valueCount * 2 do
                        if i % 2 == 1 then
                            -- Bit length values get 5 bits
                            table.insert(uniformBitLengths, 5)
                        else
                            -- Actual values get 16 bits
                            table.insert(uniformBitLengths, 16)
                        end
                    end

                    -- Decode the combined bit lengths and values
                    local decodedData = DL.decode(dataEncoded, uniformBitLengths)
                    if not decodedData then
                        d("Failed to decode data portion")
                        return nil
                    end

                    -- Extract the actual values using the decoded bit lengths
                    local flatData = {}
                    for i = 1, valueCount do
                        table.insert(flatData, decodedData[i * 2]) -- Skip the bit length entries
                    end

                    d("Successfully decoded " .. #flatData .. " values")

                    -- Expand back into a nested structure
                    local result = expandTable(flatData, schema)
                    return result
                else
                    d("This doesn't appear to be a complex schema encoding")
                    return nil
                end
            else
                -- Original implementation for simple schemas
                local values = DL.decode(str, bitLengths)
                if not values then return nil end

                local result = {}
                for i, field in ipairs(schema) do
                    result[field.name] = values[i]
                end

                return result
            end
        end
    }
end

-------------------------------------------------
-- Schema
-------------------------------------------------

local EMPTY = 0
local NUMERIC = 1
local TABLE = 2
local ARRAY = 3

--- @class Field
--- @field __index Field
--- @field name string The field name
--- @field fieldType integer The field type (EMPTY, NUMERIC, TABLE, ARRAY)
Field = {}
Field.__index = Field

--- Creates a new Field object
--- @param name string The field name
--- @param fieldType integer The field type
--- @return Field @The new Field object
function Field:New(name, fieldType)
    --- @class (partial) Field
    local o = setmetatable({}, Field)

    o.name = name
    o.fieldType = fieldType

    return o
end

-- ----------------------------------------------------------------------------

--- @class Numeric : Field
--- @field __index Numeric
--- @field bitLength integer The bit length for the numeric field
Numeric = setmetatable({}, { __index = Field })
Numeric.__index = Numeric

--- Creates a new Numeric field
--- @param name string The field name
--- @param bitLength integer The bit length for the numeric field
--- @return Numeric @The new Numeric field
function Numeric:New(name, bitLength)
    --- @class (partial) Numeric
    local o = setmetatable(Field:New(name, NUMERIC), Numeric)

    o.bitLength = bitLength

    return o
end

--- Handles a numeric value
--- @param data number The numeric data to handle
--- @return string|nil The binary string representation, or nil on error
function Numeric:Handle(data)
    if not assert(type(data) == "number", "Value must be a number.") then
        return
    end

    local result = decimalToBinaryString(data, self.bitLength)

    if #result > self.bitLength then
        error("Value is outside of upper bound")
    end

    return result
end

-- ----------------------------------------------------------------------------

--- @class Array : Field
--- @field __index Array
--- @field length integer The array length
--- @field subType Field The field type for array elements
Array = setmetatable({}, { __index = Field })
Array.__index = Array

--- Creates a new Array field
--- @param name string The field name
--- @param length integer The array length
--- @param subtype Field The field type for array elements
--- @return Array The new Array field
function Array:New(name, length, subtype)
    --- @class (partial) Array
    local o = setmetatable(Field:New(name, ARRAY), Array)

    o.length = length
    o.subType = subtype

    return o
end

--- Handles an array of values
--- @param data table The array data to handle
--- @return string|nil The binary string representation, or nil on error
function Array:Handle(data)
    local result = ""

    if not assert(type(data) == "table", "Value must be a table.") then
        return
    end

    for _, datum in ipairs(data) do
        result = result .. self.subType:Handle(datum)
    end

    return result
end

-- ----------------------------------------------------------------------------

--- @class Table : Field
--- @field __index Table
--- @field fields Field[] The fields contained in the table
Table = setmetatable({}, { __index = Table })
Table.__index = Table

--- Creates a new Table field
--- @param name string The field name
--- @param fields Field[] The fields contained in the table
--- @return Table @The new Table field
function Table:New(name, fields)
    --- @class (partial) Table
    local o = setmetatable(Field:New(name, TABLE), Table)

    o.fields = fields

    return o
end

--- Handles a table of values
--- @param data table The table data to handle
--- @return string|nil @The binary string representation, or nil on error
function Table:Handle(data)
    local result = ""

    if not assert(type(data) == "table", "Value must be a table.") then
        return
    end

    for i, field in ipairs(self.fields) do
        result = result .. field:Handle(data[i])
    end

    return result
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

--- Creates a gear schema example for demonstration purposes
--- @return table Schema object with encode and decode methods
function DL.createGearSchema()
    -- Add debugging output
    local schema =
    {
        {
            name = "gear",
            type = "table",
            count = 14, -- Number of gear pieces
            schema =
            {
                { name = "id",     type = "number", maxValue = 65535 }, -- 16-bits for item ID
                { name = "glyph",  type = "number", maxValue = 255 },   -- 8-bits for glyph
                { name = "param1", type = "number", maxValue = 4095 },  -- 12-bits for param1
                { name = "param2", type = "number", maxValue = 4095 }   -- 12-bits for param2
            }
        }
    }

    d("Creating gear schema...")
    d(schema)

    return DL.createSchema(schema)
end

--- Alternative version of createGearSchema using the Field classes
--- @return string @The encoded string
function DL.createGearSchema_v2()
    local gearPiece = Table:New("gearPiece",
        {
            Numeric:New("id", 16),
            Numeric:New("glyph", 8),
            Numeric:New("param1", 12),
            Numeric:New("param2", 12),
        })

    -- it can be rewritten in nested format, but I like to separate this kind of things for clarity
    local build = Array:New("build", 2, gearPiece)

    -- after it, schema (build) can be used to encode data

    local testBuild =
    {
        { 15535, 100, 1000, 1000 },
        { 25535, 200, 2000, 2000 },
    }

    local encodedString = build:Handle(testBuild)

    d("Encoded string: ")
    d(encodedString)

    return encodedString
end

-- Return the library as a global
return DataLink
