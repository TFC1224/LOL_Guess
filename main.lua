local players = require("players")

-- 游戏状态
local answer, guesses, currentGuess = {}, {}, ""
local resultMessage, compositionText = "", ""
local font, font_large, scrollOffset = nil, nil, 0
local surrendered, gameOver = false, false
local taunts = {
    "就这水平？建议回家养猪！",  
    "建议删除游戏！",        
    "这都猜不中，不如玩扫雷！",  
    "网管都救不了你的啊",    
    "人机看都直呼专业！",    
    "真的是盲猜啊!"    
}
local suggestions = {}  -- 匹配的候选项
local selectedIndex = 1  -- 当前选中项
local scrollOffsetSuggestions = 0  -- 候选列表滚动偏移
local maxSuggestionsVisible = 5    -- 最大可见提示数量
local hintText = {
    "操作提示：",
    "   必须英文输入法",
    "   不区分大小写",
    "   ↑/↓ 选择候选",
    "   空格 确认选择",
    "   回车 提交答案",
    "   退格 删除字符"
}

local watermark = "Created by DUT Maple"


function love.load()
    love.window.setMode(1440, 800, {resizable = true})
    love.window.setTitle("LPL选手猜猜乐")
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- 动态字体加载
    local fontPaths = {
        "fonts/msyh.ttc",
        "C:/Windows/Fonts/msyh.ttc",
        "wqy-microhei.ttc"
    }
    for _, path in ipairs(fontPaths) do
        if love.filesystem.getInfo(path) then
            font = love.graphics.newFont(path, math.floor(24 * love.graphics.getDPIScale()))
            font_large = love.graphics.newFont(path, math.floor(36 * love.graphics.getDPIScale()))
            break
        end
    end
    if not font then
        local baseSize = math.floor(24 * love.graphics.getDPIScale())
        font = love.graphics.newFont(baseSize)
        font_large = love.graphics.newFont(baseSize * 1.5)
    end
    love.graphics.setFont(font)

    math.randomseed(os.time())
    startNewGame()
end

