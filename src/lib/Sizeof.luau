-- https://dom.rojo.space/binary.html

-- Go on you 14 year old, copy it.. 
-- I'm waiting for ⚡ to have it 1:1 and have some bs excuse 
-- LEAVE ME ALONE AND STOP COPING MY STUFF

--// Int types
local INT = 4
local INT16 = 2
local INT8 = 1

--// Float types
local FLOAT64 = 8
local FLOAT = 4
local DOUBLE = 8

--// Overheads
local OVERHEADS = {
    ["Outbound"] = INT8,
    ["Type"] = INT8,
    ["RemoteAlloc"] = 9,
    ["RemoteFunctionAlloc"] = INT16,
}

local DYAMIC = {}

local STATIC = {
    --// Basic
    ["nil"] = 0,
    ["boolean"] = INT8,
    ["number"] = DOUBLE,

    --// Items
    ["Instance"] = INT,
    ["Ray"] = 6 * FLOAT,
    ["Axes"] = 6,
    ["Faces"] = 6,
    ["EnumItem"] = INT,

    --// UDim
    ["UDim"] = FLOAT + INT,
    ["UDim2"] = (FLOAT + INT) * 2,

    --// Color
    ["BrickColor"] = INT,
    ["Color3"] = FLOAT * 3,
    ["Color3uINT8"] = INT8 * 3,

    --// Sequences
    ["NumberSequenceKeypoint"] = FLOAT * 3,
    ["ColorSequenceKeypoint"] = INT * 4,

    --// Vectors
    ["Vector2"] = FLOAT * 2,
    ["Vector3"] = FLOAT * 3,
    ["Vector2INT16"] = INT16 * 2,
    ["Vector3INT16"] = INT16 * 3,
}

local function GetTableType(Table): number?
    --// Empty
    if next(Table) == nil then return end

    local Type = 1
    for Key in next, Table do
        --// Array
        if typeof(Key) == "number" and Key ~= 0 and Key % 1 == 0 then
            Type = 1

        --// Dict
        else
            Type = 2
            break
        end
    end

    return Type
end

local function CalculateByteSize(Object: any, Processed: {any}?): (number, boolean?)
    local DataType = typeof(Object)

    --// Static
    local Static = STATIC[DataType]
    if Static then return Static end

    --// Dyamic
    Processed = Processed or {}

    local Function = DYAMIC[DataType]
    if Function then 
        return Function(Object, Processed) 
    end

    --// Unknown
    return 0, true
end

--// Dymanic data types
function DYAMIC.table(Table): number
    local IsArray = GetTableType(Table) == 1

    --// Byte sizes
    local KeysCount = 0
    local KeysByteSize = 0
    local ValuesByteSize = 0
    
    local TYPEOVERHEAD = OVERHEADS.Type

    for Key, Value in next, Table do
        --// Calculate byte size
        if IsArray then
            KeysByteSize += CalculateByteSize(Key) + TYPEOVERHEAD
        else
            ValuesByteSize += CalculateByteSize(Value) + TYPEOVERHEAD
        end

        KeysCount += 1
    end

    --// Total byte size
    return KeysCount + KeysByteSize + ValuesByteSize
end

function DYAMIC.Sequence(Sequence: ColorSequence | NumberSequence): number
    local ByteSize = INT
    for _, Keypoint in next, Sequence.Keypoints do
        ByteSize += CalculateByteSize(Keypoint)
    end

    return ByteSize
end

function DYAMIC.buffer(Buffer: buffer): number
    return buffer.len(Buffer)
end

function DYAMIC.string(String: string): number
    return #String
end

function DYAMIC.ColorSequence(ColorSequence: ColorSequence): number
    return DYAMIC.Sequence(ColorSequence)
end
function DYAMIC.NumberSequence(NumberSequence: NumberSequence): number
    return DYAMIC.Sequence(NumberSequence)
end

return CalculateByteSize