-- Copyright (c) 2024 Christopher Eggison
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import "CoreLibs/animator"

local gfx = playdate.graphics

local heldButtons = {}

-- Graphics
local images = {
    PLAYER = gfx.image.new("GameAssets/player2.png"),
    MOUNTAINS = gfx.image.new("GameAssets/mountains.png"),
    TREES = gfx.image.new("GameAssets/trees.png"),
    BUTTONS = gfx.imagetable.new("GameAssets/directions"),
    BUTTON_PROMPT = gfx.image.new("GameAssets/button_prompt.png"),
    CALLOUTS = gfx.imagetable.new("GameAssets/callouts"),
    JUMPPAD = gfx.image.new("GameAssets/jump_rock.png"),
    INTRO = gfx.imagetable.new("GameAssets/introtext"),
    TITLE_BG = gfx.image.new("GameAssets/title_sky.png"),
    TITLE_LOGO = gfx.image.new("GameAssets/title_logo.png"),
    TITLE_HERO = gfx.image.new("GameAssets/title_hero.png"),
    TITLE_PROMPT = gfx.image.new("GameAssets/title_prompt.png"),
    RESULT_TEXT = gfx.image.new("GameAssets/result_text.png")
}

-- Available game states
local gameStates = {
    INTRO = 1, -- Showing the intro text crawl
    TITLE = 2, -- Showing the title screen
    GAME = 3,  -- In-game
    RESULTS = 4 -- Game Over screen
}

-- Available player states: States that the player object will be in at any given time
local playerStates = {
    IDLE = 1,       -- Player is currently cruising down the mountain
    JUMPING = 2,    -- The player is currently ascending into the air
    LANDING = 3     -- The player is landing and button inputs will be accepted
}

-- The Player object
local player = {
    STATE = playerStates.IDLE,  -- The default state of the player
    DIRECTION = 1,              -- The direction the player is facing (unused)
    WIDTH = 74,                 -- The width of the player graphic
    HEIGHT = 74,                -- The height of the player graphic
    ELEVATION = 0,              -- The current elevation from the ground
    X = 30,                     -- The player's X position on-screen
    Y = 75                      -- The player's Y position on-screen
}

-- The Jump Pad object
local jumpPad = {
    WIDTH = 50,                 -- The width of the jump pad graphic
    HEIGHT = 50,                -- The height of the jump pad graphic
    X = 0,                      -- The pad's X position on screen
    Y = 0,                      -- The pad's Y position on screen
    PROGRESS = 2                -- Unused
}

-- The path the jump pad takes
-- The 0 index informs the game where the starting position should be
-- The 1 index informs the game where the ending position should be
-- As time progresses, the 0 x,y will progress towards the 1 x,y
local jumpPadPath = {
    {X = 0, Y = 120},
    {X = 320, Y = 240}
}

-- A pool of buttons that can be selected for trick inputs
-- Three of these buttons will be selected when the user jumps into the air
local buttons = {
    playdate.kButtonUp,
    playdate.kButtonRight,
    playdate.kButtonDown,
    playdate.kButtonLeft
}

-- The current game state
local gameState = gameStates.INTRO

-- Intro Flags
local introTextAnimator = gfx.animator.new(3000, 0, 100)
local introTextIndex = 1

-- Game Flags
local gameIntroFinished = false

-- The total duration of the in-game session in milliseconds
local gameDuration = 90000

-- Background animators, controls how the background progesses
local backgroundMountainAnimator = gfx.animator.new(gameDuration, 0, -100)
local backgroundTreesAnimatorX = gfx.animator.new(gameDuration, 0, -100)
local backgroundTreesAnimatorY = gfx.animator.new(gameDuration, 0, -129)

-- Player & Jump Pad animators
local foregroundAnimator = gfx.animator.new(3000, 100, 0)
local playerJumpAnimator = gfx.animator.new(0, 0, 100)
local jumpPadAnimator = gfx.animator.new(100, 150, 150)

-- Unused
local trickCooldownAnimator = gfx.animator.new(200, 100, 0)

local trickButtons = {0,0,0}    -- Currently selected trick buttons
local trickButtonIndex = 1      -- The current trick being evaluated
local trickButtonRaised = true  -- Trying to catch the rising edge of the button input
local trickCalloutIndex = 1     -- The "success" message to be displayed when a trick succeeds

-- The current game score
local score = 0