function startNewGame()
    answer = players[math.random(#players)]
    guesses = {}
    currentGuess = ""
    resultMessage = ""
    scrollOffset = 0
    surrendered = false
    gameOver = false

    answer.metadata = {
        tagSet = {},
        teamSet = {},
        achievementSet = {}
    }
    for _, tag in ipairs(answer.tags) do answer.metadata.tagSet[tag] = true end
    for _, team in ipairs(answer.teams) do answer.metadata.teamSet[team] = true end
    for _, achv in ipairs(answer.achievements) do answer.metadata.achievementSet[achv] = true end
end

-- 输入处理
function love.textedited(text) compositionText = text end
function love.textinput(t)
    if #currentGuess < 12 and not gameOver and t:match("^[%a%d]$") then
        currentGuess = currentGuess .. t:lower()
        updateSuggestions()
        selectedIndex = 1
        scrollOffsetSuggestions = 0
    end
    compositionText = ""
end
function love.keypressed(key)
    if gameOver then return end
    
    if key == "backspace" then
        if compositionText ~= "" then
            compositionText = ""
        else
            currentGuess = currentGuess:sub(1, -2)
            updateSuggestions()
            selectedIndex = 1
            scrollOffsetSuggestions = 0
        end
    elseif key == "return" then
        processGuess()
        suggestions = {}
    elseif key == "up" then
        if #suggestions > 0 then
            selectedIndex = selectedIndex > 1 and selectedIndex - 1 or #suggestions
            -- 保持选中项在可视区域
            if selectedIndex <= scrollOffsetSuggestions then
                scrollOffsetSuggestions = math.max(0, selectedIndex - 1)
            end
        end
    elseif key == "down" then
        if #suggestions > 0 then
            selectedIndex = selectedIndex < #suggestions and selectedIndex + 1 or 1
            -- 保持选中项在可视区域
            if selectedIndex - scrollOffsetSuggestions > maxSuggestionsVisible then
                scrollOffsetSuggestions = math.min(#suggestions - maxSuggestionsVisible, scrollOffsetSuggestions + 1)
            end
        end
    elseif key == "space" then
        if #suggestions > 0 and selectedIndex <= #suggestions then
            currentGuess = suggestions[selectedIndex].name:lower()
            suggestions = {}
            selectedIndex = 1
        end
    end
end

function love.mousepressed(x, y)
    if gameOver then
        -- 调整按钮位置到窗口下方
        local winH = love.graphics.getHeight()
        local buttons = {
            {text = "再来一局", x = 1030, y = winH - 160, w=140, h=50},
            {text = "退出游戏", x = 1190, y = winH - 160, w=140, h=50}
        }
        for _, btn in ipairs(buttons) do
            if x > btn.x and x < btn.x+btn.w and y > btn.y and y < btn.y+btn.h then
                if btn.text == "再来一局" then
                    startNewGame()
                else
                    love.event.quit()
                end
            end
        end
    else
        -- 处理候选点击
        if #suggestions > 0 then
            local inputBoxX, inputBoxY = 40, 40
            local suggestionY = inputBoxY + 60  -- 在输入框下方显示
            local itemHeight = 30
            
            for i = scrollOffsetSuggestions + 1, math.min(scrollOffsetSuggestions + maxSuggestionsVisible, #suggestions) do
                local itemY = suggestionY + (i - scrollOffsetSuggestions - 1) * itemHeight
                if y > itemY and y < itemY + itemHeight then
                    currentGuess = suggestions[i].name:lower()
                    suggestions = {}
                    return
                end
            end
        end
        -- 处理投降按钮
        if x > 1340 and x < 1460 and y > 20 and y < 60 then
            surrendered = true
            gameOver = true
            resultMessage = "正确答案："..answer.name
                          
        end
    end
end

function love.wheelmoved(_, y)
    if #suggestions > maxSuggestionsVisible then
        local maxScroll = #suggestions - maxSuggestionsVisible
        scrollOffsetSuggestions = math.max(0, math.min(scrollOffsetSuggestions - y, maxScroll))
    end
    -- 保持原有历史记录滚动
    local maxScroll = math.max(#guesses*100 - (love.graphics.getHeight()-200), 0)
    scrollOffset = math.max(0, math.min(scrollOffset - y*40, maxScroll))
end

function updateSuggestions()
    suggestions = {}
    if currentGuess == "" then return end
    
    local inputLower = currentGuess:lower()
    for _, p in ipairs(players) do
        if p.name:lower():sub(1, #inputLower) == inputLower then
            table.insert(suggestions, p)
        end
    end
    -- 按名称长度排序
    table.sort(suggestions, function(a, b) 
        return a.name:len() < b.name:len() 
    end)
end
function processGuess()
    local found
    local inputName = currentGuess:lower()
    for _, p in ipairs(players) do
        if p.name:lower() == inputName then
            found = p
            break
        end
    end

    if found then
        local match = {
            position = found.position,
            status = found.status,
            commonTeams = {},
            commonTags = {},
            commonAchvs = {},
            positionMatch = found.position == answer.position,
            statusMatch = found.status == answer.status
        }

        for _, team in ipairs(found.teams) do
            if answer.metadata.teamSet[team] then table.insert(match.commonTeams, team) end
        end
        for _, tag in ipairs(found.tags) do
            if answer.metadata.tagSet[tag] then table.insert(match.commonTags, tag) end
        end
        for _, achv in ipairs(found.achievements) do
            if answer.metadata.achievementSet[achv] then table.insert(match.commonAchvs, achv) end
        end

        table.insert(guesses, {
            data = match,
            name = found.name,
            correct = found == answer
        })

        if found == answer then
            resultMessage = "恭喜你 答对了！"
            gameOver = true
        else
            -- 添加随机嘲讽语句
            resultMessage = taunts[math.random(#taunts)]
            scrollOffset = math.max(#guesses*100 - (love.graphics.getHeight()-100), 0)
        end
        currentGuess = ""
    else
        resultMessage = "选手不存在！"
    end
end


function love.draw()
    -- 原有绘制代码...
    local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.clear(0.1, 0.1, 0.2)
    
    -- 输入区（动态布局）
    if not gameOver then
        local inputBoxW = math.min(500, winW * 0.4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", 40, 40, inputBoxW, 50)
        
        -- 自动缩放文本
        local displayText = currentGuess .. compositionText
        local textWidth = font:getWidth(displayText)
        local maxTextWidth = inputBoxW - 120
        if textWidth > maxTextWidth then
            love.graphics.setScissor(160, 40, maxTextWidth, 50)
        end
        love.graphics.printf("输入ID：", 45, 55, inputBoxW - 10, "left")
        love.graphics.setColor(0.9, 0.9, 0.4)
        love.graphics.printf(displayText, 160, 55, maxTextWidth, "left")
        love.graphics.setScissor()
        
        -- 投降按钮
        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.rectangle("fill", winW - 140, 20, 120, 40)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("投降", winW - 140, 30, 120, "center")
    end

    -- 结果显示（动态布局）
    if resultMessage ~= "" then
        love.graphics.setFont(font_large)
        love.graphics.setColor(1, 0.8, 0)
        local resultX = math.max(winW - 400, 600)
        love.graphics.printf(resultMessage, resultX, 100, 350, "left")
        
        if gameOver then
            -- 正确答案详情（自动换行）
            love.graphics.setFont(font)
            love.graphics.setColor(0.6, 1, 0.6)
            local detailY = 180
            local detailTexts = {
                "位置："..answer.position,
                "状态："..answer.status,
                "战队经历："..table.concat(answer.teams, ","),
                "\n标签："..table.concat(answer.tags, ","),
                "\n成就："..table.concat(answer.achievements, ",")
            }
            for _, text in ipairs(detailTexts) do
                love.graphics.printf(text, resultX, detailY, 350, "left")
                detailY = detailY + font:getHeight() * 1.5
            end
            
            -- 操作按钮（固定在窗口下方）
            local btnY = winH - 160
            love.graphics.setColor(0.2, 0.8, 0.2)
            love.graphics.rectangle("fill", 1030, btnY, 140, 50)
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.rectangle("fill", 1190, btnY, 140, 50)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("再来一局", 1030, btnY + 15, 140, "center")
            love.graphics.printf("退出游戏", 1190, btnY + 15, 140, "center")
        end
        love.graphics.setFont(font)
    end

    -- 历史记录区（动态高度）
    local scrollAreaH = winH - 200
    love.graphics.setScissor(40, 120, winW * 0.6, scrollAreaH)
    local y = 120 - scrollOffset
    for i, g in ipairs(guesses) do
        drawGuess(g, y, i, winW)
        y = y + 100
    end
    love.graphics.setScissor()
    
    -- 输入提示框
    if #suggestions > 0 and not gameOver then
        local inputBoxX, inputBoxY = 40, 40
        local suggestionY = inputBoxY + 60
        local itemHeight = 30
        local boxWidth = 300
        
        -- 背景框
        love.graphics.setColor(0.2, 0.2, 0.3)
        love.graphics.rectangle("fill", inputBoxX, suggestionY, boxWidth, 
            math.min(maxSuggestionsVisible, #suggestions) * itemHeight)
        
        -- 候选项目
        love.graphics.setColor(1, 1, 1)
        for i = scrollOffsetSuggestions + 1, math.min(scrollOffsetSuggestions + maxSuggestionsVisible, #suggestions) do
            local itemY = suggestionY + (i - scrollOffsetSuggestions - 1) * itemHeight
            -- 高亮选中项
            if i == selectedIndex then
                love.graphics.setColor(0.3, 0.3, 0.5)
                love.graphics.rectangle("fill", inputBoxX, itemY, boxWidth, itemHeight)
            end
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(suggestions[i].name, inputBoxX + 10, itemY + 5, boxWidth - 20, "left")
        end
    end
    -- 绘制操作提示
    local hintX = love.graphics.getWidth() - 650
    local hintY = 30
    love.graphics.setColor(0.05, 0.05, 0.1, 0.9)
    love.graphics.rectangle("fill", hintX - 10, hintY - 10, 230, 200, 5, 5)
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    for i, text in ipairs(hintText) do
        love.graphics.printf(text, hintX, hintY + (i-1)*25, 200, "left")
end


-- 绘制水印
local watermarkFont = love.graphics.newFont(30)
love.graphics.setFont(watermarkFont)
love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
local wmX = love.graphics.getWidth() - watermarkFont:getWidth(watermark) - 20
local wmY = love.graphics.getHeight() - 45
love.graphics.print(watermark, wmX, wmY)
love.graphics.setFont(font) -- 恢复默认字体
end

function drawGuess(guess, y, idx, winW)
    -- 基础信息
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("#"..idx, 45, y+5, 60, "left")

    -- 选手名（自动缩放）
    love.graphics.setColor(guess.correct and {0,1,0} or {1,0.3,0.3})
    local nameWidth = font:getWidth(guess.name)
    if nameWidth > 180 then
        love.graphics.printf(guess.name, 110, y+5, 180, "left")
    else
        love.graphics.printf(guess.name, 110, y+5, 200, "left")
    end

    -- 位置/状态信息
    local infoY = y + 35
    local function drawMatch(text, match)
        love.graphics.setColor(match and {0,1,0} or {1,0,0})
        love.graphics.printf(text, 110, infoY, 200, "left")
        infoY = infoY + 30
    end
    drawMatch("位置："..guess.data.position, guess.data.positionMatch)
    drawMatch("状态："..guess.data.status, guess.data.statusMatch)

    -- 动态调整右侧内容宽度
    local rightContentW = winW * 0.6 - 400
    local rightX = 320

    -- 队伍信息（自动换行）
    love.graphics.setColor(0.8, 0.5, 1)
    local teamsText = #guess.data.commonTeams > 0 and table.concat(guess.data.commonTeams, ",") or "无共同队伍"
    love.graphics.printf("战队经历："..teamsText, rightX, y+5, rightContentW, "left")

    -- 标签信息
    love.graphics.setColor(0.5, 1, 0.5)
    local tagsText = #guess.data.commonTags > 0 and table.concat(guess.data.commonTags, ",") or "无共同标签"
    love.graphics.printf("标签："..tagsText, rightX, y+35, rightContentW, "left")

    -- 成就信息
    love.graphics.setColor(1, 0.8, 0.5)
    local achvText = #guess.data.commonAchvs > 0 and table.concat(guess.data.commonAchvs, "|") or "无共同成就"
    love.graphics.printf("成就："..achvText, rightX, y+65, rightContentW, "left")
end
