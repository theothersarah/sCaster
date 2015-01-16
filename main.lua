scaster = require("scaster")

-- 
function math.sign(n) return n>0 and 1 or n<0 and -1 or 0 end
function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end

--
 player = {
	x = 64*64/2 + 32,
	y = 64*64/2 + 32,
	angle = 0
}

--
function love.load()
	scaster.load()
end

-- Controls go here
function love.update(dt)
	if love.keyboard.isDown("a") then
		player.angle = player.angle - dt
		
		if player.angle < 0 then
			player.angle = player.angle + 2*math.pi
		end
	end
	
	if love.keyboard.isDown("d") then
		player.angle = player.angle + dt
		
		if player.angle > 2*math.pi then
			player.angle = player.angle - 2*math.pi
		end
	end
	
	if love.keyboard.isDown("w") then
		player.x = player.x + 256*dt*math.cos(player.angle)
		player.y = player.y + 256*dt*math.sin(player.angle)
	end
	
	if love.keyboard.isDown("s") then
		player.x = player.x - 256*dt*math.cos(player.angle)
		player.y = player.y - 256*dt*math.sin(player.angle)
	end
end

-- Rendering goes here
function love.draw()
	scaster.draw(player.x, player.y, player.angle)

	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.print(love.timer.getFPS(), 0, 0)
end
