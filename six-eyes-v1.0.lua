-- to whoever reading this:
-- this code is so unbelievably bad that it is impossible to maintain. 
-- it is held together by hopes and dreams
-- By Maticzpl
-- edited by TheFPSKiller

-- Keys:
-- Stack tool - SHIFT + S
-- Move Tool - M
-- Config Tool - C
-- Stack Edit Mode - SHIFT + D
-- Choose property in stack edit - Left / Right Arrows
-- Set property value in stack edit - Enter
-- Change position in stack display - PageUp / PageDown
-- Go to beggining / end in stack display - Home / End
-- Toggle Zoom Overlay - CTRL + O
-- Open Options - SHIFT + F1
-- Reorder Particles - SHIFT + F5
-- HUD Spectrum Format - CTRL + U

-- Features:
-- Stack HUD - displays the elements of a stack, shows info like FILT ctype in hexadecimal etc. Types are colored!
-- Stack navigation and editing - allows to look through very large stacks and edit particles in the middle of one
-- Stack Tool - stacks all the particles inside of a specified rectangle into one place AND unstacks already stacked particles
-- Config Tool - Easiely set properties of DRAY CRAY CONV LDTC LSNS and other particles
-- Zoom Overlay - See the particle ctypes in the zoom window
-- Property Labels - Many properties of many elements now are documented when stack edit mode is enabled


local enabled = false
evt.register(evt.keypress, function (key)
    if key == interface.SDLK_COMMA then 
        enabled = not enabled
        if enabled then
        elem.property(elem.DEFAULT_PT_WARP, "Graphics", function(i, colr, colg, colb) return 1, ren.PMODE_FLAT, 255,117,231,0 end) 
else
        elem.property(elem.DEFAULT_PT_WARP, "Graphics", false) 
end
end
end)

if MaticzplChipmaker then return end

MaticzplChipmaker =
{
    StackTool = {
        isInStackMode = false,
        mouseDown = false,
        realStart = {x = 0, y = 0},
        realEnd = {x = 0, y = 0},
        rectStart = {x = 0, y = 0},
        rectEnd = {x = 0, y = 0},
    },
    StackEdit = {
        isInStackEditMode = false,
        stackPos = 0,
        selected = -1,
        mouseCaptured = false,
        mouseReleased = true,
        selectedField = 0,
        propDesc = {}
    },
    ConfigTool = {
        inConfigMode = false,
        isSetting1 = false,
        isSetting2 = false,
        setting1Value = -1,
        direction = 0,
        setting2Value = -1,
        target = -1,
        mouseHeld = false,
        overlayAlpha = 150,
        radiusParts = {elem.DEFAULT_PT_DTEC, elem.DEFAULT_PT_TSNS, elem.DEFAULT_PT_LSNS, elem.DEFAULT_PT_VSNS}
    },
    MoveTool = {
        isInMoveMode = false,
        rectStart = {x = 0, y = 0},
        rectEnd = {x = 0, y = 0},
        movement = {x = 0,y = 0},
        mouseDown = false,
        isDragging = false,
    },
    ZoomOverlay = {       
        CallbackList = {}
    },
    FollowUpdate = {
        currentID = -1
    },
    CursorPos = {x = 0, y = 0},
    Settings = {
        cursorDisplayBgAlpha = 190,
        unstackHeight = 50,
    },
    spectrumFormat = 0,
    currentStackSize = 0,
    SegmentedLine = {},
    replaceMode = false,
    tmp3name = "tmp3",
    tmp4name = "tmp4",
    propTable = {'ctype','temp','life','tmp','tmp2','tmp3','tmp4','pres'}
}
local cMaker = MaticzplChipmaker


function MaticzplChipmaker.OnKey(key,scan,_repeat,shift,ctrl,alt) -- 99 is c 115 is s    
    if key == 27 then   -- ESCAPE
        if not cMaker.DisableAllModes() then
            return false
        end
    end     

    if key == 1073741882 and shift and not ctrl and not alt and not _repeat  then -- Shift + F1
        cMaker.openSettings()        
        return false    
    end


    if key == 1073741886 and shift and not ctrl and not alt and not _repeat  then -- Shift + F5
        cMaker.ReorderParticles()
        return false    
    end

    if key == 59 and not ctrl and not _repeat then -- ; semicolon for replacemode
        cMaker.replaceMode = (not cMaker.replaceMode)
    end

    -- You can already do it with CTRL + P
    -- if key == 112 then -- P
    --     tpt.selectedl = "DEFAULT_UI_PROPERTY"

    --     return false
    -- end
end

function MaticzplChipmaker.OnMouseDown(x,y,button)
    if button == 3 then -- RMB
        if not cMaker.DisableAllModes() then
            return false
        end
    end
end

function MaticzplChipmaker.OnMouseMove(x,y,dx,dy)
    cMaker.CursorPos = {x = x, y = y}
end

function MaticzplChipmaker.openSettings()
    local window = Window:new(-1,-1,300,200)

    local exitButton = Button:new(0, 0, 20, 20, "X")
    exitButton:action(
        function(sender)
            interface.closeWindow(window)
            cMaker.SaveSettings()
        end
    )
    window:addComponent(exitButton)

    -- Title
    local SettingsTitle = Label:new(20,0,260,20,"Maticzpl's Chipmaker Settings")
    window:addComponent(SettingsTitle)


    -- Cursor Display Bg
    local CDBgSliderTitle = Label:new(20,30,200,10,"Stack Display Opacity")
    window:addComponent(CDBgSliderTitle)

    local CDBgSliderLabel = Label:new(240,30,20,10,string.format("%.2f %%",cMaker.Settings.cursorDisplayBgAlpha / 2.56))
    window:addComponent(CDBgSliderLabel)

    local CDBgSlider = Slider:new(20,40,260,15,256)
    CDBgSlider:value(cMaker.Settings.cursorDisplayBgAlpha)
    CDBgSlider:onValueChanged(
        function(sender, value)
            cMaker.Settings.cursorDisplayBgAlpha = value
            CDBgSliderLabel:text(string.format("%.2f %%",value / 2.56))
        end
    )
    window:addComponent(CDBgSlider)

    interface.showWindow(window)
end

function MaticzplChipmaker.SaveSettings()
    local sett = cMaker.Settings    local MANAGER = rawget(_G, "MANAGER")

    MANAGER.savesetting("MaticzplCmaker","CDBgColA",sett.cursorDisplayBgAlpha)
end

--cMaker.StackEdit.propDesc[type][field]
cMaker.StackEdit.propDesc = {
    CRAY = {
        ctype = "Created particle type",
        temp = "Created particle temp",
        life = "Created particle life",
        tmp = "Number of parts to create",
        tmp2 = "Distance to skip"
    },
    DRAY = {
        ctype = "Element to stop copying at",
        tmp = "Number of pixels to copy",
        tmp2 = "Distance between source and copy"
    },
    ARAY = {
        life = "Created BRAY life",
    },
    WIFI = {
        temp = "WIFI channel",
        tmp = "WIFI channel index (cannot be overwritten)",
    },
    TESC = {
        tmp = "Lightning size",
    },
    BCLN = {
        ctype = "Cloned element",
    },
    CLNE = {
        ctype = "Cloned element",
    },
    PCLN = {
        ctype = "Cloned element",
    },
    CONV = {
        ctype = "Target type",
        tmp = "Affects only particles of this type"
    },
    VOID = {
        ctype = "Affects only particles of this type"
    },
    PRTI = {
        temp = "Portal channel",
        tmp = "Portal channel index (cannot be overwritten)",
    },
    HSWC = {
        tmp = "1 = Deserialize FILT -> temp"
    },
    DLAY = {
        temp = "Delay in frames starting from 0C"
    },
    STOR = {
        ctype = "Stores only particles of this type",
        temp = "Stored particle temp",
        tmp2 = "Stored particle life",
        tmp3 = "Stored particle tmp",
        tmp4 = "Stored particle ctype",
    },
    PVOD = {
        ctype = "Affects only particles of this type",
    },
    PUMP = {
        temp = "Emmited pressure",
        tmp = "1 = Deserialize FILT -> pressure"
    },
    PBCL = {
        ctype = "Cloned element",
    },
    GPMP = {
        temp = "Force of gravity",
    },
    INVS = {
        tmp = "Pressure to open at",
    },
    DTEC = {
        ctype = "Detected type",
        tmp2 = "Detection radius",        
    },
    TSNS = {
        temp = "Temperature detection threshold",
        tmp = "1 = Serialize temp -> FILT\n2 = Detects lower temp than self",
        tmp2 = "Detection radius",        
    },
    PSNS = {
        temp = "Pressure detection threshold",
        tmp = "1 = Serialize pressure -> FILT\n2 = Detects lower pressure",
        tmp2 = "Detection radius",        
    },
    LSNS = {
        temp = "Life detection threshold",
        tmp = "1 = Serialize life -> FILT\n2 = Detects lower life\n3 = Deserialize FILT -> life",
        tmp2 = "Detection radius",        
    },
    LDTC = {
        ctype = "Detected type",
        tmp = "Detection range",
        life = "Pixels to skip before detecting",
        tmp2 = "This property is a flag\nUse bitwise OR to set multiple modes\n1 = Detects everything but its ctype\n2 = Ignore energy particles\n4 = Don't set FILT color\n8 = Keep searching after finding a particle",
    },
    VSNS = {
        temp = "Velocity detection threshold",
        tmp = "1 = Serialize velocity -> FILT\n2 = Detects lower velocity\n3 = Deserialize FILT -> velocity",
        tmp2 = "Detection radius",        
    },
    ACEL = {
        life = "Velocity multiplier / 100 + 1"
    },
    DCEL = {
        life = "Percent velocity decrease"
    },
    FRAY = {
        temp = "Added / decreased velocity. 10C = 1px/frame"
    },
    RPEL = {
        ctype = "Affected particle",
        temp = "Used force. Can be negative"
    },
    PSTN = {
        ctype = "Blocked by element of this type",
        temp = "Extension distance 1px every 10C",
        tmp = "Max ammount of particles it can push",
        tmp2 = "Max extension length",
    },
    FRME = {
        tmp = "0 = Sticky, otherwise not sticky"
    },
    FIRW = {
        tmp = "1 = Ignited",
        life = "Fuse timer",
    },
    FWRK = {
        life = "Fuse timer",
    },    
    LITH = {
        ctype = "Charge",
        tmp = "Hydrogenation factor (impurity)",
        tmp2 = "Carbonation factor (impurity)",
    },
    LAVA = {
        ctype = "Molten element type"
    },
    GEL = {
        tmp = "Ammount of water absorbed"
    },
    VIRS = {
        tmp3 = "Frames until cured",
        tmp4 = "Frames until death",        
    },
    SNOW = {
        ctype = "Element it turns into after melting",
    },
    ICE = {
        ctype = "Element it turns into after melting",
    },
    SPNG = {
        life = "Ammount of water absorbed",
    },
    FILT = {
        ctype = "Spectrum containing 30 bits of data",
        tmp = "Operation 0 = SET, 1 = AND, 2 = OR, 3 = SUB\n4 = RED SHIFT, 5 = BLUE SHIFT, 6 = NONE\n7 = XOR, 8 = NOT, 9 = QRTZ\n10 = VARIABLE RED SHIFT, 11= VARIABLE BLUE SHIFT"
    },
    PHOT = {
        ctype = "Spectrum containing 30 bits of data",
    },
    DEUT = {
        life = "Level of compression",
    },
    SIGN = {
        tmp = "Explosion power",
        life = "Explosion timer",
    },
    VIBR = {
        tmp = "Absorbed power",
        life = "Explosion timer",
    },
    BVBR = {
        tmp = "Absorbed power",
        life = "Explosion timer",
    },

}


