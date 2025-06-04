-- FFXIV Navigation Script for SomethingNeedDoing
-- 
-- Created by: Nil
--
-- DESCRIPTION:
-- This script automates navigation between 5 predefined points in FFXIV.
-- It will continuously cycle through the navigation points, waiting a random
-- amount of time (1-10 seconds) at each point. If combat is detected during
-- navigation or waiting, the script will halt all movement and wait for
-- combat to end before resuming. This is useful for farming routes, gathering
-- circuits, or any repetitive navigation tasks.
--
-- REQUIRED ADDONS:
-- - SomethingNeedDoing: Provides the Lua scripting environment
-- - vnavmesh: Handles pathfinding and navigation between coordinates
--
-- OPTIONAL ADDONS:
-- - Rotation Solver Reborn: Automates combat rotations during encounters
-- - BossMod Reborn: Provides enhanced combat mechanics and boss fight assistance
-- - Teleporter: Enables teleportation between distant points
-- - Lifestream: Allows world/datacenter travel if needed
--
-- SETUP:
-- 1. Install required addons (SomethingNeedDoing + vnavmesh)
-- 2. Replace the coordinates in navigationPoints with your desired locations
-- 3. Use /vnavmesh to get the navigationPoints
-- 4. Load, set to LUA, and run the script in SomethingNeedDoing
--
-- Navigates between 5 points with random waits and combat handling (add more points if you want them)

-- Define your 5 navigation points here (replace with actual coordinates)
local navigationPoints = {
    {x = 100.0, y = 50.0, z = 200.0}, -- Point 1
    {x = 150.0, y = 55.0, z = 180.0}, -- Point 2
    {x = 120.0, y = 60.0, z = 220.0}, -- Point 3
    {x = 90.0, y = 45.0, z = 190.0},  -- Point 4
    {x = 110.0, y = 52.0, z = 210.0}  -- Point 5
}

-- Current point index
local currentPoint = 1

-- Function to generate random wait time between 1 and 10000 milliseconds
local function getRandomWait()
    return math.random(1, 10000)
end

-- Function to check if player is in combat
local function isInCombat()
    return GetCharacterCondition(26) -- Combat condition flag
end

-- Function to navigate to a specific point
local function navigateToPoint(point)
    yield("/vnav moveto " .. point.x .. " " .. point.y .. " " .. point.z)
end

-- Function to stop all movement immediately
local function stopMovement()
    yield("/vnav stop")
    yield("/automove off")
end

-- Function to wait until out of combat
local function waitForCombatEnd()
    while isInCombat() do
        -- Ensure we stay stopped while in combat
        if GetCharacterCondition(27) then -- If still moving
            stopMovement()
        end
        yield("/wait 0.5")
    end
end

-- Main navigation loop
local function mainLoop()
    yield("/echo Starting navigation between 5 points...")
    
    while true do
        -- Check for combat before starting navigation
        if isInCombat() then
            yield("/echo In combat, waiting...")
            stopMovement()
            waitForCombatEnd()
        end
        
        -- Get current navigation point
        local targetPoint = navigationPoints[currentPoint]
        
        yield("/echo Navigating to point " .. currentPoint .. " (" .. targetPoint.x .. ", " .. targetPoint.y .. ", " .. targetPoint.z .. ")")
        
        -- Navigate to the point
        navigateToPoint(targetPoint)
        
        -- Wait for navigation to complete or until in combat
        while GetCharacterCondition(27) do -- While moving
            if isInCombat() then
                yield("/echo Combat detected! Stopping all movement...")
                stopMovement()
                waitForCombatEnd()
                yield("/echo Combat ended, resuming navigation...")
                -- Resume navigation to the same point
                navigateToPoint(targetPoint)
            else
                yield("/wait 0.1")
            end
        end
        
        -- Check if we reached the destination or if combat interrupted
        if not isInCombat() then
            yield("/echo Reached point " .. currentPoint)
            
            -- Generate random wait time
            local waitTime = getRandomWait()
            yield("/echo Waiting for " .. waitTime .. " milliseconds...")
            
            -- Wait with combat checking
            local waitStart = os.clock()
            local waitSeconds = waitTime / 1000
            while (os.clock() - waitStart) < waitSeconds do
                if isInCombat() then
                    yield("/echo Combat during wait period!")
                    stopMovement()
                    waitForCombatEnd()
                    -- Resume waiting from where we left off
                    waitStart = os.clock() - ((os.clock() - waitStart))
                end
                yield("/wait 0.1")
            end
            
            -- Move to next point
            currentPoint = currentPoint + 1
            if currentPoint > #navigationPoints then
                currentPoint = 1 -- Loop back to first point
                yield("/echo Completed full cycle, starting over...")
            end
        end
        
        -- Small delay to prevent script from running too fast
        yield("/wait 0.1")
    end
end

-- Initialize random seed
math.randomseed(os.time())

-- Start the main loop
mainLoop()
