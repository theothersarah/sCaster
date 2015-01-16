-- This table is returned when this file is passed to require
local scaster = {}

-- This holds data about the current map
local map = {
	loaded = false
}

-- This holds data about the screen resolution
local screen = {}

screen.width, screen.height = love.graphics.getDimensions()

screen.center =  {
	x = screen.width/2,
	y = screen.height/2
}

-- Holds some renderer settings and constants that only need to be calculated once
local renderer = {
	textured = false, -- Set to true to use textures
	fov = math.pi / 3
}

renderer.angleIncrement = renderer.fov / screen.width
renderer.perspectivePlaneDistance = screen.center.x / math.tan(renderer.fov/2)

-- Holds texture data
local texture = {
	width = 512,
	height = 512,
	images = {},
	quads = {}
}

-- Holds sky information
local sky = {
}

function scaster.load(filename)
	-- If no filename was provided then randomize it
	if filename == nil then
		--
		map.size = 512 -- Number of tiles (x and y directions)
		map.gridWidth = 64 -- Unit width of each tile
		map.wallHeight = 64 -- Height of each wall
		map.fogDistance = 32*64 -- Distance in units before the fog intensity is at maximum

		-- Two dimensional table (indexed from 1 to map.size in both dimensions) that holds the
		-- walls and textures
		map.data = {}

		-- Insert random data
		for i = 1, map.size, 1 do
			map.data[i] = {}

			for j = 1, map.size, 1 do
					map.data[i][j] = {
						wall = math.random() < 0.25,
						texture = math.ceil(3*math.random())
					}
			end
		end

		-- Let's have some textures
		if (renderer.textured) then
			-- Create an array of pre-calculated texture co-ordinates 
			for i= 0, texture.width - 1, 1 do
				texture.quads[i] = love.graphics.newQuad(i, 0, 1, texture.height, texture.width, texture.height)
			end	
			
			texture.images[1] = love.graphics.newImage("brick1.png")
			texture.images[2] = love.graphics.newImage("brick2.png")
			texture.images[3] = love.graphics.newImage("brick3.png")
		
			-- Skybox
			sky.image = love.graphics.newImage("city.png")
			sky.quad = love.graphics.newQuad(0, 0, 1024, 768, 1024, 768)
		end
	else
		-- Map loading code can go here
		
		-- This should be done in the event of a failure in loading or parsing
		map.loaded = true
		return false
	end
	
	-- Loading successful
	map.loaded = true
	return true
end

