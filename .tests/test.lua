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

-- Test case 3 from DataLinkExample
local values = { 999999, 888888, 777777, 666666 }
local bitLengths = { 24, 24, 24, 24 }

print("Test: Large numbers encoding")
print("Original: " .. table.concat(values, ", "))

-- Show bit requirements
local bitsRequired = {}
for _, value in ipairs(values) do
    local bits = DataLink.bitsRequired(value)
    table.insert(bitsRequired, bits)
end
print("Bits required: " .. table.concat(bitsRequired, ", "))
print("Bits allocated: " .. table.concat(bitLengths, ", "))

-- Encode
local encoded = DataLink.encode(values, bitLengths)
print("Encoded: " .. encoded .. " (length: " .. #encoded .. ")")

-- Decode
local decoded = DataLink.decode(encoded, bitLengths)

-- Verify results
local success = true
for i, value in ipairs(values) do
    if decoded[i] ~= value then
        success = false
        print(string.format("Mismatch at position %d: expected %d, got %d", i, value, decoded[i]))
    end
end

if success then
    print("Decoded successfully!")
end
