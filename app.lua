--[[

    find volume of 3d shape bounded by two given curves

    func(1,2,etc) are lua's functions,
    f(1,2,etc) are nspire's functions.

--]]

-- default variables
window = platform.window
var.store('ypos', 1)
var.store('xpos', 1)
var.store('areadisp', false)
var.store('volumedip', false)
maxf = 10
zoom = 10
fontsize = 15

-- create 10 empty function variables
for i = 1, maxf do
    if i == 1 then
        local default = ''
    else
        local default = nil
    end
    var.store('func'..i, default)
end

-- default tables
functions = {}
values = {}
errors = {}
points = {}
ipoints = {}
ipointpairs = {}
orientation = { 'a', 'b', 'aor' }
origin = {50, 160}
opts = {region = ''}

-- x and y axis positions
x = {
    x = 50,
    y = 80,
    dx = 50,
    dy = 190
}
y = {
    x = 5,
    y = 160,
    dx = 300,
    dy = 160
}

-- menu
function findarea()
    var.store('areadisp', true)
    window.invalidate()
end

function findvolume()
    var.store('volumedisp', true)
    window.invalidate()
end

function clear()
    for i = 1, #points do
        var.store('func'..i, '')
    end
    var.store('areadisp', false)
    var.store('volumedisp', false)
    var.store('ypos', 1)
    var.store('xpos', 1)
    math.eval('ClearAZ')
    points = {}
    window.invalidate()
end

menu = {
    {'actions',
        {'clear', clear}
    },
    {'integration',
        {'area', findarea},
        {'volume', findvolume},
    }
}

toolpalette.register(menu)

-- homemade tools

function deref(o)
    d = {}
    -- associative
    if table.concat(o, '.') == '' then
        for k, v in pairs(o) do
            d[k] = v
        end
    -- indexed
    else
        for i, v in ipairs(o) do
            d[i] = v
        end
    end
    return d
end