-- Custom HUD for Chipmaker
function MaticzplChipmaker.make_string(x, y)
    local pid = sim.partID(x, y)
    if not pid then return "" end
    local elementID = sim.partProperty(pid, "type")
    local pressureX = math.floor(x/4)
    local pressureY = math.floor(y/4)
    local pres = 0
    if pressureX >= 0 and pressureY >= 0 and pressureX < sim.XRES/4 and pressureY < sim.YRES/4 then
        pres = sim.pressure(pressureX, pressureY) or 0
    end
    local p = {
        id = elementID,
        ctype = sim.partProperty(pid, "ctype"),
        temp = sim.partProperty(pid, "temp"),
        life = sim.partProperty(pid, "life"),
        tmp = sim.partProperty(pid, "tmp"),
        tmp2 = sim.partProperty(pid, "tmp2"),
        tmp3 = sim.partProperty(pid, "tmp3"),
        tmp4 = sim.partProperty(pid, "tmp4"),
        vx = sim.partProperty(pid, "vx"),
        vy = sim.partProperty(pid, "vy"),
        pres = pres
    }
    return string.format("ID:%d C:%d T:%.2f L:%d tmp:%d tmp2:%d tmp3:%d tmp4:%d vx:%d vy:%d pres:%d",
        p.id, p.ctype, p.temp, p.life,
        p.tmp, p.tmp2, p.tmp3, p.tmp4,
        p.vx, p.vy, p.pres)
end

function MaticzplChipmaker.drawHUD(line)
    local HUDx, HUDy = 12, 27
    local color = {192,0,238,118}
    graphics.fillRect(HUDx, HUDy, tpt.textwidth(line)+8, 14, 0,0,0,128)
    graphics.drawText(HUDx+3, HUDy+3, line,
        color[2], color[3], color[4], color[1])
end

-- Thanks LBPhacker for fixing this :P
function MaticzplChipmaker.getColorForString(color)
    local function handle_nono_zone(chr)
        local byte = chr:byte()
        if byte < 0x80 then
            return chr
        end
        return string.char(bit.bor(0xC0, bit.rshift(byte, 6)), bit.bor(0x80, bit.band(byte, 0x3F)))
    end

    local hex = string.format("%x", color)
    --12345678
    --aarrggbb
    --ff2030d0

    local r = tonumber(string.sub(hex,3,4),16)
    local g = tonumber(string.sub(hex,5,6),16)
    local b = tonumber(string.sub(hex,7,8),16)
    
    while #hex < 8 do -- If leading it had leading zeroes add them back in 
        hex = "0"..hex
        r = tonumber(string.sub(hex,3,4),16)
        g = tonumber(string.sub(hex,5,6),16)
        b = tonumber(string.sub(hex,7,8),16)
    end    
    
    if r == 0 or string.char(r) == '\n' then
        r = r + 1
    end
    if g == 0 or string.char(g) == '\n' then
        g = g + 1
    end
    if b == 0 or string.char(b) == '\n' then
        b = b + 1
    end
    
    if r + g + b < 100 then --If too dark bright it up
        local adjustement = (180 - math.max(r,g,b)) / 3
        r = r + adjustement
        g = g + adjustement
        b = b + adjustement
    end
    r = string.char(r)
    g = string.char(g)
    b = string.char(b)
    if tpt.version.jacob1s_mod == nil then
        r = handle_nono_zone(r)
        g = handle_nono_zone(g)
        b = handle_nono_zone(b)        
    end
    return "\x0F"..r..g..b

end

-- Thanks @krftdnr#1652 for this rect code!
function MaticzplChipmaker.DrawRect(x1, y1, x2, y2, r,g,b,a,adjust)    
    if adjust then
        x1, y1 = sim.adjustCoords(x1,y1)
        x2, y2 = sim.adjustCoords(x2,y2)
    end

    local function isInZoom(x, y)
        local zx, zy, zs = ren.zoomScope()
        return ren.zoomEnabled() and 
        x >= zx and x < zx + zs and
        y >= zy and y < zy + zs        
    end
    
    local function calcOffset(x, y)
        local ex, ey, scale, size = ren.zoomWindow()
        local zx, zy, zs = ren.zoomScope()
        return (x - zx) * scale + ex, (y - zy) * scale + ey
    end    

    local startX = x1
    local finalX = x2
    if x2 < x1 then
        finalX = x1
        startX = x2
    end    
    
    local ex, ey, scale, size = ren.zoomWindow()
    for rx = startX, finalX do
        local nx1, ny1 = calcOffset(rx, y1)
        local nx2, ny2 = calcOffset(rx, y2)
        if isInZoom(rx, y1) then
            gfx.fillRect(nx1, ny1, scale - 1, scale - 1, r,g,b,a)
        end
        if isInZoom(rx, y2) then
            gfx.fillRect(nx2, ny2, scale - 1, scale - 1, r,g,b,a)
        end
    end

    
    local startY = y1
    local finalY = y2
    if y2 < y1 then
        finalY = y1
        startY = y2
    end    

    for ry = startY + 1, finalY - 1 do
        local nx1, ny1 = calcOffset(x1, ry)
        local nx2, ny2 = calcOffset(x2, ry)
        if isInZoom(x1, ry) then
            gfx.fillRect(nx1, ny1, scale - 1, scale - 1, r,g,b,a)
        end
        if isInZoom(x2, ry) then
            gfx.fillRect(nx2, ny2, scale - 1, scale - 1, r,g,b,a)
        end
    end
    
    
    local sizeX = x2 - x1
    local sizeY = y2 - y1
    
    if x1 > x2 then
        sizeX = x1 - x2
        x1 = x2
    end
    
    if y1 > y2 then
        sizeY = y1 - y2
        y1 = y2
    end   
    
    
    gfx.drawRect(x1, y1, sizeX, sizeY, r,g,b,a)
end

function MaticzplChipmaker.DrawLine(x1, y1, x2, y2, r,g,b,a,adjust)
    if adjust then
        x1, y1 = sim.adjustCoords(x1,y1)
        x2, y2 = sim.adjustCoords(x2,y2)
    end

    local function isInZoom(x, y)
        local zx, zy, zs = ren.zoomScope()
        return ren.zoomEnabled() and 
        x >= zx and x < zx + zs and
        y >= zy and y < zy + zs        
    end
    
    local function calcOffset(x, y)
        local ex, ey, scale, size = ren.zoomWindow()
        local zx, zy, zs = ren.zoomScope()
        return (x - zx) * scale + ex, (y - zy) * scale + ey
    end    

    local function interpolate(x,y,xr,yr,progress)
        return ((xr - x) * progress) + x,((yr - y) * progress) + y
    end

    local xDiff = math.max((x1 - x2),(x2 - x1))
    local yDiff = math.max((y1 - y2),(y2 - y1))
    local length = math.sqrt((xDiff*xDiff) + (yDiff*yDiff))
    length = length * 4 -- for accuracy

    local ex, ey, scale, size = ren.zoomWindow()
    for step = 0, 1, 1/length do
        local pixelX, pixelY = interpolate(x1,y1,x2,y2,step)
        pixelX = math.floor(pixelX)
        pixelY = math.floor(pixelY)

        local nx ,ny = calcOffset(pixelX,pixelY)

        if isInZoom(pixelX, pixelY) then
            gfx.fillRect(nx,ny,scale - 1, scale - 1,r,g,b,a)
        end
    end

    gfx.drawLine(x1,y1,x2,y2,r,g,b,a)

end

function MaticzplChipmaker.GetAllPartsInPos(x,y)
    local result = {}
    for part in sim.parts() do
        local px,py = simulation.partPosition(part)

        px = math.floor(px+0.5) -- Round pos
        py = math.floor(py+0.5)

        if x == px and y == py then
            table.insert(result,part)
        end
    end
    
    return result
end

-- Thanks to mad-cow for this function!
function MaticzplChipmaker.GetAllPartsInRegion(x1, y1, x2, y2)
    -- builts a map of particles in a region.
    -- WARN: Misbehaves if partile order hasn't been reloaded since it relies on sim.parts()
    -- Save the returned value and provide it to .GetAllPartsInPos(x,y,region) to reduce computational complexity
    -- or you can just index the returned value youself, idc
    local result = {}
    local width = sim.XRES
    if x2 < x1 then
        x1,x2 = x2,x1
    end
    if y2 < y1 then
        y1,y2 = y2,y1
    end
    for part in sim.parts() do
        local px, py = sim.partPosition(part)
        
        px = math.floor(px+0.5) -- Round pos
        py = math.floor(py+0.5)
        local idx = math.floor(px + (py * width))
        
        if px >= x1 and px <= x2 and py >= y1 and py <= y2 then
            if not result[idx] then
                result[idx] = {}
            end
            table.insert(result[idx], part)
        end
    end
    return result
end

function MaticzplChipmaker.DrawModeText(text)
    graphics.fillRect(0,0,sim.XRES,sim.YRES,0,0,0,128)
    graphics.drawText(15,360,text,252, 232, 3)
end

function MaticzplChipmaker.DisableAllModes()
    if cMaker.StackTool.isInStackMode then       
        cMaker.StackTool.DisableStackMode(); 
        return false
    end
    if cMaker.ConfigTool.inConfigMode then      
        cMaker.ConfigTool.DisableConfigMode();
        return false
    end
    if cMaker.StackEdit.isInStackEditMode then      
        cMaker.StackEdit.DisableStackEditMode();
        return false
    end
    if cMaker.MoveTool.isInMoveMode then
        cMaker.MoveTool.DisableMoveMode();
        return false
    end
    return true
end

function MaticzplChipmaker.ReorderParticles()
    print("Particle Order Reloaded")
    
    local particles = {}
    local width = sim.XRES
    for part in sim.parts() do
        local x = math.floor(sim.partProperty(part,'x')+0.5);
        local y = math.floor(sim.partProperty(part,'y')+0.5);

        local particleData = {}
        particleData.type =     sim.partProperty(part,'type');
        particleData.temp =     sim.partProperty(part,'temp');
        particleData.ctype =    sim.partProperty(part,'ctype');
        particleData.tmp =      sim.partProperty(part,'tmp');
        particleData.tmp2 =     sim.partProperty(part,'tmp2');
        particleData.tmp3 =     sim.partProperty(part,cMaker.tmp3name);
        particleData.tmp4 =     sim.partProperty(part,cMaker.tmp4name);
        particleData.life =     sim.partProperty(part,'life');
        particleData.vx =       sim.partProperty(part,'vx');
        particleData.vy =       sim.partProperty(part,'vy');
        particleData.dcolour =  sim.partProperty(part,'dcolour');
        particleData.flags =    sim.partProperty(part,'flags');

        local index = math.floor(x + (y * width))
        if particles[index] == nil then
            particles[index] = {}            
        end
        table.insert(particles[index],particleData)
        --particles[index][#particles[index]] = particleData  
        sim.partKill(part)     
    end
    
    for i = sim.XRES * sim.YRES, 0, -1 do
        local stack = particles[i]
        if stack ~= nil then
            for j = #stack, 1, -1 do
                local part = stack[j]
                local x = math.floor(i % sim.XRES)
                local y = math.floor((i - x) / sim.XRES)


                local id = sim.partCreate(-3,x,y,elem.DEFAULT_PT_BRCK)

                sim.partProperty(id,'type',part.type);
                sim.partProperty(id,'temp',part.temp);
                sim.partProperty(id,'ctype',part.ctype);
                sim.partProperty(id,'tmp',part.tmp);
                sim.partProperty(id,'tmp2',part.tmp2);
                sim.partProperty(id,cMaker.tmp3name,part.tmp3);
                sim.partProperty(id,cMaker.tmp4name,part.tmp4);
                sim.partProperty(id,'life',part.life);
                sim.partProperty(id,'vx',part.vx);
                sim.partProperty(id,'vy',part.vy);
                sim.partProperty(id,'dcolour',part.dcolour)
                sim.partProperty(id,'flags',part.flags);
            end            
        end
    end

end

function MaticzplChipmaker.GetEndInDirection(direction,centerx,centery,distance)
    local x = centerx
    local y = centery
    
    if direction == 1 then --Left top
        x = centerx - distance
        y = centery - distance
        return {x = x, y = y}
    end
    if direction == 2 then
        y = centery - distance
        return {x = x, y = y}        
    end
    if direction == 3 then
        x = centerx + distance
        y = centery - distance
        return {x = x, y = y}        
    end
    if direction == 4 then
        x = centerx + distance
        return {x = x, y = y}        
    end
    if direction == 5 then
        x = centerx + distance
        y = centery + distance
        return {x = x, y = y}        
    end
    if direction == 6 then
        y = centery + distance
        return {x = x, y = y}        
    end
    if direction == 7 then
        x = centerx - distance
        y = centery + distance
        return {x = x, y = y}          
    end    
    if direction == 8 then
        x = centerx - distance
        return {x = x, y = y}        
    end

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)

    return {x = x, y = y}
