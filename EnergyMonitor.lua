------------ CODE ------------

-- Reading Config file --
local cfg_file = fs.open("EnergyMonitorConfig.lua", "r")
local cfg = textutils.unserialise(cfg_file.readAll())
cfg_file:close()

local Abbreviations = cfg.Abbreviations
local EnergyType = cfg.EnergyType


-- Global Variables --
cells = {}
monitor = nil

-- Maps --
RF_DISPLAY_MAP = {
"K","M", "B", "T"
}

VALID_ENERGY_TYPES = {
    "RF", "EU"
}

RF_CELL_TYPE = {
    "thermal:energy_cell",
    "powah:energy_cell"
}

EU_CELL_TYPE = {
    "ic2:batbox",
    "ic2:cesu",
    "ic2:mfe",
    "ic2:mfsu"
}

RF_CELL_METHOD_T01 = {
    "thermal:energy_cell",
    "powah:energy_cell"
}

RF_CELL_METHOD_T02 = {
}

-- Functions --

    -- Algorithm Functions --
local function cloneTable(g)
    return {table.unpack(g)}
end

local function strToTable(str)
    local t = {}
    local len = string.len(str)
    
    for i = 1, len, 1 do 
        table.insert(t, str:sub(i, i))
    end
    
    return t
end

local function tableToStr(table)
    local str = ""
    
    for k, v in pairs(table) do
        str = str..v
    end
    
    return str
end

local function tableContains(table, item)
    for k, v in pairs(table) do
        if v == item then
            return true
        end
    end

    return false
end

    -- Project Functions --

