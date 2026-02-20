love.graphics.setDefaultFilter("nearest", "nearest")

local gameState = "menu" 
local score, lives, highScore = 0, 5, 0
local isNight = false
local cycleTimer, difficulty, gameTime, cherryCount = 0, 1, 0, 0
local objects, imgs, snds = {}, {}, {}
local floatingTexts = {}
local font_big, font_small
local shakeTimer, spawnTimer = 0, 0
local lastDifficultyLevel = 1

function love.load()
    font_big = love.graphics.newFont(38)      
    font_small = love.graphics.newFont(18)
    
    -- تحميل الصور
    imgs.player = love.graphics.newImage("image/glass.png")
    imgs.bgDay = love.graphics.newImage("image/background.png")
    imgs.bgNight = love.graphics.newImage("image/night_background.png")
    imgs.life = love.graphics.newImage("image/life.png")
    imgs.btnPlay = love.graphics.newImage("image/button_play.png")
    imgs.btnInfo = love.graphics.newImage("image/button_info.png")
    imgs.btnPause = love.graphics.newImage("image/pause.png")
    imgs.ice = love.graphics.newImage("image/ice.png")
    imgs.cherry = love.graphics.newImage("image/cherry.png")
    imgs.coffee = love.graphics.newImage("image/coffee.png")

    -- تحميل واجهة التوقف
    imgs.uiPanel = love.graphics.newImage("image/ui.png")
    imgs.btnContinue = love.graphics.newImage("image/button_ continue.png")
    imgs.btnRestart = love.graphics.newImage("image/button_return.png")
    imgs.btnHome = love.graphics.newImage("image/button_back.png")

    -- تحميل الأصوات
    snds.ice = love.audio.newSource("Sound/pick_ice.wav", "static")
    snds.coffee = love.audio.newSource("Sound/pick_coffe.wav", "static")
    snds.cherry = love.audio.newSource("Sound/Pick_cherry.wav", "static")
    snds.loseLife = love.audio.newSource("Sound/lost_life.wav", "static")
    snds.levelUp = love.audio.newSource("Sound/level_up.wav", "static")
    snds.warning = love.audio.newSource("Sound/low_life.wav", "static")
    snds.click = love.audio.newSource("Sound/click.wav", "static")
    snds.night = love.audio.newSource("Sound/night.wav", "static")
    snds.day = love.audio.newSource("Sound/start_day.wav", "static")
    
    SW, SH = love.graphics.getDimensions()
    player = { 
        x = SW/2, y = SH - 160, 
        w = imgs.player:getWidth(), h = imgs.player:getHeight(),
        speed = 850 
    }
    loadHighScore()
end

function updateGame(dt)
    gameTime = gameTime + dt
    difficulty = 1 + (gameTime / 60) * 0.15 
    if math.floor(difficulty * 10) > math.floor(lastDifficultyLevel * 10) then
        snds.levelUp:play(); lastDifficultyLevel = difficulty
    end

    if shakeTimer > 0 then shakeTimer = shakeTimer - dt end
    
    local oldNight = isNight
    cycleTimer = cycleTimer + dt
    if cycleTimer > 20 then isNight = not isNight; cycleTimer = 0 end
    if oldNight ~= isNight then
        if isNight then snds.night:play() else snds.day:play() end
    end

    if love.mouse.isDown(1) then
        local mx = love.mouse.getX()
        if mx < SW/2 then player.x = player.x - player.speed * dt
        else player.x = player.x + player.speed * dt end
    end
    player.x = math.max(player.w/2, math.min(SW - player.w/2, player.x))

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnObject()
        spawnTimer = math.random(0.4, 1.2) / math.min(difficulty, 2) 
    end

    for i = #objects, 1, -1 do
        local o = objects[i]
        if not o.isFading then
            o.y, o.x = o.y + o.vy * dt, o.x + o.vx * dt
            local hitWidth = player.w * 0.6 
            if (o.x > player.x - hitWidth/2) and (o.x < player.x + hitWidth/2) and 
               (o.y + o.h/2 > player.y) and (o.y < player.y + 30) then 
                o.isFading = true; processScore(o)
            end
        else
            o.x = o.x + (player.x - o.x) * 15 * dt
            o.y = o.y + (player.y + 40 - o.y) * 15 * dt
            o.opacity = o.opacity - dt * 8
            if o.opacity <= 0 then table.remove(objects, i) end
        end

        if o.y > SH then
            if not isNight and o.type == "ice" and not o.isFading then
                lives = lives - 1; shakeTimer = 0.2; snds.loseLife:play()
                if lives == 1 then snds.warning:play() end
                if lives <= 0 then saveScore(); gameState = "menu" end
            end
            table.remove(objects, i)
        end
    end

    for i = #floatingTexts, 1, -1 do
        local t = floatingTexts[i]
        t.y, t.timer = t.y - 60 * dt, t.timer - dt
        if t.timer <= 0 then table.remove(floatingTexts, i) end
    end
