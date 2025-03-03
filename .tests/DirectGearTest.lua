-- Load DataLink library
package.path = package.path .. ";./?.lua"
require "DataLink.DataLink"

print("==== DIRECT GEAR ENCODING TEST ====")

-- Create sample gear data (just 3 items for clarity)
local gearItems =
{
    { id = 1234, glyph = 56, param1 = 78, param2 = 90 }, -- Item 1
    { id = 2345, glyph = 67, param1 = 89, param2 = 12 }, -- Item 2
    { id = 3456, glyph = 78, param1 = 90, param2 = 23 }  -- Item 3
}

print("Original data:")
for i, item in ipairs(gearItems) do
    print(string.format("Item %d: id=%d, glyph=%d, param1=%d, param2=%d",
        i, item.id, item.glyph, item.param1, item.param2))
end

-- Simpler approach: encode each item directly and concatenate with separators
local encodedItems = {}

-- For each gear item, encode directly in a fixed format
for i, item in ipairs(gearItems) do
    -- For each item, encode the 4 values directly
    -- Each part gets a fixed number of digits in the encoding
    local idEncoded = DataLink.encodeDirectly(item.id, 3)         -- 3 digits for id
    local glyphEncoded = DataLink.encodeDirectly(item.glyph, 2)   -- 2 digits for glyph
    local param1Encoded = DataLink.encodeDirectly(item.param1, 2) -- 2 digits for param1
    local param2Encoded = DataLink.encodeDirectly(item.param2, 2) -- 2 digits for param2

    -- Combine the parts (no separator needed because we know the digit count)
    local itemEncoded = idEncoded .. glyphEncoded .. param1Encoded .. param2Encoded
    table.insert(encodedItems, itemEncoded)
end

-- Add the count as a prefix, then join all items
local countEncoded = DataLink.encodeDirectly(#gearItems, 1) -- 1 digit for count
local finalEncoded = countEncoded .. table.concat(encodedItems)

print("\nEncoded: " .. finalEncoded)
print("Length: " .. #finalEncoded .. " characters")

-- Decoding: split the string into parts based on known digit counts
local decoded = {}

-- Extract the count
local countDigits = 1
local itemCount = DataLink.decodeDirectly(finalEncoded:sub(1, countDigits))
local position = countDigits + 1

-- For each item, extract and decode the parts
for i = 1, itemCount do
    local idDigits = 3
    local glyphDigits = 2
    local param1Digits = 2
    local param2Digits = 2

    local idEncoded = finalEncoded:sub(position, position + idDigits - 1)
    position = position + idDigits

    local glyphEncoded = finalEncoded:sub(position, position + glyphDigits - 1)
    position = position + glyphDigits

    local param1Encoded = finalEncoded:sub(position, position + param1Digits - 1)
    position = position + param1Digits

    local param2Encoded = finalEncoded:sub(position, position + param2Digits - 1)
    position = position + param2Digits

    local item =
    {
        id = DataLink.decodeDirectly(idEncoded),
        glyph = DataLink.decodeDirectly(glyphEncoded),
        param1 = DataLink.decodeDirectly(param1Encoded),
        param2 = DataLink.decodeDirectly(param2Encoded)
    }

    table.insert(decoded, item)
end

print("\nDecoded data:")
for i, item in ipairs(decoded) do
    print(string.format("Item %d: id=%d, glyph=%d, param1=%d, param2=%d",
        i, item.id, item.glyph, item.param1, item.param2))
end

-- Verify the data
local success = true
for i = 1, itemCount do
    local orig = gearItems[i]
    local dec = decoded[i]

    if orig.id ~= dec.id or
    orig.glyph ~= dec.glyph or
    orig.param1 ~= dec.param1 or
    orig.param2 ~= dec.param2 then
        success = false
        print(string.format("Mismatch in item %d", i))
    end
end

if success then
    print("\nAll items verified successfully!")
end

print("\n==== TEST COMPLETE ====")