local function numToDisplayAbb(num)
    local result = {}

    local str = tostring(num)
    local arr = strToTable(str)
    
    if #arr < 4 then 
        return str..",000 "..EnergyType
    end
    
    local map_key = math.floor(#arr/3)
    if map_key > #RF_DISPLAY_MAP then map_key = #RF_DISPLAY_MAP end
    
    local survivors = #arr - map_key * 3 + 3
    
    if survivors == 0 then survivors = 3 end
    
    for i = 1, survivors, 1 do
        if i == 2 then
            result[i] = ","..arr[i]
        else
            result[i] = arr[i]
        end
    end
            
    local str_result = tableToStr(result)
    str_result = str_result..RF_DISPLAY_MAP[map_key].." "..EnergyType
    
    return str_result
end

local function numToDisplay(num)
    local result = {}
    
    local str = tostring(num)
    local arr = strToTable(str)

    local result = cloneTable(arr)
    
    if #arr < 4 then return str end

    local counter = 1

    for k, v in pairs(arr) do
        local n = math.abs(k - #arr) + 1
        if counter % 3 == 0 and counter ~= #arr then
            result[n] = "."..arr[counter]
        end

        counter = counter + 1
    end

    local result_str = tableToStr(result)
    return result_str
end


local function getTotalEnergy(cells)
    local total_energy = 0 

    if EnergyType == "RF" then
        for k, v in pairs(cells) do
            local t = peripheral.getType(v)
            local v_wrap = peripheral.wrap(v)

            if tableContains(RF_CELL_METHOD_T01, t) then
                total_energy = total_energy + v_wrap.getEnergy()
            end
        end
    end

    if EnergyType == "EU" then
        for k, v in pairs(cells) do
            local v_wrap = peripheral.wrap(v)
            total_energy = total_energy + v_wrap.getEUStored()
        end
    end
   
    return total_energy
end

local function getTotalEnergyCapacity(cells)
    local total_capacity = 0 

    if EnergyType == "RF" then
        for k, v in pairs(cells) do
            local t = peripheral.getType(v)
            local v_wrap = peripheral.wrap(v)

            if tableContains(RF_CELL_METHOD_T01, t) then
                total_capacity = total_capacity + v_wrap.getEnergyCapacity()
            end
        end
    end

    if EnergyType == "EU" then
        for k, v in pairs(cells) do
            local v_wrap = peripheral.wrap(v)
            total_capacity = total_capacity + v_wrap.getEUCapacity()
        end
    end
   
    return total_capacity
end

local function updateEnergyBar(monitor, percentage)
    monitor.setCursorPos(2, 4 + 13)
    
    for r = 13, 0, -1 do
        monitor.clearLine()
        
        if percentage < 0 then
            monitor.blit("             ", "7777777777777", "7777777777777")
        else
            if EnergyType == "RF" then
                monitor.blit("             ", "eeeeeeeeeeeee", "eeeeeeeeeeeee")
            end

            if EnergyType == "EU" then
                monitor.blit("             ", "bbbbbbbbbbbbb", "bbbbbbbbbbbbb")
            end
        end
    
        monitor.setCursorPos(2, 4 + r)
        percentage = percentage - 1
    end
    
end

local function updateEnergyText(monitor, energy, capacity)
    monitor.setTextColour(colors.green)
    
    if Abbreviations then
        monitor.setCursorPos(19, 5)
        monitor.write(numToDisplayAbb(energy))
    
        monitor.setCursorPos(19 + string.len(numToDisplayAbb(capacity)) / 2 - 1, 6)
        monitor.write(" / ")
    
        monitor.setCursorPos(19, 7)
        monitor.write(numToDisplayAbb(capacity))
    else
        local capacity_len = string.len(numToDisplay(capacity))

        local middle = 16
    
        local middle_capacity = 16 + capacity_len / 2 - 1

        monitor.setCursorPos(middle, 5)
        monitor.write(numToDisplay(energy))
        monitor.setCursorPos(middle_capacity, 6)
        monitor.write(EnergyType) 
        
        monitor.setCursorPos(middle_capacity - 1, 7)
        monitor.write(" / ")
        
        monitor.setCursorPos(middle, 8)
        monitor.write(numToDisplay(capacity))
        monitor.setCursorPos(middle_capacity, 9)
        monitor.write(EnergyType)
    end
end

local function updateEnergyLevels(cells, monitor)
    local energy = getTotalEnergy(cells)
    local capacity = getTotalEnergyCapacity(cells)

    monitor.setTextColour(colors.white)
    monitor.setCursorPos(2, 3)
    monitor.write("Energy stored:")
    
    -- Energy Bar --    
    local percentage = energy * 13 / capacity
    percentage = math.floor(percentage)
    
    updateEnergyBar(monitor, percentage)
    
    -- Energy / Capacity
    updateEnergyText(monitor, energy, capacity)
end

local function findCells(ps)
    cells = {}

    local ps = peripheral.getNames()

    for k, v in pairs(ps) do
        local vtype = peripheral.getType(v)

        if EnergyType == "RF" then
            if tableContains(RF_CELL_TYPE, vtype) then
                table.insert(cells, v)
            end
        end

        if EnergyType == "EU" then
            if tableContains(EU_CELL_TYPE, vtype) then
                table.insert(cells, v)
            end
        end
    end
end

local function update(cells, monitor)
    updateEnergyLevels(cells, monitor)
    
    os.sleep(1)
end


local function initprogram()
    print("----------------- Energy Monitor -----------------")
    print(" * Starting initialization...")

    local ps = peripheral.getNames()
    monitor = peripheral.find("monitor")

    print("")
    print(" * Connected Devices:")
    for k, v in pairs(ps) do
        print("   > "..v)
    end

    --  Check for devices --
    print("\n * Energy Type: "..EnergyType)

    findCells()

    print("")

    if peripheral.find("monitor") == nil then error(" /!\\ No monitor found!") end
    if cells == nil then error(" /!\\ No energy cells found!") end
    if not tableContains(VALID_ENERGY_TYPES, EnergyType) then 
        error(" /!\\ Enter a valid energy type!")
    end

    print(" * Found energy cells: ("..#cells..")")
    for k, v in pairs(cells) do
        print("   > "..v)
    end
end

local function program()
    initprogram()

    print("")
    print(" * Program successfully started!")
    print("--------------------------------------------------")

    while true do
        update(cells, monitor)
    end
end

-- Program --
program()