function table.reverse(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

-- graphical tools

function navigate(key)

    -- ui controller
    local ypos = var.recall('ypos')
    local xpos = var.recall('xpos')

    if key == 'up' and ypos ~= 1 then
        var.store('ypos', ypos - 1)
    elseif key == 'down' and ypos < maxf then
        local newpos = ypos + 1
        var.store('ypos', newpos)
        if not var.recall('func'..newpos) then
            var.store('func'..newpos, '')
        end
    elseif key == 'right' and xpos == 1 then
        var.store('ypos', 1)
        var.store('xpos', 2)
    elseif key == 'left' and xpos == 2 then
        var.store('ypos', 1)
        var.store('xpos', 1)
    end
    window:invalidate()
end

function accumulatef()

    -- store defined functions in a designated table
    for i, v in ipairs(var.list()) do
        local fname = string.find(v, 'func%d+')
        local inf = table.contains(functions, v)
--        local inf = functions[tonumber(string.sub(v,string.find(v,'%d+') or 0) or 0)]
        if fname and not inf then
            local id = string.sub(v, string.find(v, '%d+'))
            local func = var.recall(v)
            table.insert(functions, tonumber(id), var.recall(v))
            opts['func'..id] = {id = id, func = func}
            if tonumber(id) == 1 then
                opts.region = func
            end
        end
    end
end

function intersection()

    -- find all intersection points
    for i = 2, #functions do
        for j = 1, i - 1 do
            local expr = string.format('%s=%s', functions[i], functions[j])
            local dispip = string.format('solve(%s, x)', expr)
            local ip = math.evalStr(dispip)
            if ipoints[ip] ~= ip then
                ipoints[ip] = ip
            end
        end
    end

    -- implementing intersection points
    for k, v in pairs(ipoints) do
        local old = var.recall('intersection') or ''
        if #functions == 2 then
            local copy = {}
            for ip in string.gmatch(k, '%d+') do
                table.insert(copy, #copy+1, ip)
            end
            ipointpairs[#ipointpairs+1] = copy
        end 
    end
end

function sortf()

    -- sort functions by ascending output
    -- only call if a and b are defined
    local a = var.recall('a')
    local b = var.recall('b')
    
    --var.store('test', table.concat(functions, ', '))
    local devrn = {}

    local randnum = math.random(a*100, b*100) / 100
    table.insert(devrn, #devrn+1, randnum)
    
    -- evaluate all functions with random number within range 
    for i, v in ipairs(functions) do
        local val = math.evalStr(string.gsub(v, 'x', randnum))
        table.insert(values, val)
    end

    local values_copy = deref(values)
--    var.store('test', table.concat(values_copy, ', ')..', '..table.concat(devrn, ', '))

    table.sort(values_copy)

    local indexdiff = {}

    -- find the difference in index between values and sorted values
    for i, v in ipairs(values) do
        for ic, vc in ipairs(values_copy) do
            if v == vc then
                local id = ic - i
                indexdiff[v] = {}
                indexdiff[v].id = id
            end
        end
    end

    functions_copy = {}

    -- apply index differences to functions
    for k, v in pairs(indexdiff) do
        local id = v.id
        for fi, fv in ipairs(functions) do
            functions_copy[fi-id] = fv
        end
    end

    
    var.store('test', table.concat(functions, ', '))
- reverse the order of functions
    functions = table.reverse(functions_copy)

end

function graph(expr)

    -- send points to on.paint(gc)
    local id    = tonumber(expr.id)
    local fname = 'f'..id

    math.eval('Define '..fname..'(x)='..expr.func)
    points[id] = {}
    local fplot = points[id]

    -- plot points from -100 to 100
    for i = -100, 100, 1 do

        -- controls zoom
        local x = i / zoom

        -- approximate is used from solving fractions
        local res, e = math.evalStr('approx('..fname..'('..x..'))')

        -- fixes negative number bug
        -- calculator's '-' is different from ascii(45)
        if res == nil then
            res = 0
        elseif tonumber(res) == nil then
            res = 0 - math.eval('abs('..res..')')
        else
            res = tonumber(res)
        end

        -- if no error
        if type(e) ~= 'number' then
            local y  = res
            local lx = origin[1] + (x * 25)/2
            local ly = origin[2] + (-y * 25)/2
            table.insert(fplot, lx)
            table.insert(fplot, ly)
        end

    end

    window.invalidate()
end

function on.construction()

    -- refresh at 60 frames/second
    on:timer(1/60)
end

function on.paint(gc)

    -- draws the ui
    if var.recall('areadisp') and var.recall('region') then
        local area = string.format('area: %d', var.recall('region'))
        gc:drawString(area, 10, 60)
    end

    -- define
    for i = 1, #var.list() do
        local val = var.list()[i]
        if string.find(val, 'func') and var.recall(val) ~= '' or val == 'func1' then
            local id = string.sub(val, string.find(val, '%d+'))
            local func = var.recall(val)
            local dispf = string.format('f%d(x)=', id)
            gc:drawString(dispf, 10, 10 + fontsize * id)
            gc:drawString(func, 50, 10 + fontsize * id)
        end
    end

    for i, key in ipairs(orientation) do
        local val = var.recall(key) or 0
        local dispv = string.format('%s is %d', key, val)
        gc:drawString(dispv, 100, 10 + 10 * i)
    end

    -- graph
    -- x and y axis
    gc:drawLine(x.x, x.y, x.dx, x.dy)
    gc:drawLine(y.x, y.y, y.dx, y.dy)

    gc:drawString(table.concat(functions, ', '), 100, 60)

    if var.recall('test') then
        gc:drawString(var.recall('test'), 10, 80)
    end
    --gc:drawString(var.recall('ypos'), 50, 60)
    --gc:drawString(var.recall('xpos'), 70, 60)

    -- safe way to plot points
    for i = 1, #points do
        pcall(function()
            if unexpected_condition then end
            gc:drawPolyLine(points[i])
            window.invalidate()
        end)
    end
end

function on.enterKey()
    -- integrates defined functions on enter key press
    accumulatef()

    -- obtain range
    if not var.recall('a') or not var.recall('b') then
        var.store('a', ipointpairs[1][1])
        var.store('b', ipointpairs[1][2])
    end

    -- sort functions in ascending order
    sortf()

    for i = 1, #functions do
        -- stop at last function
        if functions[i] == nil or opts['func'..i] == nil then
            break
        end

        local val = opts['func'..i]

        -- get intersection points
        intersection()

        -- if function is defined, graph it
        if var.recall('func'..i) ~= '' then
            graph(val)
        end

        -- obtain region to integrate
        if i > 1 then
            local copy = opts.region
            if copy ~= '' and copy then
                copy = copy..'-'
                opts.region = math.evalStr(copy..val.func)
            elseif not copy then
                copy = ''
                opts.region = 'undef'
            end
        end
    end

    -- integrate obtained region
    local a = var.recall('a')
    local b = var.recall('b')
    local dispint = string.format('integral(%s, x, %d, %d)',
                                  opts.region, a, b)

    var.store('region', math.evalStr(dispint))

    window:invalidate()  
end

function on.arrowKey(key)
    -- make call to ui controller
    navigate(key)
end

function on.charIn(key)
    -- add to defined function
    local ypos = var.recall('ypos')
    local xpos = var.recall('xpos')
    if xpos == 1 then
        local oldfunc = var.recall('func'..ypos) or ''
        local dispf = string.format('func%d', ypos)
        var.store(dispf, oldfunc..key)
    elseif xpos == 2 then
        -- a, b (optional)
        -- axis of rotation
        local res = orientation[ypos] or ''
        local val = (var.recall(res) or '')..key
        var.store(res, val)
    end
    window:invalidate()
end

function on.timer()
    -- refresh the screen
    window:invalidate()
end