function playdate.update()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)

    if gameState == gameStates.INTRO then
        introUpdate()
    elseif gameState == gameStates.TITLE then
        titleUpdate()
    elseif gameState == gameStates.GAME then
        gameUpdate()
    elseif gameState == gameStates.RESULTS then
        resultUpdate()
    end

    --playdate.drawFPS(0,0)
end

function introUpdate()
    if introTextAnimator:ended() then
        introTextIndex = introTextIndex + 1
        introTextAnimator:reset()
    end

    if introTextIndex > 5 then
        gameState = gameStates.TITLE
    end
    
    if introTextIndex >= 4 then
        if introTextIndex >= 4 then
            images.INTRO:getImage(4):draw(50, 80)
        end

        if introTextIndex >= 5 then
            images.INTRO:getImage(5):draw(50, 145)
        end
    elseif introTextIndex < 4 then
        if introTextIndex >= 1 then
            images.INTRO:getImage(1):draw(50, 60)
        end

        if introTextIndex >= 2 then
            images.INTRO:getImage(2):draw(50, 110)
        end

        if introTextIndex >= 3 then
            images.INTRO:getImage(3):draw(50, 160)
        end
    end

    if heldButtons[playdate.kButtonA] then
        gameState = gameStates.TITLE
    end
    
end

function titleUpdate()
    images.TITLE_BG:draw(-94, -120)
    images.TITLE_HERO:draw(210, 8)
    images.TITLE_LOGO:draw(30, 30)
    images.TITLE_PROMPT:draw(70, 170)

    if heldButtons[playdate.kButtonA] then
        initGame()
    end
end

function resultUpdate()
    images.RESULT_TEXT:draw(200 - (images.RESULT_TEXT.width / 2), 60)

    local scoreString = "Score: " .. score

    gfx.drawText(scoreString, 200 - (images.RESULT_TEXT.width / 2), 80 + images.RESULT_TEXT.height)

    if heldButtons[playdate.kButtonA] then
        initGame()
    end
end

function initGame()
    gameState = gameStates.GAME
    jumpPadAnimator = gfx.animator.new(100, 150, 150)
    foregroundAnimator:reset()
    playerJumpAnimator:reset()
    backgroundMountainAnimator:reset()
    backgroundTreesAnimatorX:reset()
    backgroundTreesAnimatorY:reset()
end

function gameUpdate()
    if backgroundMountainAnimator:ended() then
        gameState = gameStates.RESULTS
    end

    -- Do background drawing
    drawBackground()
    drawSlope()

    -- Update the Jump Pad before drawing
    jumpPadTick()

    -- Update player, draw player
    playerTick()
    drawPlayer()

    -- The jump pad should appear above the player.
    -- Do not worry about when the jump pad passes the player.
    -- The player will be clear of the jump pad graphic.
    drawJumpPad()

    -- When in the LANDING state, check inputs
    if player.STATE == playerStates.LANDING then
        checkTrickInput()
        drawTrickPrompt()
    end
end

function drawBackground()
    images.MOUNTAINS:draw(0, backgroundMountainAnimator:currentValue())
    images.TREES:draw(backgroundTreesAnimatorX:currentValue(), backgroundTreesAnimatorY:currentValue())
end

function drawSlope()
    local slopeSY = 88 + (88 * (foregroundAnimator:currentValue() / 100))
    local slopeEY = 240 + (240 * (foregroundAnimator:currentValue() / 100))
    if not gameIntroFinished then
        if foregroundAnimator:ended() then
            gameIntroFinished = true
            initJumpPad()
        end
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(0, slopeSY, 400, slopeEY, 0, slopeEY)

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(-2, slopeSY, 400, slopeEY + 2)
end

-- Resets the jump pad
function initJumpPad()
    jumpPadAnimator = gfx.animator.new(6000, -150, 200)
end

function playerTick()
    if player.STATE == playerStates.IDLE then
        -- Bit of a hacky way to detect when the player colides with a jump pad.
        if jumpPadAnimator:currentValue() > 80 and jumpPadAnimator:currentValue() < 90 then
            playerWillJump()
        end
    end if player.STATE == playerStates.JUMPING then
        if playerJumpAnimator:ended() then
            -- Player has reached the zienth of their jump, start landing
            playerWillLand()
        end
    end if player.STATE == playerStates.LANDING then
        if playerJumpAnimator:ended() then
            -- Player has landed, set state to idle
            player.STATE = playerStates.IDLE
        end
    end
end