end

function processScore(o)
    local col = {1, 1, 1}
    if o.type == "coffee" then 
        score = math.max(0, score - 20); col = {1, 0.2, 0.2}; snds.coffee:stop(); snds.coffee:play()
    elseif o.type == "cherry" then
        score = score + 25; cherryCount = cherryCount + 1; col = {0.2, 1, 0.2}; snds.cherry:stop(); snds.cherry:play()
        if cherryCount >= 4 then lives = math.min(lives + 1, 5); cherryCount = 0 end
    else 
        score = score + 5; col = {0.4, 0.8, 1}; snds.ice:stop(); snds.ice:play()
    end
    table.insert(floatingTexts, { text = (o.points > 0 and "+" or "") .. o.points, x = player.x - 20, y = player.y - 30, timer = 1.2, color = col })
end

function love.draw()
    if gameState == "play" and shakeTimer > 0 then love.graphics.translate(math.random(-6, 6), math.random(-6, 6)) end
    local bg = isNight and imgs.bgNight or imgs.bgDay
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, 0, 0, 0, SW / bg:getWidth(), SH / bg:getHeight())

    if gameState == "play" or gameState == "pause" then
        love.graphics.draw(imgs.player, player.x, player.y, 0, 1, 1, player.w/2, 0)
        for _, o in ipairs(objects) do
            love.graphics.setColor(1, 1, 1, o.opacity)
            love.graphics.draw(o.img, o.x, o.y, o.angle, 1, 1, o.w/2, o.h/2)
        end
        love.graphics.setColor(1, 1, 1, 1)
        for _, t in ipairs(floatingTexts) do
            love.graphics.setFont(font_small)
            love.graphics.setColor(0, 0, 0, t.timer); love.graphics.print(t.text, t.x + 2, t.y + 2)
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], t.timer); love.graphics.print(t.text, t.x, t.y)
        end
        drawUI()
        if gameState == "pause" then drawPauseMenu() end
    elseif gameState == "menu" then drawMenu()
    elseif gameState == "info" then drawInfo() end
end

function drawUI()
    love.graphics.setColor(0, 0, 0, 0.5); love.graphics.rectangle("fill", 15, 15, 200, 150, 12, 12)
    love.graphics.setColor(1, 1, 1)
    for i = 1, 5 do
        local a = (i <= lives) and 1 or 0.25
        love.graphics.setColor(1, 1, 1, a); love.graphics.draw(imgs.life, 25 + (i-1)*35, 30, 0, 1.3, 1.3) 
    end
    love.graphics.setColor(1, 1, 1, 1); love.graphics.setFont(font_small)
    love.graphics.print("SCORE: " .. score, 30, 65); love.graphics.print("BEST: " .. highScore, 30, 90); love.graphics.print("CHERRY: " .. cherryCount .. "/4", 30, 115)
    love.graphics.draw(imgs.btnPause, SW - 80, 20, 0, 60 / imgs.btnPause:getWidth(), 60 / imgs.btnPause:getHeight())
end