-- Casts out a single ray from point (x, y) at angle phi
local function rayCast(x, y, phi)
	-- This table is loaded with collision information and returned
	local collision = {}
	
	-- Calculate current map tile co-ordinate from the position
	local mapCoord = {
		x = math.floor(x/map.gridWidth) + 1,
		y = math.floor(y/map.gridWidth) + 1
	}
	
	-- Get the player's position within the current tile
	local tilePos = {
		x = x % map.gridWidth,
		y = y % map.gridWidth
	}
	
	-- Determine the direction of the ray on a Cartesian plane where "up" and "left" are positive
	local sign = {
		x = math.sign(math.cos(phi)),
		y = math.sign(math.sin(phi))
	}
	
	-- Ugly hack where the angle phi is adjusted to the angle between the ray and the x axis
	-- TODO: Removing this renders the distances properly but the texture coordinates are all
	-- jacked up, so figure out why that's the case so we can get rid of this crap
	local theta
	
	if phi > 2 * math.pi then
		theta = phi - 2*math.pi
	elseif phi > 1.5 * math.pi then
		theta = 2*math.pi - phi
	elseif phi > math.pi then
		theta = phi - math.pi
	elseif phi > math.pi/2 then
		theta = math.pi - phi
	elseif phi < 0 then
		theta = math.abs(phi)
	else
		theta = phi
	end
	
	-- Step size when looking for a vertical wall collision
	local stepV = {
		x = sign.x * map.gridWidth,
		y = sign.y * map.gridWidth * math.tan(theta)
	}
	
	stepV.distance = math.dist(0, 0, stepV.x, stepV.y)
	
	-- Step size when looking for a horizontal wall collision
	local stepH = {
		x = sign.x * map.gridWidth / math.tan(theta),
		y = sign.y * map.gridWidth
	}
	
	stepH.distance = math.dist(0, 0, stepH.x, stepH.y)
	
	-- Relative position and distance closest wall point that could be a vertical collision
	-- (Relative to the bottom-left of the tile the player is standing in)
	local wallV
	
	if sign.x > 0 then
		wallV = {
			x = map.gridWidth,
			y = tilePos.y + sign.y * (map.gridWidth - tilePos.x) * math.tan(theta)
		}
	else
		wallV = {
			x = 0,
			y = tilePos.y + sign.y * tilePos.x * math.tan(theta)
		}
	end
	
	wallV.distance = math.dist(tilePos.x, tilePos.y, wallV.x, wallV.y)
	
	-- Relative position and distance of closest wall point that could be a horizontal collision
	local wallH
	
	if sign.y > 0 then
		wallH = {
			x = tilePos.x + sign.x * (map.gridWidth - tilePos.y) / math.tan(theta),
			y = map.gridWidth
		}
	else
		wallH = {
			x = tilePos.x + sign.x * tilePos.y / math.tan(theta),
			y = 0
		}
	end
	
	wallH.distance = math.dist(tilePos.x, tilePos.y, wallH.x, wallH.y)
	
	--
	while true do
		-- Step into the next map cell that the ray would pass through
		if wallV.distance < wallH.distance then
			mapCoord.x = mapCoord.x + sign.x
			
			-- Save this stuff just in case there is a collision
			collision.distance = wallV.distance
			collision.vertical = true
		else
			mapCoord.y = mapCoord.y + sign.y
			
			collision.distance = wallH.distance
			collision.vertical = false
		end
		
		-- Check to see if the ray left the map boundaries
		if mapCoord.x < 1 or mapCoord.x > map.size or mapCoord.y < 1 or mapCoord.y > map.size then
			-- Return distance as infinity to represent the ray flying off into oblivion
			collision.distance = math.huge
			return collision
		
		-- Otherwise, check to see if there was a collision
		elseif map.data[mapCoord.x][mapCoord.y].wall then
			-- There was, so break out of the loop
			break
		end
		
		-- There wasn't a collision so increment distance by a step and do another one
		-- The relative wall coordinate is also incremented so that a texture coordinate can
		-- be calculated later
		if wallV.distance < wallH.distance then
			wallV.x = wallV.x + stepV.x
			wallV.y = wallV.y + stepV.y
			wallV.distance = wallV.distance + stepV.distance
		else
			wallH.x = wallH.x + stepH.x
			wallH.y = wallH.y + stepH.y
			wallH.distance = wallH.distance + stepH.distance
		end
	end

	-- Calculate texture coordinates based on the orientation of the collision and its
	-- position within the tile
	if collision.vertical then
		collision.tc = (wallV.y % map.gridWidth) / map.gridWidth
	
		-- Flip it so that it isn't mirrored when viewing it from the opposite direction
		if sign.x < 0 then
			collision.tc = 1 - collision.tc
		end
	else
		collision.tc = (wallH.x % map.gridWidth) / map.gridWidth
		
		if sign.y > 0 then
			collision.tc = 1 - collision.tc
		end
	end
	
	-- Add the texture index to the return table
	collision.texture = map.data[mapCoord.x][mapCoord.y].texture

	-- Return the collision information
	return collision
end

function scaster.draw(x, y, phi)
	-- Don't proceed if a map wasn't loaded yet
	if map.loaded == false then
		return
	end
	
	-- Draw ceiling
	if renderer.textured then
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.draw(sky.image, sky.quad, 0, 0)
	else
		love.graphics.setColor(50, 50, 100, 255)
		love.graphics.rectangle("fill", 0, 0, screen.width, screen.center.y)
	end

	-- Draw floor
	love.graphics.setColor( 50, 50, 50, 255)
	love.graphics.rectangle("fill", 0, screen.center.y, screen.width, screen.height)

	-- Starting angle
	local delta = -renderer.fov/2
	
	-- Loop through each screen column
	for screenColumn = 0, screen.width - 1, 1 do
		local collision = rayCast(x, y, phi + delta)
		
		-- If the distance is infinite then there's no wall to draw
		if collision.distance < math.huge then
			-- Fishbowl correction
			collision.distance = collision.distance * math.cos(delta)
		
			--
			local height = (map.wallHeight/collision.distance)*renderer.perspectivePlaneDistance
			
			-- Shading
			local intensity
			
			if collision.distance > map.fogDistance then
				intensity = 0
			else
				local shading = 1 - collision.distance / map.fogDistance
				
				if collision.vertical then
					intensity = 255*shading
				else
					intensity = 200*shading
				end
			end
			
			-- This color is mixed in with the drawn texture, or is used as the line colour if texturing is off
			love.graphics.setColor(intensity, intensity, intensity, 255)
			
			-- Draw a wall texture strip or a line depending on the texturing flag
			if (renderer.textured) then
				local textureColumn = math.floor(collision.tc*texture.width)
				love.graphics.draw(texture.images[collision.texture], texture.quads[textureColumn], screenColumn, screen.center.y-height/2, 0, 1, height/texture.height)
			else
				love.graphics.line(screenColumn + 0.5, screen.center.y - height/2, screenColumn + 0.5, screen.center.y + height/2)
			end
		end
		
		delta = delta + renderer.angleIncrement
	end
end

return scaster