function drawPlayer()
    local playerX = player.X
    local playerY = player.Y

    if player.STATE ~= playerStates.IDLE then
        playerY = playerY + playerJumpAnimator:currentValue()
    end

    -- Placeholder black square until graphics arrive
    --gfx.setColor(gfx.kColorBlack)
    --gfx.fillRect(playerX, playerY, player.WIDTH, player.HEIGHT)
    images.PLAYER:draw(playerX, playerY)
end

function playerWillJump()
    playerJumpAnimator:reset() -- Start a timer to block the user doing tricks
    playerJumpAnimator = gfx.animator.new(800, 0, -50, playdate.easingFunctions.outSine)
    initTrick() -- Setup trick input now
    player.STATE = playerStates.JUMPING
end

function playerWillLand()
    playerJumpAnimator = gfx.animator.new(1800, -50, 0, playdate.easingFunctions.inBack, 200)
    player.STATE = playerStates.LANDING
end

function jumpPadTick()
    local progress = 1 - (jumpPadAnimator:currentValue() / 100)

    --gfx.drawLine(jumpPadPath[1].X, jumpPadPath[1].Y, jumpPadPath[2].X, jumpPadPath[2].Y)

    jumpPad.X = jumpPadPath[1].X + ((jumpPadPath[2].X - jumpPadPath[1].X) * progress)
    jumpPad.Y = jumpPadPath[1].Y + ((jumpPadPath[2].Y - jumpPadPath[1].Y) * progress)

    if (jumpPadAnimator:ended()) then
        jumpPadAnimator:reset()
    end
end

function drawJumpPad()
    local useX = jumpPad.X - (jumpPad.WIDTH / 2)
    local useY = jumpPad.Y - (jumpPad.HEIGHT / 2)

    --gfx.fillRect(useX, useY, jumpPad.WIDTH, jumpPad.HEIGHT)
    images.JUMPPAD:draw(useX, useY)
end

function initTrick()
    trickButtonIndex = 1
    trickCalloutIndex = math.ceil(math.random() * 4)
    for i=1,3 do
        trickButtons[i] = math.ceil(math.random() * 4)
    end
end

function drawTrickPrompt()
    if trickButtonIndex < 4 then
        local promptX = 150
        local promptY = 75

        local buttonSize = 36

        local graphicY = promptY + 3

        images.BUTTON_PROMPT:draw(promptX, promptY)

        for i=1,3 do
            if trickButtonIndex <= i then
                local buttonGraphic = images.BUTTONS:getImage(trickButtons[i])
                if buttonGraphic ~= nil then
                    local graphicX = promptX + (buttonSize * (i - 1)) + 3
                    buttonGraphic:draw(graphicX, graphicY)
                end
            end
        end
    else 
        local calloutImage = images.CALLOUTS:getImage(trickCalloutIndex)
        calloutImage:draw(170, 80)
    end
end

function checkTrickInput()
    if trickButtonRaised then
        local expectedButton = buttons[trickButtons[trickButtonIndex]]
        if heldButtons[expectedButton] then
            trickButtonIndex = trickButtonIndex + 1
            if trickButtonIndex > 3 then
                score = score + 100
            end
        end
    end
end

function checkAnyButtonDown()
    trickButtonRaised = true
    if next(heldButtons) ~= nil then
        trickButtonRaised = false
    end
end

local inputHandler = {

    AButtonDown = function()
        heldButtons[playdate.kButtonA] = true
    end,

    AButtonUp = function()
        heldButtons[playdate.kButtonA] = nil
        checkAnyButtonDown()
    end,

    upButtonDown = function()
        heldButtons[playdate.kButtonUp] = true
    end,

    upButtonUp = function()
        heldButtons[playdate.kButtonUp] = nil
        checkAnyButtonDown()
    end,

    downButtonDown = function()
        heldButtons[playdate.kButtonDown] = true
    end,

    downButtonUp = function()
        heldButtons[playdate.kButtonDown] = nil
        checkAnyButtonDown()
    end,

    leftButtonDown = function()
        heldButtons[playdate.kButtonLeft] = true
    end,

    leftButtonUp = function()
        heldButtons[playdate.kButtonLeft] = nil
        checkAnyButtonDown()
    end,

    rightButtonDown = function()
        heldButtons[playdate.kButtonRight] = true
    end,

    rightButtonUp = function()
        heldButtons[playdate.kButtonRight] = nil
        checkAnyButtonDown()
    end

}
playdate.inputHandlers.push(inputHandler)