function drawPauseMenu()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, SW, SH)
    
    love.graphics.setColor(1, 1, 1, 1)
    local uiScale, btnScale = 4, 2.5
    local uiX, uiY = SW/2, SH/2
    local uiH = imgs.uiPanel:getHeight() * uiScale
    
    love.graphics.draw(imgs.uiPanel, uiX, uiY, 0, uiScale, uiScale, imgs.uiPanel:getWidth()/2, imgs.uiPanel:getHeight()/2)
    
    local spacing = 80 
    local btnY = uiY + (uiH * 0.25) 
    
    love.graphics.draw(imgs.btnHome, uiX - spacing, btnY, 0, btnScale, btnScale, imgs.btnHome:getWidth()/2, imgs.btnHome:getHeight()/2)
    love.graphics.draw(imgs.btnRestart, uiX, btnY, 0, btnScale, btnScale, imgs.btnRestart:getWidth()/2, imgs.btnRestart:getHeight()/2)
    love.graphics.draw(imgs.btnContinue, uiX + spacing, btnY, 0, btnScale, btnScale, imgs.btnContinue:getWidth()/2, imgs.btnContinue:getHeight()/2)
end

function love.mousereleased(x, y, button)
    if button == 1 then
        if gameState == "menu" then
            if math.abs(x - SW/2) < 100 then
                snds.click:play()
                if y > SH*0.45 and y < SH*0.55 then resetGame(); gameState = "play"
                elseif y > SH*0.6 and y < SH*0.7 then gameState = "info" end
            end
        elseif gameState == "info" then snds.click:play(); gameState = "menu"
        elseif gameState == "play" then 
            if x > SW - 90 and y < 90 then snds.click:play(); gameState = "pause" end
        elseif gameState == "pause" then 
            local uiY = SH/2
            local btnY = uiY + (imgs.uiPanel:getHeight() * 8 * 0.15)
            local range = 50 
            
            if math.abs(y - btnY) < 60 then
                snds.click:play()
                if math.abs(x - (SW/2 - 80)) < range then gameState = "menu"
                elseif math.abs(x - (SW/2)) < range then resetGame(); gameState = "play"
                elseif math.abs(x - (SW/2 + 80)) < range then gameState = "play" end
            end
        end
    end
end

function spawnObject()
    local difficultyScale = math.min(1 + (gameTime / 60) * 0.2, 2.2)
    local oType = isNight and "coffee" or (math.random() < 0.07 and "cherry" or (math.random() < 0.25 and "coffee" or "ice"))
    local o = {
        type = oType, x = math.random(50, SW-50), y = -60,
        vx = math.random(-20, 20), vy = (150 + math.random(20, 50)) * difficultyScale,      
        opacity = 1, isFading = false, angle = math.random(0, 360), rotSpeed = math.random(-2, 2)
    }
    if o.type == "cherry" then o.img = imgs.cherry; o.points = 25
    elseif o.type == "coffee" then o.img = imgs.coffee; o.points = -20
    else o.img = imgs.ice; o.points = 5 end
    o.w, o.h = o.img:getWidth(), o.img:getHeight()
    table.insert(objects, o)
end

function love.update(dt) if gameState == "play" then updateGame(dt) end end
function loadHighScore() if love.filesystem.getInfo("highscore.txt") then highScore = tonumber(love.filesystem.read("highscore.txt")) or 0 end end
function saveScore() if score > highScore then highScore = score; love.filesystem.write("highscore.txt", tostring(highScore)) end end
function resetGame() 
    score, lives, cherryCount, gameTime, cycleTimer, objects, floatingTexts, difficulty, shakeTimer, isNight, spawnTimer, lastDifficultyLevel = 0, 5, 0, 0, 0, {}, {}, 1, 0, false, 0, 1 
end

function drawInfo()
    love.graphics.setColor(0,0,0,0.9); love.graphics.rectangle("fill", 30, SH*0.25, SW-60, SH*0.5, 25, 25)
    love.graphics.setColor(1,1,1); love.graphics.setFont(font_small)
    love.graphics.printf("DEVELOPER\nMamdouh Ibrahim\n\n- UI Scaled & Centered\n- Horizontal Buttons\n\n(Tap to Return)", 40, SH*0.35, SW-80, "center")
end

function drawMenu()
    local btnW = imgs.btnPlay:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.btnPlay, SW/2, SH*0.5, 0, 1, 1, btnW/2, imgs.btnPlay:getHeight()/2)
    love.graphics.draw(imgs.btnInfo, SW/2, SH*0.65, 0, 1, 1, btnW/2, imgs.btnInfo:getHeight()/2)
    love.graphics.setFont(font_big); love.graphics.printf("BEST SCORE\n" .. highScore, 0, SH*0.2, SW, "center")
end