end

function MaticzplChipmaker.OffsetToDirection(x,y,cx,cy)
    local fx = cx - x
    local fy = cy - y

    local a = math.atan2(fx,-fy) * (180/math.pi)

    if a < 0 then
        a = 360 + a
    end

    --0(0,-1)    45  (1,-1)

    --   X       90  (1,0 )

    --180(0,1)   135 (1,1 )

    if (a > (360-20) and a <= 0) --0
        or 
        (a >= 0 and a < 20) then
        return 2 -- top
    end
    if a >= 20 and a <=70 then --45
        return 3
    end
    if a > 70 and a < 110 then --90
        return 4
    end
    if a >= 110 and a <=160 then --135
        return 5
    end
    if a > 160 and a < 200 then --180
        return 6
    end
    if a >= 200 and a <= 250 then --225
        return 7
    end
    if a > 250 and a < 290 then --270
        return 8
    end
    if a >= 290 and a <= 340 then --315
        return 1
    end
    
    

end

function MaticzplChipmaker.SegmentedLine:new(direction,alpha)
    local o = {}
    o.segments = {}
    o.direction = direction
    o.alpha = alpha
    setmetatable(o, self)
    self.__index = self
    return o
end

function MaticzplChipmaker.SegmentedLine:addSegment(r,g,b,length)
    length = (length or 1) - 1
    table.insert(self.segments,{r=r,g=g,b=b,length=length})
end

function MaticzplChipmaker.SegmentedLine:draw(x,y)
    for key, segment in pairs(self.segments) do
        local r,g,b = segment.r,segment.g,segment.b
        local length = segment.length
        local lineEnd = cMaker.GetEndInDirection(self.direction,x,y,length)

        if length >= 0 then
            cMaker.DrawLine(x+0.5,y+0.5,lineEnd.x+0.5,lineEnd.y+0.5,r,g,b,self.alpha)            
        end

        local nextLineStart = cMaker.GetEndInDirection(self.direction,lineEnd.x,lineEnd.y,1)
        x = nextLineStart.x
        y = nextLineStart.y
    end
end

function table:includes(element)
    for i, elem in ipairs(self) do
        if elem == element then
            return true
        end
    end
    return false
end


-- v[STACK TOOL]v

--Thanks to mad-cow for optimizing those 2 functions
function MaticzplChipmaker.StackTool.Stack()
    local s = cMaker.StackTool
    
    local partsMoved = 0
    
    sim.takeSnapshot()
    cMaker.ReorderParticles()
    
    local region = cMaker.GetAllPartsInRegion(s.rectStart.x,s.rectStart.y,
                                              s.rectEnd.x,s.rectEnd.y)
    
    for idx,parts in pairs(region) do
        for i,part in pairs(parts) do
            if part ~= nil then
                if x ~= s.rectEnd.x and y ~= s.rectEnd.y then   --count every particle except the ones that got already stacked
                    partsMoved = partsMoved + 1
                elseif partsMoved < #parts then
                    partsMoved = partsMoved + 1
                end
                
                sim.partProperty(part,"x",s.rectEnd.x)
                sim.partProperty(part,"y",s.rectEnd.y)
            end
            
        end
    end
    
    if partsMoved > 5 then
        print("Warning: More than 5 particles stacked")
        tpt.set_pause(1)
    end
    cMaker.ReorderParticles()
    
end

function MaticzplChipmaker.StackTool.Unstack()
    local s = cMaker.StackTool
    -- rectStart == rectEnd
    
    local parts = cMaker.GetAllPartsInPos(s.rectStart.x,s.rectStart.y)
    
    -- Check if space is free
    local collision = false
    local xOffset = 0
    local yOffset = 0 
    for i,part in pairs(parts) do
        local posX = s.rectStart.x + xOffset
        local posY = s.rectStart.y + yOffset

        local inPos = simulation.partID(posX,posY)
        if ( inPos ~= nil and i ~= 1 ) or 
         (posX > 607) or (posY > 379) or (posX < 4) or (posY < 4) then
            collision = true
            break
        end
        
        xOffset = xOffset + 1
        if xOffset >= cMaker.Settings.unstackHeight then
            yOffset = yOffset + 1
            xOffset = 0
        end
    end
    
    if collision then
        print("Not enough space to unstack")
    else
        sim.takeSnapshot()
        xOffset = 0
        yOffset = 0 
        for i,part in pairs(parts) do
            sim.partProperty(part,"y",s.rectStart.y + yOffset)
            sim.partProperty(part,"x",s.rectStart.x + xOffset)
           
        
            xOffset = xOffset + 1
            if xOffset >= cMaker.Settings.unstackHeight then
                yOffset = yOffset + 1
                xOffset = 0
            end
        end
    end
    
end

function MaticzplChipmaker.StackTool.StartStackRectangle(x,y)    
    cMaker.StackTool.realStart = {x=x,y=y}
    x, y = simulation.adjustCoords(x,y)            
    cMaker.StackTool.rectStart = {x = x,y = y}
end

function MaticzplChipmaker.StackTool.FinishStacking(x,y)
    cMaker.StackTool.realEnd = {x=x,y=y}
    x, y = simulation.adjustCoords(x,y)    
    cMaker.StackTool.rectEnd = {x = x,y = y}
    
    if cMaker.StackTool.rectEnd.x == cMaker.StackTool.rectStart.x and
    cMaker.StackTool.rectEnd.y == cMaker.StackTool.rectStart.y then
        cMaker.StackTool.Unstack()
    else
        cMaker.StackTool.Stack()
    end
    
    cMaker.StackTool.DisableStackMode()    
end


function MaticzplChipmaker.StackTool.EnableStackMode()
    cMaker.DisableAllModes()
    cMaker.StackTool.isInStackMode = true
end

function MaticzplChipmaker.StackTool.DisableStackMode()    
    cMaker.StackTool.mouseDown = false            
    cMaker.StackTool.isInStackMode = false    
end

local function StackToolInit()   
    event.register(event.keypress, 
        function (key,scan,_repeat,shift,ctrl,alt)
            if key == 115 and shift and not ctrl and not alt and not _repeat then -- SHIFT + S
                cMaker.StackTool.EnableStackMode();
                return false
            end
        end
    )
    event.register(event.mousedown, 
        function (x,y,button)     
            if cMaker.StackTool.isInStackMode and button == 1 then
                cMaker.StackTool.mouseDown = true
                cMaker.StackTool.StartStackRectangle(x,y)
                return false        
            end
        end
    )
    event.register(event.mouseup, 
        function (x,y,button,reason)  
            if cMaker.StackTool.isInStackMode and button == 1 then
                  cMaker.StackTool.FinishStacking(x,y)
                return false
            end  
        end
    )
    event.register(event.tick, 
        function ()  
            if cMaker.StackTool.isInStackMode then
                cMaker.DrawModeText("Stacking Mode (right click to cancel)")
                
                if cMaker.StackTool.mouseDown then            
                    local startX = cMaker.StackTool.realStart.x
                    local startY = cMaker.StackTool.realStart.y
                    
                    local cx = cMaker.CursorPos.x
                    local cy = cMaker.CursorPos.y
                    
                    cMaker.DrawRect(startX,startY,cx,cy,255,255,255,70,true)      
                end
            end
        end
    )

end

StackToolInit()
-- ^[STACK TOOL]^

local cMaker = MaticzplChipmaker

-- v[STACK EDIT]v
function MaticzplChipmaker.HandleStackEdit(button)
    --tpt.selectedl  left   1
    --tpt.selecteda  middle 2
    --tpt.selectedr  right  3  
    local select = nil
    local part = cMaker.StackEdit.selected

    if part == -1 then
        return true
    end

    if button == 1 then
        select = tpt.selectedl
    else
        if button == 3 then
            select = tpt.selectedr
        else
            select = tpt.selecteda
        end              
    end            

    sim.takeSnapshot()
    
    -- Handle Tools
    if select == "DEFAULT_UI_SAMPLE" then
        local hasName,Name = pcall(elements.property,sim.partProperty(part,'type'),"Name")
        if hasName then
            tpt.selectedl = "DEFAULT_PT_"..Name
            print("Part Sampled")
            return false                
        end
    end

    if select == "DEFAULT_PT_NONE" then
        sim.partKill(part)
        cMaker.StackEdit.stackPos = math.max(cMaker.StackEdit.stackPos - 1,0)
        print("Part Removed")
        return false
    end

    if cMaker.ConfigTool.inConfigMode then
        cMaker.ConfigTool.target = part
        print("Part Configured")
        return false
    end

    --Handle Elements
    if string.sub(select,0,10) == "DEFAULT_PT" then
        if cMaker.replaceMode or tpt.selectedreplace ~= "DEFAULT_PT_NONE" then
            sim.partChangeType(part,elem[select])
            print("Part Replaced")
            return false
        else
            sim.partProperty(part,'ctype',elem[select])
            print("Part Ctype Set")
            return false
        end
    end
end

function MaticzplChipmaker.StackEdit.EnableStackEditMode()
    cMaker.DisableAllModes()
    cMaker.StackEdit.isInStackEditMode = true
end

function MaticzplChipmaker.StackEdit.DisableStackEditMode()    
    cMaker.StackEdit.isInStackEditMode = false                
end

