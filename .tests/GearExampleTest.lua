-- Load DataLink library
package.path = package.path .. ";./?.lua"
require "DataLink.DataLink"

-- Mock bit manipulation functions (these are provided by ESO)
BitLShift = bit32 and bit32.lshift or bit and bit.lshift or function (a, b) return a * (2 ^ b) end
BitRShift = bit32 and bit32.rshift or bit and bit.rshift or function (a, b) return math.floor(a / (2 ^ b)) end
BitAnd = bit32 and bit32.band or bit and bit.band or function (a, b) return a % (b + 1) end
BitOr = bit32 and bit32.bor or bit and bit.bor or function (a, b) return a - a % (b + 1) + b end

-- Mock d() function (debug print in ESO)
function d(...)
    local args = { ... }
    for i, v in ipairs(args) do
        print(tostring(v))
    end
end

-- Print table recursively for debugging
function printTable(t, indent)
    if type(t) ~= "table" then
        print(tostring(t))
        return
    end
    
    indent = indent or 0
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(string.rep("  ", indent) .. tostring(k) .. " = {")
            printTable(v, indent + 1)
            print(string.rep("  ", indent) .. "}")
        else
            print(string.rep("  ", indent) .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

print("==== ALTERNATIVE GEAR DATA ENCODING TEST ====")

-- IMPORTANT: A simpler but effective approach for complex nested data structures
-- is to manually flatten them before encoding and reconstruct them after decoding.

-- Define bit lengths for each field in each gear item
local gearFieldBits = {
    id = 16,      -- Up to 65535
    glyph = 8,     -- Up to 255
    param1 = 12,   -- Up to 4095
    param2 = 12    -- Up to 4095
}

-- Create sample gear data (14 pieces with 4 attributes each)
local gearItems = {
    { id = 12345, glyph = 67, param1 = 890, param2 = 123 },   -- Helmet
    { id = 23456, glyph = 78, param1 = 901, param2 = 234 },   -- Chest
    { id = 34567, glyph = 89, param1 = 12,  param2 = 345 },   -- Shoulders
    { id = 45678, glyph = 90, param1 = 123, param2 = 456 },   -- Hands
    { id = 56789, glyph = 12, param1 = 234, param2 = 567 },   -- Belt
    { id = 67890, glyph = 23, param1 = 345, param2 = 678 },   -- Legs
    { id = 78901, glyph = 34, param1 = 456, param2 = 789 },   -- Feet
    { id = 89012, glyph = 45, param1 = 567, param2 = 890 },   -- Necklace
    { id = 90123, glyph = 56, param1 = 678, param2 = 901 },   -- Ring 1
    { id = 10234, glyph = 67, param1 = 789, param2 = 12 },    -- Ring 2
    { id = 11345, glyph = 78, param1 = 890, param2 = 123 },   -- Weapon 1 Main
    { id = 12456, glyph = 89, param1 = 901, param2 = 234 },   -- Weapon 1 Off
    { id = 13567, glyph = 90, param1 = 12,  param2 = 345 },   -- Weapon 2 Main
    { id = 14678, glyph = 12, param1 = 123, param2 = 456 }    -- Weapon 2 Off
}

-- Calculate raw data size
local rawSize = #gearItems * 4 * 4 -- 4 fields per item, 4 bytes per field

print(string.format("Raw data size: %d bytes (estimated)", rawSize))

-- Manually flatten the gear data
local flattenedValues = {}
local flattenedBits = {}

for _, item in ipairs(gearItems) do
    -- Add each field in consistent order
    table.insert(flattenedValues, item.id)
    table.insert(flattenedBits, gearFieldBits.id)
    
    table.insert(flattenedValues, item.glyph)
    table.insert(flattenedBits, gearFieldBits.glyph)
    
    table.insert(flattenedValues, item.param1)
    table.insert(flattenedBits, gearFieldBits.param1)
    
    table.insert(flattenedValues, item.param2)
    table.insert(flattenedBits, gearFieldBits.param2)
end

print("Flattened " .. #flattenedValues .. " values from " .. #gearItems .. " gear items")

-- Encode the flattened data
local startTime = os.clock()
print("Encoding " .. #flattenedValues .. " values with appropriate bit lengths")
-- Print sample of bit lengths
for i = 1, 12 do
    print(string.format("  Value %d: %d bits for value %d", i, flattenedBits[i], flattenedValues[i]))
end
print("  ... (more values) ...")

local encoded = DataLink.encode(flattenedValues, flattenedBits)
local encodeTime = os.clock() - startTime

-- Add a simple "G" prefix to indicate gear data and include count
local finalEncoded = "G" .. DataLink.encodeInt(#gearItems) .. ":" .. encoded
print(string.format("Encoded size: %d characters", #finalEncoded))
print(string.format("Compression ratio: %.2f%%", (#finalEncoded / rawSize) * 100))
print(string.format("Encoding time: %.6f seconds", encodeTime))
print("Encoded string: " .. finalEncoded)

-- Decode the gear data
startTime = os.clock()

-- Split the string back
local prefix = finalEncoded:sub(1, 1)
local separatorPos = finalEncoded:find(":")
local countEncoded = finalEncoded:sub(2, separatorPos - 1)
local dataEncoded = finalEncoded:sub(separatorPos + 1)
print("Prefix: " .. prefix .. ", Count encoded: " .. countEncoded .. ", Data length: " .. #dataEncoded)

-- Get the count and validate format
if prefix ~= "G" then
    print("Invalid gear data format")
else
    local itemCount = DataLink.decodeInt(countEncoded)
    print("Decoding data for " .. itemCount .. " gear items")
    
    -- Rebuild the bit lengths array based on item count
    local expectedBitLengths = {}
    for i = 1, itemCount do
        table.insert(expectedBitLengths, gearFieldBits.id)
        table.insert(expectedBitLengths, gearFieldBits.glyph)
        table.insert(expectedBitLengths, gearFieldBits.param1)
        table.insert(expectedBitLengths, gearFieldBits.param2)
    end
    
    -- Print the total expected bits
    local totalBits = 0
    for _, bits in ipairs(expectedBitLengths) do
        totalBits = totalBits + bits
    end
    print(string.format("Total expected bits: %d for %d values", totalBits, #expectedBitLengths))
    
    -- Check if we have the enhanced encoding format (starts with E)
    local isEnhancedFormat = dataEncoded:sub(1, 1) == "E"
    
    -- Decode the flattened data
    local decodedValues
    if isEnhancedFormat then
        print("Detected enhanced encoding format with metadata")
        -- The metadata is part of the encoded string, we pass it as-is
        print("Using enhanced decoding approach with metadata")
        decodedValues = DataLink.decode(dataEncoded, expectedBitLengths)
    else
        -- Legacy decoding for backward compatibility
        print("Using legacy decoding approach")
        decodedValues = DataLink.decode(dataEncoded, expectedBitLengths)
    end
    
    if decodedValues then
        local decodeTime = os.clock() - startTime
        print(string.format("Decoding time: %.6f seconds", decodeTime))
        print(string.format("Successfully decoded %d values", #decodedValues))
        
        -- Print sample of decoded values
        for i = 1, 8 do
            print(string.format("  Decoded value %d: %d", i, decodedValues[i]))
        end
        print("  ... (more values) ...")
        
        -- Reconstruct the gear items
        local reconstructedItems = {}
        
        for i = 1, itemCount do
            local baseIndex = (i - 1) * 4 + 1
            local item = {
                id = decodedValues[baseIndex],
                glyph = decodedValues[baseIndex + 1],
                param1 = decodedValues[baseIndex + 2],
                param2 = decodedValues[baseIndex + 3]
            }
            table.insert(reconstructedItems, item)
        end
        
        -- Verify the data matches
        local success = true
        for i, original in ipairs(gearItems) do
            local decoded = reconstructedItems[i]
            
            if decoded.id ~= original.id or
               decoded.glyph ~= original.glyph or
               decoded.param1 ~= original.param1 or
               decoded.param2 ~= original.param2 then
                success = false
                print(string.format("Mismatch at gear item %d:", i))
                print(string.format("  Original: ID=%d, Glyph=%d, Param1=%d, Param2=%d", 
                      original.id, original.glyph, original.param1, original.param2))
                print(string.format("  Decoded:  ID=%d, Glyph=%d, Param1=%d, Param2=%d", 
                      decoded.id, decoded.glyph, decoded.param1, decoded.param2))
            end
        end
        
        if success then
            print("All gear data verified correctly!")
        end
        
        -- Print the first few items as a sample
        print("\nSample of decoded gear data:")
        for i = 1, 3 do
            print(string.format("Gear item %d:", i))
            print(string.format("  ID: %d, Glyph: %d, Param1: %d, Param2: %d", 
                  reconstructedItems[i].id, 
                  reconstructedItems[i].glyph,
                  reconstructedItems[i].param1,
                  reconstructedItems[i].param2))
        end
    else
        print("Failed to decode gear data")
    end
end

print("\n==== TEST COMPLETE ====") 