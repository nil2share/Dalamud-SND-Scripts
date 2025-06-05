-- FFXIV Navigation Script for SomethingNeedDoing
-- 
-- Created by: Nil
-- Version: 1.0.1
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

-- Function to check if player has a target
local function hasTarget()
    return GetTargetName() ~= nil and GetTargetName() ~= ""
end

-- Function to get distance to current target
local function getTargetDistance()
    if hasTarget() then
        return GetDistanceToTarget()
    end
    return 999 -- Return high value if no target
end

-- Function to check if target is within acceptable range
local function isTargetInRange(maxDistance)
    maxDistance = maxDistance or 10 -- Default to 10 if not specified
    return hasTarget() and getTargetDistance() <= maxDistance
end

-- Function to target closest attackable enemy and attack
local function targetAndAttack()
    if not hasTarget() then
        yield("/targetenemy") -- Target closest enemy
        yield("/wait 0.5") -- Small delay to ensure targeting completes
        
        if isTargetInRange(10) then
            -- Move to the target's actual position using vnavmesh
            yield("/vnavmesh moveto")
            yield("/wait 1") -- Wait for movement to start
            yield("/automove on") -- Enable auto-attack by moving toward target
        elseif hasTarget() then
            -- Target is too far, clear it by targeting self
            yield("/target <me>")
        end
    end
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
    yield("/vnav stop") -- Call twice to ensure it stops
end

-- Function to wait until out of combat
local function waitForCombatEnd()
    while isInCombat() do
        -- Ensure we stay stopped while in combat
        if GetCharacterCondition(27) then -- If still moving
            stopMovement()
        end
        
        -- Try to target and attack if no target
        targetAndAttack()
        
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
        
        -- Wait for navigation to complete or until target/combat found
        local targetFound = false
        local loopCount = 0
        while not targetFound do -- Keep checking until target found or destination reached
            -- Break if we're no longer moving AND no target found (reached destination)
            if not GetCharacterCondition(27) then
                break
            end
            
            loopCount = loopCount + 1
            -- Constantly check for targets while moving
            if not hasTarget() then
                yield("/targetenemy")
            end
            
            -- If we found a target, immediately stop everything
            if hasTarget() then
                -- Check if target is within acceptable range
                local distance = getTargetDistance()
                if distance <= 10 then
                    targetFound = true
                    yield("/echo Target found at distance " .. string.format("%.1f", distance) .. "! Force stopping navigation...")
                    -- Aggressive stop commands
                    yield("/vnav stop")
                    yield("/automove off")
                    yield("/vnav stop")
                    yield("/wait 1") -- Longer wait to ensure full stop
                    break -- Force exit immediately
                else
                    -- Target too far, ignore it and clear target by targeting self
                    yield("/echo Target too far (" .. string.format("%.1f", distance) .. "), ignoring...")
                    yield("/target <me>")
                end
            elseif isInCombat() then
                yield("/echo Combat detected! Stopping all movement...")
                stopMovement()
                waitForCombatEnd()
                yield("/echo Combat ended, resuming navigation...")
                navigateToPoint(targetPoint)
            end
            
            yield("/wait 0.1")
            
            -- Safety check - if we've been in this loop too long, something's wrong
            if loopCount > 1000 then
                yield("/echo Navigation loop timeout, breaking...")
                break
            end
        end
        
        -- Handle target engagement after breaking out of movement loop
        if targetFound and isTargetInRange(10) then
            yield("/echo Moving to engage target...")
            yield("/vnavmesh moveto") -- Move to target's position
            yield("/wait 1")
            yield("/automove on") -- Enable auto-attack movement
            -- Wait for combat to start or target to be lost
            while hasTarget() and not isInCombat() do
                yield("/wait 0.1")
            end
            -- If combat started, wait for it to end
            if isInCombat() then
                waitForCombatEnd()
            end
            yield("/echo Combat ended, resuming navigation...")
            -- Resume navigation to the original point
            navigateToPoint(targetPoint)
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
                else
                    -- Check for nearby enemies to engage during wait
                    targetAndAttack()
                end
                yield("/wait 0.5") -- Slightly longer delay when checking for targets
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