function MaticzplChipmaker.StackEdit.SetFieldValue(field, wrong)
	wrong = wrong or false

	local function applyValue(field_name, val)
		if string.sub(val, #val) == "C" then
			val = tonumber(string.sub(val, 0, #val-1)) + 273.15
		end

		local name = elem["DEFAULT_PT_"..string.upper(val)]
		if name ~= nil then
			val = name
		end

		local success, _ = pcall(sim.partProperty, cMaker.StackEdit.selected, field_name, val)

		if not success then
			cMaker.StackEdit.SetFieldValue(field_name, true)
		end
	end

	local title = "Set Property"

	if wrong then
		title = "Wrong value! Try again."
	end

	if tpt.input then
		applyValue(field, tpt.input(title, "Set value for "..field))
	else
		interface.beginInput(title, "Set value for ".. field, "", "", function (val)
			applyValue(field, val)
		end) 
	end

end

local function StackEditInit()
    event.register(event.keypress, 
        function (key,scan,_repeat,shift,ctrl,alt)
            if key == 100 and shift and not ctrl and not alt and not _repeat then --shift D        
                cMaker.StackEdit.EnableStackEditMode()
                return false
            end
            local editing = cMaker.StackEdit.isInStackEditMode;
            if (key == 1073741899 or (key == 0x40000052 and editing)) and not shift and not ctrl and not alt then    -- PageUp / Up arrow
                cMaker.StackEdit.stackPos = cMaker.StackEdit.stackPos + 1
                return false
            end
            if (key == 1073741902 or (key == 0x40000051 and editing)) and not shift and not ctrl and not alt then    -- PageDown / Down arrow       
                if cMaker.StackEdit.stackPos > 0 then
                    cMaker.StackEdit.stackPos = cMaker.StackEdit.stackPos - 1
                    return false
                end             
            end
            if key == 1073741898 and not shift and not ctrl and not alt and not _repeat then    -- Home        
                cMaker.StackEdit.stackPos = 0
                return false
            end  
            if key == 1073741901 and not shift and not ctrl and not alt and not _repeat then    -- End        
                cMaker.StackEdit.stackPos = math.max(cMaker.currentStackSize - 1,0)
                return false
            end  
            if cMaker.StackEdit.isInStackEditMode then                 
                if key == 1073741903 and not shift and not ctrl and not alt and not _repeat then --Right arrow
                    cMaker.StackEdit.selectedField = cMaker.StackEdit.selectedField + 1
                    if cMaker.propTable[cMaker.StackEdit.selectedField] == nil  then
                        cMaker.StackEdit.selectedField = 0
                    end
                    return false
                end               
                if key == 1073741904 and not shift and not ctrl and not alt and not _repeat then --Left arrow
                    cMaker.StackEdit.selectedField = cMaker.StackEdit.selectedField-1
                    if cMaker.StackEdit.selectedField < 0 then
                        cMaker.StackEdit.selectedField = 0
                    end
                    return false
                end   
                if key == 13 and not shift and not ctrl and not alt and not _repeat then -- Enter                    
                    if cMaker.StackEdit.selectedField > 0 then
                        local field = cMaker.propTable[cMaker.StackEdit.selectedField]
                        sim.takeSnapshot()

						cMaker.StackEdit.SetFieldValue(field)
                    end
                    return false
                end
            end
        end
    )

    event.register(event.mousedown, 
        function (x,y,button)     
            if cMaker.StackEdit.isInStackEditMode then                
                if not cMaker.HandleStackEdit(button) then
                    return false                           
                end 
            end
        end
    )

    event.register(event.tick, 
        function ()                         
            if cMaker.StackEdit.isInStackEditMode then
                cMaker.DrawModeText("Stack Edit Mode (ESC to cancel)")
                cMaker.ConfigTool.DrawPartConfig(cMaker.StackEdit.selected)
            end    
        end
    )
end

StackEditInit()
-- ^[STACK EDIT]^


-- v[CONFIG TOOL]v
local cMaker = MaticzplChipmaker

function MaticzplChipmaker.ConfigTool.EnableConfigMode()
    cMaker.DisableAllModes()
    cMaker.ConfigTool.inConfigMode = true
end

function MaticzplChipmaker.ConfigTool.DisableConfigMode()
    cMaker.ConfigTool.inConfigMode = false           
    cMaker.ConfigTool.isSetting1 = false          
    cMaker.ConfigTool.isSetting2 = false         
    cMaker.ConfigTool.setting1Value = -1         
    cMaker.ConfigTool.setting2Value = -1        
    cMaker.ConfigTool.target = -1    
end


function MaticzplChipmaker.ConfigTool.CheckUsefulNeighbors(direction,x,y,type)
    local part = nil
    if direction == 1 then
        part = sim.partID(x-1,y-1)
    end
    if direction == 2 then
        part = sim.partID(x,y-1)
    end
    if direction == 3 then
        part = sim.partID(x+1,y-1)
    end
    if direction == 4 then
        part = sim.partID(x+1,y)
    end
    if direction == 5 then
        part = sim.partID(x+1,y+1)
    end
    if direction == 6 then
        part = sim.partID(x,y+1)
    end
    if direction == 7 then
        part = sim.partID(x-1,y+1)
    end
    if direction == 8 then
        part = sim.partID(x-1,y)
    end    
    if part == nil then
        return false
    end

    local t = sim.partProperty(part,'type')

    if (t == elem.DEFAULT_PT_FILT and type == elem.DEFAULT_PT_LDTC) or t == elem.DEFAULT_PT_SPRK or t == elem.DEFAULT_PT_METL or t == elem.DEFAULT_PT_PSCN or t == elem.DEFAULT_PT_NSCN or t == elem.DEFAULT_PT_TUNG or t == elem.DEFAULT_PT_INWR or t == elem.DEFAULT_PT_INST or t == elem.DEFAULT_PT_BMTL or t == elem.DEFAULT_PT_TTAN or t == elem.DEFAULT_PT_IRON then
        return true
    end

    return false
end

function MaticzplChipmaker.ConfigTool.DrawPartConfig(part,overwriteDirection)  
    local sourceCol = {r=255,g=255,b=255}

    local type = sim.partProperty(part,'type')
    local x, y = sim.partPosition(part)
    
    if table.includes(cMaker.ConfigTool.radiusParts,type) then
        local r = sim.partProperty(part,'tmp2')
        
        MaticzplChipmaker.DrawRect(x-r,y-r,x+r,y+r, 0, 255, 0, cMaker.ConfigTool.overlayAlpha);
        cMaker.DrawLine(x,y,x,y,sourceCol.r,sourceCol.g,sourceCol.b,cMaker.ConfigTool.overlayAlpha)
        return
    end

    if type == elem.DEFAULT_PT_LDTC or type == elem.DEFAULT_PT_CRAY then
        local skip = sim.partProperty(part,'life')
        local range = sim.partProperty(part,'tmp')
        if type == elem.DEFAULT_PT_CRAY then            
            skip = sim.partProperty(part,'tmp2')
            range = sim.partProperty(part,'tmp')
        end

        for d = 1, 8, 1 do --8 directions
            local opposite = d + 4
            if opposite > 8 then
                opposite = opposite - 8
            end
            
            local dir = d
            if overwriteDirection ~= nil then
                dir = overwriteDirection
            end
            if cMaker.ConfigTool.CheckUsefulNeighbors(opposite,x,y,type) or overwriteDirection ~= nil then
                local line = cMaker.SegmentedLine:new(dir,cMaker.ConfigTool.overlayAlpha)
                line:addSegment(sourceCol.r,sourceCol.g,sourceCol.b,1    )          
                line:addSegment(255,0,  0,  skip )          
                line:addSegment(0,255,255,  range)
                line:draw(x,y)          
            end
        end
        return
    end

    if type == elem.DEFAULT_PT_DRAY then
        local range = sim.partProperty(part,'tmp')
        local skip = sim.partProperty(part,'tmp2')
        for d = 1, 8, 1 do --8 directions
            local opposite = d + 4
            if opposite > 8 then
                opposite = opposite - 8
            end
            
            local dir = d
            if overwriteDirection ~= nil then
                dir = overwriteDirection
            end
            if cMaker.ConfigTool.CheckUsefulNeighbors(opposite,x,y,type) or overwriteDirection ~= nil then  
                local line = cMaker.SegmentedLine:new(dir,cMaker.ConfigTool.overlayAlpha)
                line:addSegment(sourceCol.r,sourceCol.g,sourceCol.b,1    )           
                line:addSegment(0,  255,0,  range)      
                line:addSegment(255,0,  255,  skip )          
                line:addSegment(0,255,255,  range)
                line:draw(x,y)   
            end
        end
        return
    end

    if type == elem.DEFAULT_PT_CONV then
        local from = sim.partProperty(part,'tmp')
        local to = sim.partProperty(part,'ctype')

        local success, colorFrom = pcall(elements.property,from,"Color")
        if success then
            colorFrom = cMaker.getColorForString(colorFrom)  
        else
            colorFrom = ""          
        end

        local success, colorTo = pcall(elements.property,to,"Color")
        if success then
            colorTo = cMaker.getColorForString(colorTo)  
        else
            colorTo = ""          
        end

        local success, nameFrom = pcall(elements.property,from,"Name")
        if not success then
            nameFrom = from
        end

        local success, nameTo = pcall(elements.property,to,"Name")
        if not success then
            nameTo = to
        end

        gfx.drawText(15,345,colorFrom..nameFrom.." -> "..colorTo..nameTo)        
    end
end

function MaticzplChipmaker.ConfigTool.SetFirst(part)
    local cx, cy = sim.adjustCoords(cMaker.CursorPos.x,cMaker.CursorPos.y)

    local type = sim.partProperty(part,'type')
    local x, y = sim.partPosition(part)
    
    if table.includes(cMaker.ConfigTool.radiusParts,type) then
        --local distance = math.floor(math.sqrt(((x-cx)*(x-cx)) + ((y-cy)*(y-cy)))) --No, its a square xd
        local distance = math.abs(math.max(math.max(x - cx,cx - x), math.max(y - cy, cy - y)))
                     
        sim.partProperty(part,'tmp2',distance)
        return
    end

    if type == elem.DEFAULT_PT_LDTC or type == elem.DEFAULT_PT_CRAY then
        local direction = cMaker.OffsetToDirection(x,y,cx,cy)
        local distance = math.abs(math.max(math.max(x - cx,cx - x), math.max(y - cy, cy - y)))
        
        if type == elem.DEFAULT_PT_LDTC then
            sim.partProperty(part,'life',distance)        
        else
            sim.partProperty(part,'tmp2',distance)
        end
        cMaker.ConfigTool.setting1Value = distance
        cMaker.ConfigTool.direction = direction
        return
    end

    if type == elem.DEFAULT_PT_DRAY then
        local direction = cMaker.OffsetToDirection(x,y,cx,cy)
        local distance = math.abs(math.max(math.max(x - cx,cx - x), math.max(y - cy, cy - y)))
        
        sim.partProperty(part,'tmp',distance)   

        cMaker.ConfigTool.setting1Value = distance
        cMaker.ConfigTool.direction = direction        
        return
    end

    if type == elem.DEFAULT_PT_CONV then
        local type1 = elem.DEFAULT_PT_NONE
        if cMaker.StackEdit.selected ~= -1 then
            type1 = sim.partProperty(cMaker.StackEdit.selected,'type')
        end

        sim.partProperty(part,'tmp',type1)
        cMaker.ConfigTool.setting1Value = type1        
    end
end

function MaticzplChipmaker.ConfigTool.SetSecond(part)
    local cx, cy = sim.adjustCoords(cMaker.CursorPos.x,cMaker.CursorPos.y)

    local type = sim.partProperty(part,'type')
    local px, py = sim.partPosition(part)
    
    if type == elem.DEFAULT_PT_LDTC or type == elem.DEFAULT_PT_CRAY then
        local endPoint = cMaker.GetEndInDirection(cMaker.ConfigTool.direction,px,py,cMaker.ConfigTool.setting1Value)
        local distance = math.abs(math.max(math.max(endPoint.x - cx,cx - endPoint.x), math.max(endPoint.y - cy, cy - endPoint.y)))
        
        sim.partProperty(part,'tmp',distance)
        cMaker.ConfigTool.setting2Value = distance
        return
    end

    if type == elem.DEFAULT_PT_DRAY then
        local endPoint = cMaker.GetEndInDirection(cMaker.ConfigTool.direction,px,py,cMaker.ConfigTool.setting1Value)
        local distance = math.abs(math.max(math.max(endPoint.x - cx,cx - endPoint.x), math.max(endPoint.y - cy, cy - endPoint.y)))
        
        sim.partProperty(part,'tmp2',distance)

        cMaker.ConfigTool.setting2Value = distance
        return
    end
    
    if type == elem.DEFAULT_PT_CONV then
        local type2 = elem.DEFAULT_PT_NONE
        if cMaker.StackEdit.selected ~= -1 then
            type2 = sim.partProperty(cMaker.StackEdit.selected,'type')
        end

        sim.partProperty(part,'ctype',type2)
        cMaker.ConfigTool.setting2Value = type2        
    end
end

local function ConfigToolInit()
    event.register(event.keypress, 
        function (key,scan,_repeat,shift,ctrl,alt)
            if key == 99 and not shift and not ctrl and not alt and not _repeat  then   -- C
                cMaker.ConfigTool.EnableConfigMode()
                return false    
            end            
        end
    )

    event.register(event.mousedown,
        function(x,y,button)
            if cMaker.ConfigTool.inConfigMode and button == 1 and not cMaker.ConfigTool.mouseHeld then   
                if not cMaker.ConfigTool.isSetting1 and not cMaker.ConfigTool.isSetting2 then    

                    cMaker.ConfigTool.target = cMaker.StackEdit.selected   
                    cMaker.ConfigTool.isSetting1 = true     

                    if cMaker.ConfigTool.target == -1 then            
                        cMaker.DisableAllModes()                        
                    end                     
                    return false
                end

                if cMaker.ConfigTool.isSetting1 then
                    cMaker.ConfigTool.isSetting1 = false  
                    cMaker.ConfigTool.isSetting2 = true      
                    return false                
                end
                if cMaker.ConfigTool.isSetting2 then      
                    cMaker.DisableAllModes()           
                    return false                                           
                end

                cMaker.ConfigTool.mouseHeld = true
                return false   
            end
        end
    )

    event.register(event.mouseup,
        function(x,y,button)
            if button == 1 then     
                cMaker.ConfigTool.mouseHeld = false
            end
        end
    )

    
    event.register(event.tick, 
        function ()   
            if cMaker.ConfigTool.inConfigMode then
                cMaker.DrawModeText("Config Mode (right click to cancel)")

                local target = MaticzplChipmaker.StackEdit.selected
                if cMaker.ConfigTool.target ~= -1 then
                    target = cMaker.ConfigTool.target
                end

                if cMaker.ConfigTool.isSetting1 then
                    cMaker.ConfigTool.SetFirst(target)       
                end
                if cMaker.ConfigTool.isSetting2 then
                    local type = sim.partProperty(target,'type')
                                                           
                    if table.includes(cMaker.ConfigTool.radiusParts,type) then 
                        cMaker.DisableAllModes() 
                        return                                  
                    end

                    cMaker.ConfigTool.SetSecond(target)    
                end

                if target ~= -1 then      
                    local x,y = sim.partPosition(target)
                    local cx, cy = sim.adjustCoords(cMaker.CursorPos.x,cMaker.CursorPos.y)
                    if not cMaker.ConfigTool.isSetting1 and not cMaker.ConfigTool.isSetting2 then
                        cMaker.ConfigTool.DrawPartConfig(target)
                    else
                        cMaker.ConfigTool.DrawPartConfig(target,cMaker.OffsetToDirection(x,y,cx,cy))
                    end
                end

                
            end       
        end
    )
end

ConfigToolInit()
-- ^[CONFIG TOOL]^





function MaticzplChipmaker.MoveTool.StartRect(x,y)
    cMaker.MoveTool.mouseDown = true
    x,y = sim.adjustCoords(x,y)
    cMaker.MoveTool.rectStart = {x = x, y = y}
end

function MaticzplChipmaker.MoveTool.EndRect(x,y)
    cMaker.MoveTool.mouseDown = false
    x,y = sim.adjustCoords(x,y)
    cMaker.MoveTool.rectEnd = {x = x, y = y}
    cMaker.MoveTool.isDragging = true    


end

function MaticzplChipmaker.MoveTool.Place(x,y)
    local s = cMaker.MoveTool
    
    local xDirection = 1
    if s.rectStart.x > s.rectEnd.x then
        xDirection = -1
    end
    
    local yDirection = 1
    if s.rectStart.y > s.rectEnd.y then
        yDirection = -1
    end

    sim.takeSnapshot()
    for l, stack in pairs(MaticzplChipmaker.GetAllPartsInRegion(s.rectStart.x,s.rectStart.y,s.rectEnd.x,s.rectEnd.y)) do
        for k, part in pairs(stack) do
            local x,y = sim.partPosition(part)
            sim.partProperty(part,'x',x - s.movement.x)
            sim.partProperty(part,'y',y - s.movement.y)
        end        
    end
end

function MaticzplChipmaker.MoveTool.EnableMoveMode()
    cMaker.DisableAllModes()
    cMaker.MoveTool.isInMoveMode = true
end

function MaticzplChipmaker.MoveTool.DisableMoveMode()    
    cMaker.MoveTool.isInMoveMode = false            
    cMaker.MoveTool.rectEnd = {x = 0, y = 0}
    cMaker.MoveTool.rectStart = {x = 0, y = 0}
end

local function MoveToolInit()
    event.register(event.keypress, 
        function (key,scan,_repeat,shift,ctrl,alt)
            if key == 109 and not shift and not ctrl and not alt and not _repeat then -- M        
                cMaker.MoveTool.EnableMoveMode()
                return false
            end 
        end
    )
    
    event.register(event.mousedown, 
        function (x,y,button)     
            if cMaker.MoveTool.isInMoveMode and button == 1 then
                if cMaker.MoveTool.isDragging then
                    cMaker.MoveTool.Place(x,y)
                else
                    cMaker.MoveTool.StartRect(x,y)
                end               
                return false        
            end
        end
    )
    event.register(event.mouseup, 
        function (x,y,button,reason)  
            if cMaker.MoveTool.isInMoveMode and button == 1 then
                if not cMaker.MoveTool.isDragging then
                    cMaker.MoveTool.EndRect(x,y)
                    return false
                else
                    cMaker.MoveTool.isDragging = false
                    cMaker.MoveTool.DisableMoveMode()
                end
            end  
        end
    )

    event.register(event.tick,
        function ()
            if cMaker.MoveTool.isInMoveMode then
                cMaker.DrawModeText("Move Tool (right click to cancel)")

                local cursorX, cursorY = sim.adjustCoords(cMaker.CursorPos.x, cMaker.CursorPos.y)

                if cMaker.MoveTool.mouseDown then
                    cMaker.MoveTool.rectEnd.x = cursorX
                    cMaker.MoveTool.rectEnd.y = cursorY

                    cMaker.DrawRect(
                        cMaker.MoveTool.rectStart.x,
                        cMaker.MoveTool.rectStart.y,
                        cMaker.MoveTool.rectEnd.x,
                        cMaker.MoveTool.rectEnd.y,
                        255,255,255,128
                    )
                else
                    if cMaker.MoveTool.isDragging then
                        cMaker.MoveTool.movement.x = cMaker.MoveTool.rectStart.x - cursorX
                        cMaker.MoveTool.movement.y = cMaker.MoveTool.rectStart.y - cursorY
                                                
                        cMaker.DrawRect(
                            cMaker.MoveTool.rectStart.x - cMaker.MoveTool.movement.x,
                            cMaker.MoveTool.rectStart.y - cMaker.MoveTool.movement.y,
                            cMaker.MoveTool.rectEnd.x - cMaker.MoveTool.movement.x,
                            cMaker.MoveTool.rectEnd.y - cMaker.MoveTool.movement.y,
                            255,255,255,128
                        )
                    end
                end
            end
        end
    )
end

MoveToolInit()

-- v[STACK HUD]v
local cMaker = MaticzplChipmaker

function MaticzplChipmaker.alignToRight(text)
    local maxWidth = 0
    local outStr = ""
    

    for str in string.gmatch(text, "([^\n]+)") do   -- find widest line
        local width,height = graphics.textSize(str)
        
        if width > maxWidth then
            maxWidth = width
        end
    end
    
    local spaceWidth, spaceHeight = graphics.textSize(" ")

    for str in string.gmatch(text, "([^\n]+)") do
        local width,height = graphics.textSize(str)
        
        local line = str
        
        if width < maxWidth then
            for i = 1, math.floor((maxWidth - width) / spaceWidth), 1 do
                line = " "..line
            end
        end
        
        outStr = outStr .. line .."\n"
    end
    
    return outStr
end

-- yes this function is garbage but i dont feel like refactoring it <- ts is so confusing that not even the guy who made it wanted to fix it
function MaticzplChipmaker.DrawCursorDisplay()
    cMaker.StackEdit.selected = -1
    local x,y = simulation.adjustCoords(cMaker.CursorPos.x,cMaker.CursorPos.y)
    
    if sim.partID(x, y) == nil then
        return
    end

    local partsOnCursor = cMaker.GetAllPartsInPos(x,y)

    local partsString = ""
    local skipped = 0
    local hasSpecialDisplay = false

    local offset = math.max(cMaker.StackEdit.stackPos - 2,0)

    if #partsOnCursor ~= 0 and cMaker.StackEdit.stackPos >= #partsOnCursor then
        offset = math.max(#partsOnCursor - 6,0)
    end

    for i = #partsOnCursor -  offset, 1, -1 do     
        local part = partsOnCursor[i]

        cMaker.currentStackSize = #partsOnCursor

        if #partsOnCursor - i - offset > 5 then
            skipped = skipped + 1
        else            
            local type = elements.property(sim.partProperty(part,"type"),"Name")
            local id = sim.partProperty(part, "type") 
            local ctype = sim.partProperty(part, "ctype") 
            local temp = sim.partProperty(part, "temp") 
            local life = sim.partProperty(part, "life") 
            local tmp = sim.partProperty(part, "tmp") 
            local tmp2 = sim.partProperty(part, "tmp2") 
            local tmp3 = sim.partProperty(part, cMaker.tmp3name) 
            local tmp4 = sim.partProperty(part, cMaker.tmp4name) 
            local vx = sim.partProperty(part, "vx") 
            local vy = sim.partProperty(part, "vy") 
            local color = cMaker.getColorForString(elements.property(sim.partProperty(part,"type"),"Color"))
            -- this definitely looks like a boolean 
            local tmpDisplay = cMaker.handleTmp(tmp,type) -- for some reason i forgot this was a function and spent like 30 minutes trying to write my own thing 
            local strCtype = cMaker.handleCtype(ctype,type,tmp,tmp4) -- i spent like 2 hours on this bullshit, i should stop trying to do my own thing
            -- theres no way i genuinely spent another hour trying to write my own thing AGAIN after already knowing theres a handleTmp function 
            local props = {} 

                
            -- :sob:
            local overwriteType = strCtype.mode ~= nil
            if overwriteType then
                strCtype = strCtype.val
                color = ""
                type = ""
            end
            table.insert(props, string.format(color .. "%s\bg%s\bg", type, strCtype)) -- don't ask me, idk how either
            table.insert(props, string.format("id: " .. color .. "%s\bg", id)) -- black and white guy praying gif 
        
            -- hides if not 0
            -- if ctype ~= 0 then table.insert(props, string.format("%s\bg", ctypeDisplay)) end -- lord have mercy
            if temp ~= 0 then table.insert(props, string.format("K: %.2f" .. " C: " .. string.format("%.2f", temp - 273.15), temp)) end -- this is probably not a good way to write it but if it ain't broke, don't fix  it, right?
            if life ~= 0 then table.insert(props, string.format("life: %d", life)) end
            if tmp ~= 0 then table.insert(props, string.format("tmp: %s", tmpDisplay)) end
            if tmp2 ~= 0 then table.insert(props, string.format("tmp2: %d", tmp2)) end
            if tmp3 ~= 0 then table.insert(props, string.format("tmp3: %d", tmp3)) end
            if tmp4 ~= 0 then table.insert(props, string.format("tmp4: %d", tmp4)) end
            if vx ~= 0 or vy ~= 0 then
                table.insert(props, string.format("vx: %.2f", vx)) -- "if you know about %.2f as an argument for string.format you're clearly better at lua than the vast majority of script makers" - ieatdirt
                table.insert(props, string.format("vy: %.2f", vy))
            end
            
            -- join them together 
            partsString = partsString .. table.concat(props, ", ")

            if #partsOnCursor > 1 then
                partsString = partsString .. ", #" .. part
            end

            if (#partsOnCursor - cMaker.StackEdit.stackPos) == i then
                partsString = partsString .. " \x0F\xFF\x01\x01<\bg"    
                cMaker.StackEdit.selected = part     
            end

            partsString = partsString .. "\n"

            local typeName = elements.property(id, "Name")
            if typeName == "FILT" or typeName == "BRAY" or typeName == "PHOT" or typeName == "CONV" then
                hasSpecialDisplay = true

            end
        end        
    end    
    if skipped > 0 then
        partsString = partsString .. skipped.." more "
    end

    if cMaker.StackEdit.selectedField > 0 and cMaker.StackEdit.selected ~= -1 then
        local field = cMaker.propTable[cMaker.StackEdit.selectedField]
        local value = sim.partProperty(cMaker.StackEdit.selected,field)
        local typeName = elements.property(sim.partProperty(cMaker.StackEdit.selected,"type"),"Name")
        if value ~= nil then
            local descProps = cMaker.StackEdit.propDesc[typeName]
            local description = ""
            if descProps then
                description = descProps[field] or ""
            end
            if field == "temp" then
                value = (math.floor((value - 273.145) * 100) / 100).."C"
            end
            partsString = partsString .. "\btProp Edit: ["..field..': '..value..']\n'..description..'\bg\n'
        end
    end

    if cMaker.StackEdit.stackPos ~= 0 then         
        partsString = partsString .. "\bt[Stack Pos: "..cMaker.StackEdit.stackPos.."]\bg\n"
    else 
        if skipped > 0 then
            partsString = partsString .. "\n" --Add new line for "And x more"
        end 
    end    


    -- Set text position
    local width,height = graphics.textSize(partsString)
    local noDebugOffset = 14
    local textPos = {
        x=(597 - width),
        y=44
    }      

    local zx,zy,s = ren.zoomScope()
    local zwx,zwy,zfactor,zsize = ren.zoomWindow();
    if iscrackmod then  -- Cracker's mod
        textPos = {
            x = 9,
            y=50
        }
        if ren.zoomEnabled() and zx + (s / 2) > 305 then
            textPos = {
                x = 7,
                y= zsize + 4
            }   
        end
    else
        if ren.zoomEnabled() then            
            if tpt.version.jacob1s_mod ~= nil then
                if zx + (s / 2) > 305 then       -- if zoom window on the left side
                    textPos = {
                        x = 16,
                        y=zsize + 32
                    }    
                else
                    textPos = {
                        x = (sim.XRES - width-15),
                        y = zsize + 32
                    }
                    partsString = cMaker.alignToRight(partsString)
                end   
                noDebugOffset = 11
            else
                if zx + (s / 2) > 305 then       -- if zoom window on the left side
                    textPos = {
                        x = 7,
                        y= zsize + 4
                    }    
                else
                    textPos = {
                        x = (sim.XRES - width - 7),
                        y = zsize + 4
                    }
                    partsString = cMaker.alignToRight(partsString)
                end   
    
                noDebugOffset = 0
            end

        else            
            partsString = cMaker.alignToRight(partsString)
        end
    end
    

    if renderer.debugHUD() == 0 then
        textPos.y = textPos.y - noDebugOffset
    end

    -- Draw text
    local padding = 3
    graphics.fillRect(textPos.x - padding,textPos.y - padding,width+(padding*2),(height - 13)+(padding*2),0,0,0,cMaker.Settings.cursorDisplayBgAlpha) 
    graphics.drawText(textPos.x,textPos.y,partsString,255, 255, 255,180)
end

function MaticzplChipmaker.tmpToFiltMode(tmp)
    local modes = {"SET","AND","OR","SUB","RSHFT","BSHFT","NONE","XOR","NOT","QRTZ","VRSHIFT","VBSHIFT"}    
    local mode = modes[math.floor(tmp + 1)]
    if mode == nil then
        return "UNKNOWN"
    end
    return mode
end

function MaticzplChipmaker.ctypeToGol(ctype) --TODO: Implement this
    local golTable = {}
    golTable[0] = { color = 830464, name = "GOL"}
    golTable[1] = { color = 16711680, name = "HLIF"}
    golTable[2] = { color = 255, name = "ASIM"}
    golTable[3] = { color = 16776960, name = "2X2"}
    golTable[4] = { color = 65535, name = "DANI"}
    golTable[5] = { color = 16711935, name = "AMOE"}
    golTable[6] = { color = 16777215, name = "MOVE"}
    golTable[7] = { color = 14700560, name = "PGOL"}
    golTable[8] = { color = 5242880, name = "DMOE"}
    golTable[9] = { color = 5242960, name = "3-4"}
    golTable[10] = { color = 5263440, name = "LLIF"}
    golTable[11] = { color = 5243135, name = "STAN"}
    golTable[12] = { color = 16510077, name = "SEED"}
    golTable[13] = { color = 11068576, name = "MAZE"}
    golTable[14] = { color = 10145074, name = "COAG"}
    golTable[15] = { color = 18347, name = "WALL"}
    golTable[16] = { color = 15054651, name = "GNAR"}
    golTable[17] = { color = 2463112, name = "REPL"}
    golTable[18] = { color = 801792, name = "MYST"}
    golTable[19] = { color = 16711680, name = "LOTE"}
    golTable[20] = { color = 25650, name = "FRG2"}
    golTable[21] = { color = 64, name = "STAR"}
    golTable[22] = { color = 25600, name = "FROG"}
    golTable[23] = { color = 16776960, name = "BRAN"}

    if golTable[ctype] == nil then
        return nil, nil
    end

    local color = cMaker.getColorForString(golTable[ctype].color)
    local name = golTable[ctype].name

    return name, color
end

function MaticzplChipmaker.toBits(num,bits)
    bits = bits or math.max(1, select(2, math.frexp(num)))
    local t = {}      
    for b = bits, 1, -1 do
        t[b] = math.fmod(num, 2)
        num = math.floor((num - t[b]) / 2)
    end
    return t
end


function MaticzplChipmaker.handleCtype(ctype,type,tmp,tmp4)
    local isCtypeNamed,ctypeName = pcall(elements.property,ctype,"Name")
    local typeId = elements["DEFAULT_PT_"..type]

    if type == "PHOT" or type == "BIZR" or type == "BIZS" or type == "BIZG" or type == "BRAY" or type == "C-5" then
        if cMaker.spectrumFormat == 0 then
            return "(0x"..string.upper(string.format("%x", ctype)) ..")"
        end
        if cMaker.spectrumFormat == 1 then
            return "("..string.upper(ctype) ..")"            
        end
        if cMaker.spectrumFormat == 2 then
            return "("..string.upper(bit.band(0x1FFFFFFF,ctype)) ..")"   
        end
    end   

    if type == "PIPE" or type == "PPIP" then
        if isCtypeNamed and ctypeName ~= "NONE" then            
            local color = cMaker.getColorForString(elements.property(ctype,"Color"))
            
            local out = "PIPE with "..color..ctypeName.."\bg"

            if ctypeName == "LAVA" then
                color = cMaker.getColorForString(elements.property(tmp4,"Color"))
                local isTmp4Named,tmp4Name = pcall(elements.property,tmp4,"Name")
                if isTmp4Named then                    
                    out = "PIPE with molten "..color..tmp4Name.."\bg"
                end
            end

            return {mode = "overwrite",val = out}
        end
    end

    if type == "LAVA" and ctypeName ~= "NONE" then
        if isCtypeNamed then            
            local color = cMaker.getColorForString(elements.property(ctype,"Color"))

            local out = "Molten "..color..ctypeName.."\bg"
            return {mode = "overwrite",val = out}
        end
    end

    if type == "LIFE" then  
        local golType, color = cMaker.ctypeToGol(ctype)


        --check custom gol
        if golType == nil then            
            for k,v in pairs(sim.listCustomGol()) do
                if v.rule == ctype then
                    golType = v.name
                    color = cMaker.getColorForString(v.color1)
                end
            end
        end

        if color ~= nil and golType ~= nil then
            local out = color..golType.."\bg"
            return {mode = "overwrite",val = out}            
        end
    end

    if type == "FILT" then
        local mode = cMaker.tmpToFiltMode(tmp)
        if cMaker.spectrumFormat == 0 then
            return "("..mode..", 0x"..string.upper(string.format("%x", ctype)) ..")"
        end
        if cMaker.spectrumFormat == 1 then
            return "("..mode..", "..string.upper(ctype) ..")"            
        end
        if cMaker.spectrumFormat == 2 then
            return "("..mode..", "..string.upper(bit.band(0x1FFFFFFF,ctype)) ..")"
	end
        if cMaker.spectrumFormat == 3 then
            return "("..mode..", "..table.concat(cMaker.toBits(ctype, 30)):gsub("....", "%1 "):gsub(":$", "") ..")"
        end
    end
    
    if type == "CLNE" or  type == "BCLN" or type == "PCLN" or type == "PBCN" then
        if ctypeName == "LAVA" then            
            local color = cMaker.getColorForString(elements.property(tmp,"Color"))
            local tmpName = elements.property(tmp,"Name")
            
            local typeColor = cMaker.getColorForString(elements.property(typeId,"Color"))

            local out = typeColor..type.."\bg(Molten "..color..tmpName.."\bg)"
            return {mode = "overwrite",val = out}
        end
    end

    if ctype >= 125 + 512 and type == "CRAY" then --CRAY FILT WITH TMP
        if (ctype - 125) % 512 == 0 then --Is it actually filt?
            local mode = cMaker.tmpToFiltMode((ctype - 125) / 512)
            
            local color = cMaker.getColorForString(elements.property(elem.DEFAULT_PT_FILT,"Color"))
            
            return "("..color.."FILT\bg("..mode.."))"      
        end
    end

    if ctype == 0 then
        return ""
    end

    if type == "LITH" or type == "GLOW" or type == "WWLD" then
        return "("..ctype..")"        
    end
    
    if isCtypeNamed then
        local color = cMaker.getColorForString(elements.property(ctype,"Color"))
        return "("..color..ctypeName.."\bg)"        
    end
    
    return "("..ctype..")"
    
end

function MaticzplChipmaker.handleTmp(tmp,type)
    local success,name = pcall(elements.property,tmp,"Name")
    if type == "CONV" then
        if success then
            local color = cMaker.getColorForString(elements.property(tmp,"Color"))
            
            return color..name.."\bg"       
        end    
    end   
    
    return tmp    
end

event.register(event.keypress, function (key, scan, rep, shift, ctrl, alt)
    -- CTRL + U to switch mode
    if key == 117 and ctrl and not shift and not alt and not rep then
        cMaker.spectrumFormat = (cMaker.spectrumFormat + 1) % 4
        local modeNames = {"Hexadecimal", "Decimal with 30th bit", "Decimal without 30th bit", "Binary"}
        print("Spectrum format: "..modeNames[cMaker.spectrumFormat + 1])
        return false
    end
end)

-- ^[STACK HUD]^


-- v[Zoom Overlay]v

local cMaker = MaticzplChipmaker

-- ID, X, Y, ZoomX, ZoomY, ZoomScale
function MaticzplChipmaker.RegisterZoomOverlayCallback(func)
    table.insert(cMaker.ZoomOverlay.CallbackList,func)
end

function MaticzplChipmaker.DrawZoomOverlay()
    if not ren.zoomEnabled() then
        return
    end

    -- Excluding RB
    -- [<LEFT RIGHT) <TOP BOTTOM) ]
    local x,y,size = ren.zoomScope()
    local zx,zy,zfactor,zsize = ren.zoomWindow()

    for i = x, x+size - 1, 1 do        
        for j = y, y+size - 1, 1 do
            local partId = sim.partID(i,j)
            if partId ~= nil then                    
                local inZoomX = ((i - x) * zfactor) +zx
                local inZoomY = ((j - y) * zfactor) +zy
                
                for k, func in pairs(cMaker.ZoomOverlay.CallbackList) do
                    func(partId,i,j,inZoomX,inZoomY,zfactor)
                end
            end
        end
    end
end

-- Ctype overlay
cMaker.RegisterZoomOverlayCallback(function (id, x, y, zx, zy, zs)
    local type = sim.partProperty(id,'type')
    local ctype = sim.partProperty(id,'ctype')
    local tmp = sim.partProperty(id,'tmp')

    local typeBlacklist = {elem.DEFAULT_PT_BRAY,elem.DEFAULT_PT_WWLD,elem.DEFAULT_PT_FILT,elem.DEFAULT_PT_PHOT,elem.DEFAULT_PT_BIZR,elem.DEFAULT_PT_BIZG,elem.DEFAULT_PT_BIZS,elem.DEFAULT_PT_LITH}
    
    local includes = false
    for _, bltype in pairs(typeBlacklist) do
        if bltype == type then
            includes = true
        end
    end

    if includes then
        return
    end
    

    local success, ctypeColor = pcall(elem.property,ctype,"Color")
    if success and ctype ~= 0 then
        local hex = string.format("%x", ctypeColor)

        local r = tonumber(string.sub(hex,3,4),16)
        local g = tonumber(string.sub(hex,5,6),16)
        local b = tonumber(string.sub(hex,7,8),16)
        
        while #hex < 8 do -- If leading it had leading zeroes add them back in
            hex = "0"..hex
            r = tonumber(string.sub(hex,3,4),16)
            g = tonumber(string.sub(hex,5,6),16)
            b = tonumber(string.sub(hex,7,8),16)
        end
        local inset = zs * 0.3

        if type == elem.DEFAULT_PT_CONV and tmp ~= 0 then
            gfx.fillRect(zx+inset,zy+inset,(zs-inset*2) / 2,zs-inset*2,r,g,b)
        else
            gfx.fillRect(zx+inset,zy+inset,zs-inset*2,zs-inset*2,r,g,b)
        end

    end
    
    local success, tmpColor = pcall(elem.property,tmp,"Color")
    if type == elem.DEFAULT_PT_CONV and success and tmp ~= 0 then
        local hex = string.format("%x", tmpColor)

        local r = tonumber(string.sub(hex,3,4),16)
        local g = tonumber(string.sub(hex,5,6),16)
        local b = tonumber(string.sub(hex,7,8),16)
        
        while #hex < 8 do
            hex = "0"..hex
            r = tonumber(string.sub(hex,3,4),16)
            g = tonumber(string.sub(hex,5,6),16)
            b = tonumber(string.sub(hex,7,8),16)
        end

        local inset = zs * 0.3
        local sideOffset = (zs-inset*2) / 2
        gfx.fillRect(zx+inset+math.floor(sideOffset),zy+inset,sideOffset,zs-inset*2,r,g,b)
    end
end)


event.register(event.keypress,function (key,scan,_repeat,shift,ctrl,alt)
    if key == 111 and ctrl and not alt and not shift then --CTRL + O
        if cMaker.ZoomOverlay.tickEvent == nil then
            cMaker.ZoomOverlay.tickEvent = event.register(event.tick,cMaker.DrawZoomOverlay)        
        else
            event.unregister(event.tick,cMaker.ZoomOverlay.tickEvent)
            cMaker.ZoomOverlay.tickEvent = nil
        end
    end    
end)


local cMaker = MaticzplChipmaker

function MaticzplChipmaker.FollowUpdate.TryFollow()
    if cMaker.FollowUpdate.currentID ~= -1 and ren.zoomEnabled() then
        local x, y, size = ren.zoomScope()
        local x, y = sim.partPosition(cMaker.FollowUpdate.currentID)
        
        if x + size / 2 > sim.XRES then
            x = math.floor(sim.XRES - size / 2)
        end
        if y + size / 2 > sim.YRES then
            y = math.floor(sim.YRES - size / 2)
        end
        if x - size / 2 < 0 then
            x = math.ceil(size / 2)
        end
        if y - size / 2 < 0 then
            y = math.ceil(size / 2)
        end

        ren.zoomScope(x - size / 2, y - size / 2, size)
        local wx, wy, zoomFactor, wsize = ren.zoomWindow()
        if x > 305 then
            ren.zoomWindow(0,0,zoomFactor)
        else
            ren.zoomWindow(sim.XRES - wsize,0,zoomFactor)
        end
        local stack = cMaker.GetAllPartsInPos(x,y)
        for z, part in ipairs(stack) do
            if part == cMaker.FollowUpdate.currentID then
                cMaker.StackEdit.stackPos = #stack - z
            end
        end
    end
end

function MaticzplChipmaker.FollowUpdate.FindNextPart(id)
    if sim.partPosition(id + 1) then
        return id + 1
    else
        local closest = 10000000
        for p in sim.parts() do
            if p - id > 0 and p - id < closest - id then
                closest = p
            end
        end
        if closest == 10000000 then
            return -1
        else
            return closest
        end
    end
end

event.register(event.keypress,function (key,scan,rep,shift,ctrl,alt)
    -- space or f
    if key == 32 and not rep or key == 102 and not shift and not alt and not rep then
        cMaker.FollowUpdate.currentID = -1
    end
    -- alt f
    if key == 102 and alt and not rep then
        if cMaker.FollowUpdate.currentID == -1 then
            cMaker.ReorderParticles();
        end

        cMaker.FollowUpdate.currentID = cMaker.FollowUpdate.FindNextPart(cMaker.FollowUpdate.currentID)

        MaticzplChipmaker.FollowUpdate.TryFollow()
    end
    -- shift f
    if key == 102 and shift and not alt and not rep then
        if cMaker.FollowUpdate.currentID == -1 then
            cMaker.ReorderParticles();
        end

        local x, y = sim.adjustCoords(cMaker.CursorPos.x, cMaker.CursorPos.y)
        local newID = sim.partID(x,y) or -1
        if newID < cMaker.FollowUpdate.currentID then
            cMaker.FollowUpdate.currentID = -1
        else
            cMaker.FollowUpdate.currentID = newID
        end    
        MaticzplChipmaker.FollowUpdate.TryFollow()
    end
end)

event.register(event.tick,function ()
    if cMaker.FollowUpdate.currentID ~= -1 and ren.zoomEnabled() then
        local x, y = sim.partPosition(cMaker.FollowUpdate.currentID)
        
        cMaker.DrawRect(x,y,x,y,255,255,255,100)
    end    
end)

function MaticzplChipmaker.EveryFrame()
    if ren.hud() then        
        cMaker.DrawCursorDisplay()
    end
end

function MaticzplChipmaker.Init()
    event.register(event.keypress, cMaker.OnKey)
    event.register(event.mousedown,cMaker.OnMouseDown)
    --event.register(event.mouseup,  cMaker.OnMouseUp)
    event.register(event.mousemove,cMaker.OnMouseMove)
    event.register(event.tick,     cMaker.EveryFrame)
    event.register(event.close,    cMaker.SaveSettings)

    tpt.setdebug(bit.bor(0x8, 0x4))

    -- Test tmp3/4 or tmp3/1 detection
    local part = sim.partCreate(-3,4,4,1)
    pcall(sim.partProperty, part, "tmp3", 2138)
    local _, res = pcall(sim.partProperty, part, "tmp3")
    sim.partKill(part)
    if res == 2138 then
        MaticzplChipmaker.tmp3name = "tmp3"
        MaticzplChipmaker.tmp4name = "tmp4"
        MaticzplChipmaker.propTable[6] = "tmp3"
        MaticzplChipmaker.propTable[7] = "tmp4"
    else
        MaticzplChipmaker.tmp3name = "tmp3"
        MaticzplChipmaker.tmp4name = "tmp4"   
        MaticzplChipmaker.propTable[6] = "tmp3"
        MaticzplChipmaker.propTable[7] = "tmp4"
    end

    local MANAGER = rawget(_G, "MANAGER")    

    local CDBgColA = MANAGER.getsetting("MaticzplCmaker","CDBgColA")    
    if CDBgColA ~= nil then
        cMaker.Settings.cursorDisplayBgAlpha = CDBgColA 
    end
end

cMaker.Init()

print("Six Eyes based on Subframe Chipmaker and LHR. Edited by TheFPSKiller")
--== Layering Helper Squared ==--
---- Remake of Layering Helper Reforged
---- Updated with Column Moving buttons (< and >) above the CLR headers.

--< Local Functions >--
local function testIsNumber(value) return tonumber(value) ~= nil end

local function testElement(element_type)
	if element_type == nil then return false, 0 end
	if testIsNumber(element_type) then
		-- It's already a numeric ID — validate it by asking tpt.element for its name
		local n = tonumber(element_type)
		local success = pcall(tpt.element, n)
		if success then return true, n end
	else
		-- It's a name string like "CONV" — look up its ID
		local success, ret = pcall(tpt.element, element_type)
		if success then return true, ret end
	end
	return false, 0
end

local names_setstring = ""
local names_nilstring = ""
function testExpression(str)
	if string.len(names_setstring) < 1 or string.len(names_nilstring) < 1 then
		local name_count = 0
		local string_buffer = ""
		local vstring_buffer = ""

		for name, tbl in pairs(tpt.el) do
			if name_count >= 5 then
				names_setstring = names_setstring .. string.format("%s = %s; ", string_buffer, vstring_buffer)
				names_nilstring = names_nilstring .. string.format("%s = %s; ", string_buffer, "nil" .. ((name_count > 1) and (string.rep(", nil", name_count * 2 - 1)) or ""))

				string_buffer = ""
				vstring_buffer = ""
				name_count = 0
			end

			local exists, elem_id = testElement(name)
			if exists then
				local cleanname = string.gsub(name, "%-", "")
				local lname, uname = string.lower(cleanname), string.upper(cleanname)

				string_buffer = string_buffer .. string.rep(", ", name_count > 0 and 1 or 0) .. lname .. ", " .. uname
				vstring_buffer = vstring_buffer .. string.rep(", ", name_count > 0 and 1 or 0) .. elem_id .. ", " .. elem_id
				
				name_count = name_count + 1
			end
		end
		
		if name_count > 0 then
			names_setstring = names_setstring .. string.format("local %s = %s; ", string_buffer, vstring_buffer)
			names_nilstring = names_nilstring .. string.format("%s = %s; ", string_buffer, "nil" .. ((name_count > 1) and (string.rep(", nil", name_count * 2 - 1)) or ""))
		end
	end

	local func = loadstring(names_setstring .. "local lresult = (" .. str .. "); " .. names_nilstring .. "return lresult")
	if func then
		local ret, err = func()
		if ret == nil and type(err) == "string" then
			return false, err
		end
		return true, ret
	end
	
	return false, nil
end

--< Local Variables >--
local open_key_code = 106 -- Ctrl+J

local is_drawing = false
local is_window_open = false
local pos1_x, pos1_y, pos2_x, pos2_y = 0, 0, 0, 0
local color_r, color_g, color_b, color_a = 161, 71, 194, 255

local option_no_overlap = false

local fields = {"Type", "Life", "Ctype", "Temp", "Tmp", "Tmp2", "Tmp3", "Tmp4"}

--< GUI Components >--
local guiWindow = Window:new(-1, -1, 600, 400)
local guiComponents = {}

local function get_input(use_lua)
	local str = tpt.input()
	if string.len(str) > 0 and use_lua ~= false then
		local success, result = testExpression(str)
		if success then
			if tostring(result) == "nil" then result = 0 end
			return tostring(result)
		end
	end
	return str
end

-- Function to swap the contents of two rows
local function swapRows(r1, r2)
	for _, field in ipairs(fields) do
		local comp1 = guiComponents["Part" .. r1 .. "_" .. field]
		local comp2 = guiComponents["Part" .. r2 .. "_" .. field]
		local val1, val2 = comp1:text(), comp2:text()
		comp1:text(val2)
		comp2:text(val1)
	end
end

-- Function to swap the contents of two columns
local function swapColumns(c1, c2)
	local f1, f2 = fields[c1], fields[c2]
	for i = 1, 5 do
		local comp1 = guiComponents["Part" .. i .. "_" .. f1]
		local comp2 = guiComponents["Part" .. i .. "_" .. f2]
		local val1, val2 = comp1:text(), comp2:text()
		comp1:text(val2)
		comp2:text(val1)
	end
end

-- UI Spacing constants (adjusted for 9 columns)
local col_w = 66
local comp_w = 65

guiComponents["Label"] = Label:new(0, 0, 600, 40, "Layering Helper Squared")

-- Header Column Controls (Move Left/Right + Clear)
for idx, field in ipairs(fields) do
	local col_x = 1 + col_w * (idx - 1)

	-- Move Column Left
	guiComponents[field .. "_MoveLeft"] = Button:new(col_x, 40, 32, 26 / 2, "<")
	guiComponents[field .. "_MoveLeft"]:action(function()
		if idx > 1 then swapColumns(idx, idx - 1) end
	end)
	if idx == 1 then guiComponents[field .. "_MoveLeft"]:enabled(false) end

	-- Move Column Right
	guiComponents[field .. "_MoveRight"] = Button:new(col_x + 33, 40, 32, 26 / 2, ">")
	guiComponents[field .. "_MoveRight"]:action(function()
		if idx < #fields then swapColumns(idx, idx + 1) end
	end)
	if idx == #fields then guiComponents[field .. "_MoveRight"]:enabled(false) end

	-- Clear Column
	guiComponents[field .. "_Clear"] = Button:new(col_x, 40 + 26 / 2, comp_w, 26 / 2, "CLR " .. string.upper(field))
	guiComponents[field .. "_Clear"]:action(function()
		for i = 1, 5 do
			guiComponents["Part" .. i .. "_" .. field]:text("")
		end
	end)
end

guiComponents["ClearButton"] = Button:new(1 + col_w * 8, 40, comp_w, 26, "del *.*")

-- Row Components
for i = 1, 5 do
	guiComponents["Part" .. i .. "_Type"]	= Textbox:new(1 + col_w * 0, 40 + 26 * i, comp_w, 26, nil, "type")
	guiComponents["Part" .. i .. "_Life"]	= Textbox:new(1 + col_w * 1, 40 + 26 * i, comp_w, 26, nil, "life")
	guiComponents["Part" .. i .. "_Ctype"]	= Textbox:new(1 + col_w * 2, 40 + 26 * i, comp_w, 26, nil, "ctype")
	guiComponents["Part" .. i .. "_Temp"]	= Textbox:new(1 + col_w * 3, 40 + 26 * i, comp_w, 26, nil, "temp")
	guiComponents["Part" .. i .. "_Tmp"]	= Textbox:new(1 + col_w * 4, 40 + 26 * i, comp_w, 26, nil, "tmp")
	guiComponents["Part" .. i .. "_Tmp2"]	= Textbox:new(1 + col_w * 5, 40 + 26 * i, comp_w, 26, nil, "tmp2")
	guiComponents["Part" .. i .. "_Tmp3"]	= Textbox:new(1 + col_w * 6, 40 + 26 * i, comp_w, 26, nil, "tmp3")
	guiComponents["Part" .. i .. "_Tmp4"]	= Textbox:new(1 + col_w * 7, 40 + 26 * i, comp_w, 26, nil, "tmp4")
	
	-- Row Move Up Button
	guiComponents["Part" .. i .. "_Up"] = Button:new(1 + col_w * 8, 40 + 26 * i, 18, 26, "^")
	guiComponents["Part" .. i .. "_Up"]:action(function()
		if i > 1 then swapRows(i, i - 1) end
	end)
	if i == 1 then guiComponents["Part" .. i .. "_Up"]:enabled(false) end

	-- Row Move Down Button
	guiComponents["Part" .. i .. "_Down"] = Button:new(1 + col_w * 8 + 19, 40 + 26 * i, 18, 26, "v")
	guiComponents["Part" .. i .. "_Down"]:action(function()
		if i < 5 then swapRows(i, i + 1) end
	end)
	if i == 5 then guiComponents["Part" .. i .. "_Down"]:enabled(false) end

	-- Row Clear Button
	guiComponents["Part" .. i .. "_ClearButton"] = Button:new(1 + col_w * 8 + 38, 40 + 26 * i, 26, 26, "CLR")
	guiComponents["Part" .. i .. "_ClearButton"]:action(function()
		for _, field in ipairs(fields) do
			guiComponents["Part" .. i .. "_" .. field]:text("")
		end
	end)
end

guiComponents["Label2"] = Label:new(0, 40 + 26 * 6, 600, 40, "Options")

guiComponents["noOverlapToggle"] = Button:new(1, 40 * 2 + 26 * 6, 600 - 2, 26, "No Overlap: OFF (LHR will try to place things regardless of what is there)")
guiComponents["noOverlapToggle"]:action(function() 
	option_no_overlap = not option_no_overlap
	if option_no_overlap then 
		guiComponents["noOverlapToggle"]:text("No Overlap: ON (LHR only place parts somewhere if that place is empty)")
	else
		guiComponents["noOverlapToggle"]:text("No Overlap: OFF (LHR will try to place things regardless of what is there)")
	end
end)

guiComponents["TimesBox"]		= Textbox:new(1, 400 - 40 - 26, 600 - 2, 26, nil, "Times (def: 1)")
guiComponents["CreateButton"]	= Button:new((600 / 2) * 0 + 1, 400 - 40 - 1, 600 / 2, 40, "Create Parts")
guiComponents["CancelButton"]	= Button:new((600 / 2) * 1, 400 - 40 - 1, 600 / 2 - 1, 40, "Cancel")

local function makePart(x, y, data)
	local index = sim.partCreate(-3, x, y, data.type)
	if index >= 0 then
		for k, v in pairs(data) do
			if k ~= "type" then
				sim.partProperty(index, k, v)
			end
		end
	end
	return index >= 0
end

local function makeParts(x, y, datas)
	local valid_data = {}
	for _, data in ipairs(datas) do
		if makePart(x, y, data) then
			valid_data[#valid_data + 1] = data
		end
	end
	return valid_data
end

local function evaluateStr(value)
	if string.len(value) > 0 and value ~= nil then
		local success, result = testExpression(value)
		if success then
			if tostring(result) == "nil" then result = 0 end
			return tostring(result)
		end
	end
	return value
end 

local function collectPartDatas()
	local datas = {}
	local data = {}
	local tmpv = ""
	local ctype_exists, ctype_id = false, 0

	for _i = 1, 5 do
		local i = 6 - _i

		if guiComponents["Part" .. i .. "_Type"]:text() ~= "" then
			local typeExists, typeIndex = testElement(guiComponents["Part" .. i .. "_Type"]:text())
			if typeExists then
				data = {type = typeIndex}
			
				tmpv = evaluateStr(guiComponents["Part" .. i .. "_Life"]:text())
				if testIsNumber(tmpv) then
					data.life = tonumber(tmpv)
				elseif tmpv ~= "" then
					print("part" .. i .. ": Life invalid!")
				end

				tmpv = evaluateStr(guiComponents["Part" .. i .. "_Ctype"]:text())
				ctype_exists, ctype_id = testElement(evaluateStr(tmpv))
				if ctype_exists then
					data.ctype = ctype_id
				elseif tmpv ~= "" then
					print("part" .. i .. ": Ctype invalid!")
				end

				tmpv = evaluateStr(guiComponents["Part" .. i .. "_Temp"]:text())
				if testIsNumber(tmpv) then
					data.temp = tonumber(tmpv)
				elseif tmpv ~= "" then
					print("part" .. i .. ": Temp invalid!")
				end

				tmpv = evaluateStr(guiComponents["Part" .. i .. "_Tmp"]:text())
				if testIsNumber(tmpv) then
					data.tmp = tonumber(tmpv)
				elseif tmpv ~= "" then
					print("part" .. i .. ": Tmp invalid!")
				end

				tmpv = evaluateStr(guiComponents["Part" .. i .. "_Tmp2"]:text())
				if testIsNumber(tmpv) then
					data.tmp2 = tonumber(tmpv)
				elseif tmpv ~= "" then
					print("part" .. i .. ": Tmp2 invalid!")
				end

				tmpv = evaluateStr(guiComponents["Part" .. i .. "_Tmp3"]:text())
				if testIsNumber(tmpv) then
					data.tmp3 = tonumber(tmpv)
				elseif tmpv ~= "" then
					print("part" .. i .. ": Tmp3 invalid!")
				end

				tmpv = evaluateStr(guiComponents["Part" .. i .. "_Tmp4"]:text())
				if testIsNumber(tmpv) then
					data.tmp4 = tonumber(tmpv)
				elseif tmpv ~= "" then
					print("part" .. i .. ": Tmp4 invalid!")
				end

				datas[#datas + 1] = data
			else
				print("part" .. i .. ": Type invalid")
			end
		end
	end
	return datas
end

guiComponents["CreateButton"]:action(function()
	local times = 1
	local tmpv = guiComponents["TimesBox"]:text()
	if testIsNumber(tmpv) and tonumber(tmpv) >= 0 then
		times = tonumber(tmpv)
	end

	interface.closeWindow(guiWindow)
	is_window_open = false
	
	local datas = collectPartDatas()
	if #datas > 0 then
		if pos1_x == pos2_x and pos1_y == pos2_y then
			if (option_no_overlap and sim.partID(pos2_x, pos2_y) == nil) or option_no_overlap == false then
				for _ = 1, times do
					datas = makeParts(pos2_x, pos2_y, datas)
					if #datas < 1 then return end
				end
			end
		else
			local x_start, x_end = pos1_x, pos2_x
			if pos2_x < pos1_x then x_start = pos2_x; x_end = pos1_x end

			local y_start, y_end = pos1_y, pos2_y
			if pos2_y < pos1_y then y_start = pos2_y; y_end = pos1_y end

			for x = x_start, x_end do
				for y = y_start, y_end do
					if (option_no_overlap and sim.partID(x, y) == nil) or option_no_overlap == false then
						for _ = 1, times do
							datas = makeParts(x, y, datas)
							if #datas < 1 then return print("[LHR] Creation ended early"), print("[LHR] It is possible the part limit was reached") end
						end
					end
				end
			end
		end
	end
end)

guiComponents["CancelButton"]:action(function()
	interface.closeWindow(guiWindow)
	is_window_open = false
end)

guiComponents["ClearButton"]:action(function()
	for i = 1, 5 do
		for _, field in ipairs(fields) do
			guiComponents["Part" .. i .. "_" .. field]:text("")
		end
	end
end)

for _, component in pairs(guiComponents) do
	guiWindow:addComponent(component)
end

function lhr_showWindow() 
	is_window_open = true
	interface.showWindow(guiWindow) 
end

event.register(evt.tick, function()
	if is_drawing then
		if pos1_x == pos2_x or pos1_y == pos2_y then
			graphics.drawLine(pos1_x, pos1_y, pos2_x, pos2_y, color_r, color_g, color_b, color_a)
		else
			local dist_x, dist_y = math.abs(pos2_x - pos1_x) + 1, math.abs(pos2_y - pos1_y) + 1
			local chosen_x, chosen_y = (pos1_x < pos2_x and pos1_x or pos2_x), (pos1_y < pos2_y and pos1_y or pos2_y)
			
			graphics.drawRect(chosen_x, chosen_y, dist_x, dist_y, color_r, color_g, color_b, color_a)

			local txt = dist_x .. "x" .. dist_y
			local text_x, text_y = graphics.textSize(txt)

			if (text_x + 2) < dist_x and (text_y + 2) < dist_y then
				graphics.drawText(chosen_x + dist_x / 2 - text_x / 2 + 1, chosen_y + dist_y / 2 - text_y / 2 + 2, txt, color_r, color_g, color_b, color_a)
			end
		end
	end
end)

event.register(evt.mousemove, function(x, y, dx, dy)
	if is_drawing then
		pos2_x, pos2_y = sim.adjustCoords(tpt.mousex, tpt.mousey)
	end
end)

event.register(evt.keypress, function(key, scan, rep, shift, ctrl)
	-- Trigger selection box with Ctrl+J
	if key == open_key_code and ctrl and not is_drawing then
		pos1_x, pos1_y = sim.adjustCoords(tpt.mousex, tpt.mousey)
		pos2_x, pos2_y = sim.adjustCoords(tpt.mousex, tpt.mousey)
		is_drawing = true
	end
end)

event.register(evt.keyrelease, function(key, _, _, _, ctrl)
	if key == open_key_code and is_drawing then
		is_drawing = false
		pos2_x, pos2_y = sim.adjustCoords(tpt.mousex, tpt.mousey)
		lhr_showWindow()
	end
end)

print("LHR Ready.")