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

print("==== SIMPLE GEAR TEST ====")

-- Create just 3 gear items for simplicity
local gearItems = {
    { id = 1234, glyph = 56, param1 = 78, param2 = 90 },   -- Item 1
    { id = 2345, glyph = 67, param1 = 89, param2 = 12 },   -- Item 2
    { id = 3456, glyph = 78, param1 = 90, param2 = 23 }    -- Item 3
}

-- APPROACH: TABLE OF TABLES ENCODING
-- For nested data structures like tables of tables, we can:
-- 1. Manually flatten the data into an array
-- 2. Encode it with appropriate bit lengths
-- 3. Reconstruct the original structure when decoding

-- Step 1: Flatten the data structure
local flatValues = {}     -- Values to encode
local bitLengths = {}     -- Corresponding bit lengths

-- Add the count of items first (so we know how many to decode)
table.insert(flatValues, #gearItems)
table.insert(bitLengths, 8)  -- Up to 255 items

-- Add each field of each item
for _, item in ipairs(gearItems) do
    -- Add each field with appropriate bit length
    table.insert(flatValues, item.id)
    table.insert(bitLengths, 16)  -- 16 bits for id (up to 65535)
    
    table.insert(flatValues, item.glyph)
    table.insert(bitLengths, 8)   -- 8 bits for glyph (up to 255)
    
    table.insert(flatValues, item.param1)
    table.insert(bitLengths, 8)   -- 8 bits for param1
    
    table.insert(flatValues, item.param2)
    table.insert(bitLengths, 8)   -- 8 bits for param2
end

print("Original data:")
for i, item in ipairs(gearItems) do
    print(string.format("Item %d: id=%d, glyph=%d, param1=%d, param2=%d", 
          i, item.id, item.glyph, item.param1, item.param2))
end

-- Step 2: Encode the flattened data
local encoded = DataLink.encode(flatValues, bitLengths)
print("\nEncoded: " .. encoded)
print("Length: " .. #encoded .. " characters")

-- Step 3: Decode the data
local decoded = DataLink.decode(encoded, bitLengths)
if not decoded then
    print("Failed to decode data")
else
    -- Step 4: Reconstruct the original structure
    local itemCount = decoded[1]  -- First value is the count
    local reconstructed = {}
    
    -- Iterate through decoded values and reconstruct items
    for i = 1, itemCount do
        local baseIdx = 2 + (i-1) * 4  -- Skip count + correct offset for each item
        local item = {
            id = decoded[baseIdx],
            glyph = decoded[baseIdx + 1],
            param1 = decoded[baseIdx + 2],
            param2 = decoded[baseIdx + 3]
        }
        table.insert(reconstructed, item)
    end
    
    -- Verify the reconstruction
    print("\nDecoded data:")
    for i, item in ipairs(reconstructed) do
        print(string.format("Item %d: id=%d, glyph=%d, param1=%d, param2=%d", 
              i, item.id, item.glyph, item.param1, item.param2))
    end
    
    -- Check if values match
    local success = true
    for i = 1, itemCount do
        local orig = gearItems[i]
        local recon = reconstructed[i]
        
        if orig.id ~= recon.id or
           orig.glyph ~= recon.glyph or
           orig.param1 ~= recon.param1 or
           orig.param2 ~= recon.param2 then
            success = false
            print(string.format("Mismatch in item %d", i))
        end
    end
    
    if success then
        print("\nAll items verified successfully!")
    end
end

print("\n==== TEST COMPLETE ====") 