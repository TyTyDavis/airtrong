pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

--to do

---circ points works, but
--the logic to use it with
--plane spawn doesnt


--globals--
pi=3.1415926535897932384
circx=128/2
circy=128/2
circr=62

level=0
wave=1
planes_left=0

gamestate="menu"

planes={}
queue={}
counter=0
spawn_gap=3
grace_period=6*30
seconds=0
score=0
speed=0.4

function _init()
	set_palette()
	cls()
end


function _update()
	update_time()
	if gamestate=="menu" then
		menu()
	elseif gamestate=="level start" then
			gamestate="play"
	elseif gamestate=="play" then
		pull_from_queue()
		for plane in all(planes) do
			plane:update()
		end
        for c in all(cursors) do
            if c.balled==false then
                spawn_ball(c)
            end
            c:update()
        end


	elseif gamestate=="lost" then
		handle_lost()
	elseif gamestate=="next_level" then
		if btnp(❎) then gamestate="level start" end
	end

end


function _draw()
	cls()
	
	---
	beforedraw()
	---
	
	for x=0, 127, 8 do
		line(x,0,x,127,1)
	end
	for y=0, 127, 8 do
		line(0,y,127,y,1)
	end
	
	if gamestate=="play" or gamestate=="lost" then
		for plane in all(planes) do
			plane:draw()
		end
		c1:draw()
        c2:draw()
		local lc=6
		local rc=3
		if not c1.left then
			lc=3
			rc=6
		end
	elseif gamestate=="menu" then
		draw_menu()
	end
	
	if gamestate=="lost" then
		draw_lost()
	end
	
	if gamestate=="next_level" then
		draw_next()
	end

	circ(circx,circy,circr,6)
	
	---
	afterdraw()
	---
	
	print("l",3,119,lc)
	print("r",10,119,rc)
	print(score, 3,3,5)
end
-->8
--draw functions
function set_palette()
	pal(1,128,1)
	pal(2,133,1)
	pal(3,5,1)
	pal(4,13,1)
	pal(5,7,1)
	pal(6,6,1)
	pal(7,8,1)
	pal(8,14,1)
	pal(9,10,1)
	pal(10,135,1)
	pal(12,138,1)
	pal(13,140,1)
	pal(14,12,1)
	pal(15,14,1)
	
	poke(0x5f2e, 1 )
end

--https://www.lexaloffle.com/bbs/?tid=46286
function beforedraw()
 myx=circx
 myy=circy

 myr=circr
 
 --make a screenshot
 memcpy(0x8000,0x6000,0x2000)
end

function afterdraw()
function afterdraw()
 --remap spritesheet to become the screen
 poke(0x5f55,0)

 --fill the spritesheet with black
 palt(0,false)
 cls(0) 

 --draw a white circle on the spritesheet
 circfill(myx,myy,myr,7)

 --video remapping back to normal
 poke(0x5f55,0x60)

 --set white to transparent
 palt(7,true)

 --draw the entire spritesheet to the screen
 sspr(0,0,128,128,0,0)

 --reset everything
 reload(0,0,0x2000)
 palt()  
end
 

end

--helper wrapper for sspr that
--allows us to conveniently
--change a line function into 
--an sspr function
function ssprline(x1,y1,x2,y2)
 sspr(x1,y1,1,y2-y1,x1,y1)
end
-->8
--cursor
c1={ 
	p=0,
    x=30,
	y=62,
	dx=0,
	dy=0,
	left=true,
	acc=0.4,
	dcc=0.8,
	target=nil,
    balled=false,
	draw=function(self)
		local target_color=4
		if self.target then
			target_color=self.target.col+1
			--line(self.x, self.y, self.target.x, self.target.y,2)
		end
		local lc=6
		local rc=3
		if not self.left then
			lc=3
			rc=6
		end
		pset(self.x, self.y+1,lc)
		pset(self.x+1, self.y+1,lc)
		
		pset(self.x+3, self.y,target_color)
		pset(self.x+3, self.y+1,target_color)
		pset(self.x+3, self.y+2,target_color)
		
		pset(self.x+5, self.y+1,rc)
		pset(self.x+6, self.y+1,rc)
	end,
	update=function(self)
		if btn(⬅️,self.p) then
			self.dx-=self.acc
		elseif btn(➡️, self.p) then
			self.dx+=self.acc
		else
			self.dx*=self.dcc
		end
		if btn(⬆️,self.p) then
			self.dy-=self.acc
		elseif btn(⬇️, self.p) then
			self.dy+=self.acc
		else
			self.dy*=self.dcc
		end
		if btnp(❎, self.p) then
			if self.target then
				if self.target then
					if self.td==nil then
						if (self.left) self.target.state="turnl"
						if (not self.left) self.target.state="turnr"
					end
				end
			end
		elseif btnp(🅾️,self.p) then
			sfx(0)
			if self.left then
				self.left=false
			else
				self.left=true
			end
		end
		if in_circle(self.x+self.dx,self.y+self.dy, circx, circy, circr-2) then
			self.x+=self.dx
			self.y+=self.dy
		else
			self.dx*=-0.5
			self.dy*=-0.5
		end
		local closest=find_closest_plane(planes, self)
		if closest then
			if dist(closest.x,closest.y,self.x,self.y)<15 then
				self.target=closest
			else
				self.target=nil
			end
		else
			self.target=nil	
		end
	end,
}


function deepcopy(orig)
 local copy = {}
 for orig_key, orig_value in pairs(orig) do
  copy[orig_key] = orig_value
 end
 return copy
end	

c2 = deepcopy(c1)
c2.x  = 90
c2.p = 1

cursors={c1,c2}

function find_closest_plane(p, c)
 if (count(p)<1) return nil
 closest_plane=p[1]
 min_distance=dist(p[1].x,p[1].y, c.x,c.y)
 for pn in all(p) do
  distance = dist(pn.x,pn.y, c.x,c.y)
  if distance<min_distance then
   min_distance=distance
   closest_plane=pn
  end
 end
 return closest_plane
end
-->8
--planes
planes={}
function spawn(x,y,d,speed,p,ball)
	ball=ball or false
    p=p or c1
	if p.p==0 then
        if ball then col=13 else col = 14 end
    else
        if ball then col = 7 else col = 15 end
    end
    if ball then
        tcol=col+1
    else
        tcol=col
    end
    local p={
		id=rnd(1000),
		x=x,
		y=y,
        p=p,
        ball=ball,
		dx=0,
		dy=0,
		d=d,
		td=nil,
		col=col,
        tcol=tcol,
		speed=speed,
		trail={},
		spawned=false,
		state="straight",
		age=0,
		target_d={},
		target={},
		delete=function(self)
            if self.ball then
            	self.p.balled=false
            end
            del(planes,self)
  		end,
		draw=function(self)
			if self.p.target==self and self.td==nil then
				if self.p.left then
					turn_degrees=perc_to_d(reverse(self.d+0.25%1))
				else
					turn_degrees=perc_to_d(reverse(self.d-0.25%1))
				end
				linex,liney,_=point_on_circle(6, self.x, self.y, turn_degrees)
				line(self.x, self.y,linex,liney,3)
			elseif self.td then
				linex,liney,_=point_on_circle(6, self.x, self.y, perc_to_d(reverse(self.td)))
				line(self.x, self.y,linex,liney,3)
			end
			for t in all(self.trail) do
				pset(t[1], t[2], self.tcol)	
			end
			local coords={flr(self.x),flr(self.y)}
			add_unique_coords(self.trail, coords)
			if (count(self.trail)>20) del(self.trail,self.trail[1])
			rectfill(self.x-1,self.y-1,self.x+1,self.y+1,self.col)
			if self.ball and self.age>grace_period then
				circ(self.x,self.y, 7, self.col)
	
				for p in all(self.target) do
					pset(p[1],p[2],self.col)
				end
			end	
		end,
		update=function(self)
			self.age+=1
			if self.state=="turnl" then
				self.td=self.d+0.25%1
				self.state="straight"
			elseif self.state=="turnr" then
				self.td=self.d-0.25%1
				self.state="straight"
			end
   if self.td!=nil then
   	turn(self)
   elseif self.td==self.d then
   	self.td=nil
   end
   self.dx=self.speed*cos(reverse(self.d))
   self.dy=self.speed*sin(reverse(self.d))
   
			self.x+=self.dx*self.speed
			self.y+=self.dy*self.speed
				
			--exiting
			local in_circ=in_circle(self.x, self.y)
			if not self.spawned then
				if (in_circ) self.spawned=true
			end
			if self.spawned and not in_circ then
				if self.ball then
					if count(self.target)<0 and within_box(self.x, self.y, self.target[1][1],self.target[1][2], self.target[count(self.target)][1],self.target[count(self.target)][2]) then
						sfx(1)
						score+=100
					end
					planes_left-=1
				end
				del(planes, self)
			end
			
			--collision
			if self.ball then
				for p in all(planes) do
					if p.id != self.id then
						if in_circle(p.x,p.y, self.x, self.y, 7) and self.age>grace_period and p.age>grace_period  then 
							self:delete()
                            p:delete()
						end
					end
				end
			else
				for p in all(planes) do
					if p.id != self.id then
						if (check_collision(self.x-1,self.y-1,p.x-1,p.y-1,3,3)) then
                            self:delete()
                            p:delete()
                        end
					end
				end
			end
		end,
	}

	p.target_d={reverse(p.d-0.05),reverse(p.d+0.05)}
	p.target=get_circ_points(circx, circy, circr-3, p.target_d[1], p.target_d[2])
		
	add(queue,p,1)
end


function rnd_spawn(col,degrees,speed)
	local speed=speed or 0.4
	local col=col or 5
	local degrees=degrees or flr(rnd(360))
 local x,y,d=point_on_circle(circr, circx, circy, degrees)
 spawn(x,y,d,speed)
end

function spawn_ball(p)
    local speed = speed or 0.4
    local degrees = 0
    if p.p==0 then
        degrees = flr(rnd(180)+180)
    else
        degrees = flr(rnd(180))
    end
    local x,y,d=point_on_circle(circr, circx, circy, degrees)
    spawn(x,y,d,speed,p,true)
    p.balled=true
end

function turn(p)
 local increment = 0.003
 local clockwise_diff = (p.td - p.d + 1.0) % 1.0
 local counterclockwise_diff = (p.d - p.td + 1.0) % 1.0

 local direction = 0
 if clockwise_diff < counterclockwise_diff then
  direction = 1  -- move clockwise
 else
  direction = -1  -- move counterclockwise
 end

 
 local new_value = p.d + (increment * direction)

 if new_value < 0.0 then
  new_value = new_value + 1.0
 elseif new_value > 1.0 then
  new_value = new_value - 1.0
 end
 if abs(new_value-p.td)<=increment*3 then
 	p.d=p.td
 	p.td=nil
 else
 	p.d=new_value
 end
end


function p_degrees(length)
 local numbers={} 

 local first_number=flr(rnd(350))
 add(numbers, first_number)

 for i = 2,length do
  local new_number
  variance=flr(rnd(30)+30)
 	new_number=(numbers[i-1]+variance)%360
 	add(numbers, new_number)
	end
	return numbers
end

function spawn_wave(p,color_p)
	local degrees=p_degrees(p)
	for i=1,p do
		local col=5
		if color_p>1 then
				col=rnd(plane_colors)
				color_p-=1
		end
		rnd_spawn(col,degrees[i])
	end
end

function pull_from_queue()
	if seconds%spawn_gap==0 then
		if type(queue[count(queue)]) == "string" then
			deli(queue, count(queue))
		else
			add(planes, deli(queue, count(queue)))
		end
		seconds+=0.1
	end
end
-->8

--helpers
function add_unique_coords(list, coords)
    local found = false
    for c in all(list) do
     if c[1] == coords[1] and c[2] ==coords[2] then
      found=true
     	break
     end
    end
    if not found then
     add(list,coords)
    end
end

function dist(x1,y1,x2,y2)
 local xdif=x1-x2
 local ydif=y1-y2

 local atan=atan2(xdif,ydif)

 local xdist=cos(atan)*xdif
 local ydist=sin(atan)*ydif

 return xdist+ydist
end


function in_circle(x, y, circle_x, circle_y, radius)
	circle_x=circle_x or circx
	circle_y=circle_y or circy
	radius=radius or circr
	distance = sqrt((x - circle_x)^2 + (y - circle_y)^2)
 return distance <= radius
end


function check_collision(x1,y1,x2,y2,l1,l2)
 if (x1+l1-1 < x2) or (x2+l2-1 < x1) 
 or (y1+l1-1 < y2) or (y2+l2-1 < y1) then
   return false
 else 
 	return true
 end
end

function lose()
	sfx(2)
	gamestate="lost"
end

function point_on_circle(radius, x_center, y_center, degrees)
 local angle=d_to_perc(degrees)
 local x=x_center+radius*cos(angle)
 local y=y_center+radius*sin(angle)
 return x, y, angle
end

function round(num)
	if (num%1)>=0.5 then
		return ceil(num)
	else
		return flr(num)
	end
end

function reverse(angle)
	local reversed_angle = (angle + .5) % 1
 return reversed_angle
end


function d_to_perc(degrees)
 turns=turns or false
 local degrees=degrees%360
 local percentage=(degrees/360)
 return percentage
end

function perc_to_d(perc)
 local angle_degrees=perc*360
 return angle_degrees
end


function center_print(string,y, col, shadow)
	local col=col or 5
	local shadow=shadow or nil
	if shadow!=njil then
		print(string, 64-(#string*2)+1, y+1, shadow)
	end
	print(string, 64-(#string*2), y, col)
end

function update_time()
	if flr(time())>seconds then
		seconds=flr(time())
	end
end


function get_circ_points(xc, yc, r, start_degrees, end_degrees)
 local edge_coordinates={}
	for d=start_degrees,end_degrees,0.001 do
		local x,y,_=point_on_circle(r,xc,yc,d*360)
		add(edge_coordinates,{x,y})
	end
 return edge_coordinates
end

function circ_point(xc,yc,r,p)
	--this isn't working
	local x,y=xc+r*cos(a),yc+r*sin(p)
	return x,y
end

function within_box(px,py,x1,y1,x2,y2)
	local minx=min(x1, x2)
 local maxx=max(x1, x2)
 local miny=min(y1, y2)
 local maxy=max(y1, y2)
 return px>=minx and px <= maxx and py >= miny and py <= maxy
end
-->8
--storms
--to do
-- implement storm areas
-->8
--menus and state
--to do
-- implement menus and gamestate  

function set_up_level()
	if level<=2 then
		l=level_settings[1]	
	elseif level<=4 then
		l=level_settings[2]
	elseif level<=6 then
		l=level_settings[3]
	elseif level<=8 then
		l=level_settings[4]
	else
		l=level_settings[5]
	end
		
	repeat
		planes_per_wave=l["cplanes"]/l["waves"]
		spawn_wave(planes_per_wave,planes_per_wave)
		if (wave>1) add_pause(1)
		wave+=1
	until wave>=l["waves"]
	planes_left=l["cplanes"]
end

function add_pause(n)
	for i=1,n do
		add(queue,"pause",1)
	end
end


function draw_menu()
	string1="air trong"
	string2="press ❎ to start"
	
	center_print(string1,55, 5,2)
	center_print(string2,63,5,2)
end

function menu()
	if (btnp(❎)) gamestate="level start"
end

function draw_lost()
	string1="game over"
	string2="press ❎ to restart"
	
	center_print(string1,55, 5,2)
	center_print(string2,63,5,2)
end

function draw_next()
	string1="level "..level.." complete!"
	string2="press ❎ to continue"
	
	center_print(string1,55, 5,2)
	center_print(string2,63,5,2)
end

function handle_lost()
	if btnp(❎) then
		level=1
		wave=1
		new_level()
	end
end

function new_level()
	queue={}
	planes={}
	level+=1
	wave=1
	gamestate="level start"
end
-->8
--data
level_settings={
	{
		speed=0.6,
		waves=4,
		cplanes=8,
		clouds=0,
	},
	{
		speed=0.8,
		waves=5,
		cplanes=12,
		clouds=0,
	},
		{
		speed=1.0,
		waves=6,
		cplanes=16,
		clouds=0,
	},
	{
		speed=1.2,
		waves=6,
		cplanes=18,
		clouds=0,
	},
	{
		speed=1.0,
		waves=6,
		cplanes=24,
		clouds=0,
	},
}
	
	
plane_colors={7,9,11,13}
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
eeeeecccccceeecccccceeecccccceeecccccceee888888eeecccccceeecccccceeecccccceeeeeeeeeeeeeeeeeelleelleeelllelleeeeeeelleeeeeelleeee
eeeecceeecceecceeccceecceeecceecceeeccee88e8e88eecceeecceeccecccceecceeecceeeeeeeeeeeeeeeeeelllllleeelllelleeeeelleleeeeeellleee
eeecccececcecccceccceccccceccecccccecce888e8e88ecccecccceccceccccecccccecceeeeeeeeeeeeeeeeeelelleleeellleeeeeelleeeleeeeeeleeeee
eeecccececcecccceccceccceeeccecccceecce888eee88eccceeecceccceeeccecccccecceeeeeeeeeeeeeeeeeelllllleeeeeellleeelleeeleeeellleeeee
eeecccececcecccceccceccceccccecccccecce88888e88eccccceccecccececcecccccecceeeeeeeeeeeeeeeeeeelllleeeellellleeeeelleleeelllleeeee
eeeccceeecceccceeecceccceeecceccceeecce88888e88eccceeecceccceeeccecccccecceeeeeeeeeeeeeeeeeeeleeleeeellellleeeeeeelleeellleeeeee
eeeccccccccecccccccceccccccccecccccccce88888888ecccccccceccccccccecccccccceeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gg8ggbbbgbbbgbbbgbbbgg8ggg8ggg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g8ggggbgggbggbbbgbggg8ggggg8ggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g8ggggbgggbggbgbgbbgg8ggggg8ggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g8ggggbgggbggbgbgbggg8ggggg8ggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gg8gggbggbbbgbgbgbbbgg8ggg8ggg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gg66g666g666gg66ggggg666gg66g666g66gg666gg66gg8gg6g6gg66ggggggggg6g6gg66ggggggggg666gggggggggg66g666g666g666g666ggggg66gg666gg66
g6gggg6gg6g6g6ggggggg6g6g6g6gg6gg6g6gg6gg6ggg8ggg6g6g6ggggggggggg6g6g6ggggggggggg6g6ggggggggg6gggg6gg6g6g6g6gg6gggggg6g6g6ggg6gg
g6gggg6gg66gg6ggggggg666g6g6gg6gg6g6gg6gg666g8gggg6gg6ggggggggggg666g6ggggggggggg66gggggggggg666gg6gg666g66ggg6gggggg6g6g66gg6gg
g6gggg6gg6g6g6ggggggg6ggg6g6gg6gg6g6gg6gggg6g8ggg6g6g6gggg8gggggggg6g6gggg8gggggg6g6gg8gggggggg6gg6gg6g6g6g6gg6gggggg6g6g6ggg6g6
gg66g666g6g6gg66g666g6ggg66gg666g6g6gg6gg66ggg8gg6g6gg66g8ggggggg666gg66g8ggggggg6g6g8ggggggg66ggg6gg6g6g6g6gg6gg666g666g666g666
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gg66gg66g666g66gg666g66gg666g666g666gg66gggggg88g88ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g6g6g6g6g6g6g6g6gg6gg6g6g6g6gg6gg6ggg6ggg888gg8ggg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g6g6g6g6g66gg6g6gg6gg6g6g666gg6gg66gg666ggggg88ggg88gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g6g6g6g6g6g6g6g6gg6gg6g6g6g6gg6gg6ggggg6g888gg8ggg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g66gg66gg6g6g666g666g6g6g6g6gg6gg666g66ggggggg88g88ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g66gg666gg66g666g666g666gg66ggggg666g66gg66gggggg66gg666gg66g666g666g666gg66gggggqqqgggggqqqgqqggggggccgggccgggggggggggggggggggg
g6g6g6ggg6ggg6g6g6ggg6ggg6ggggggg6ggg6g6g6g6ggggg6g6g6ggg6ggg6g6g6ggg6ggg6gggggggqgqgggggqgqggqggggggcgcgcgcgggggggggggggggggggg
g6g6g66gg6ggg66gg66gg66gg666ggggg66gg6g6g6g6ggggg6g6g66gg6ggg66gg66gg66gg666gggggqgqgggggqgqggqggggggcgcgcgcgggggggggggggggggggg
g6g6g6ggg6g6g6g6g6ggg6ggggg6gg8gg6ggg6g6g6g6ggggg6g6g6ggg6g6g6g6g6ggg6ggggg6gg8ggqgqgggggqgqggqggggggcgcgcgcgggggggggggggggggggg
g666g666g666g6g6g666g666g66gg8ggg666g6g6g666g666g666g666g666g6g6g666g666g66gg8gggqqqggqggqqqgqqqgggggcccgccggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggeeee
ggggg666gg66g666g66gg666gggggg66g66ggggggg66g666g666gg66g6ggg666gg8gg666ggggg6g6gg66ggggg6g6gg66ggggg66ggggggqqqgqqqgqgqgqqqee8e
g888g6g6g6g6gg6gg6g6gg6gggggg6g6g6g6ggggg6gggg6gg6g6g6ggg6ggg6ggg8ggg6g6ggggg6g6g6ggggggg6g6g6ggggggg6g6ggggggqggqgqgqgqgqggeee8
ggggg666g6g6gg6gg6g6gg6gggggg6g6g6g6ggggg6gggg6gg66gg6ggg6ggg66gg8ggg66ggggggg6gg6ggggggg666g6ggggggg6g6ggggggqggqqggqgqgqqggee8
g888g6ggg6g6gg6gg6g6gg6gggggg6g6g6g6ggggg6gggg6gg6g6g6ggg6ggg6ggg8ggg6g6gg8gg6g6g6gggg8gggg6g6gggg8gg6g6gg8gggqggqgqgqgqgqgg8ge8
ggggg6ggg66gg666g6g6gg6gg666g66gg6g6g666gg66g666g6g6gg66g666g666gg8gg6g6g8ggg6g6gg66g8ggg666gg66g8ggg666g8ggggqggqgqggqqgqqg88ge
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg888g
gg66g666g66gg666g66gg666g666g666gg66gggggg88g6g6ggggg6g6g88ggg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg8888
g6g6g6g6g6g6gg6gg6g6g6g6gg6gg6ggg6gggggggg8gg6g6ggggg6g6gg8gggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg88gg
g6g6g66gg6g6gg6gg6g6g666gg6gg66gg666ggggg88ggg6gggggg666gg88ggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg8g
g6g6g6g6g6g6gg6gg6g6g6g6gg6gg6ggggg6gg8ggg8gg6g6gg8gggg6gg8gggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g66gg6g6g666g666g6g6g6g6gg6gg666g66gg8gggg88g6g6g8ggg666g88ggg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gg66gg66gg66g666g66gg666g66gg666g666g666gg66gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g6ggg6g6g6g6g6g6g6g6gg6gg6g6g6g6gg6gg6ggg6gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g6ggg6g6g6g6g66gg6g6gg6gg6g6g666gg6gg66gg666gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g6ggg6g6g6g6g6g6g6g6gg6gg6g6g6g6gg6gg6ggggg6gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gg66g66gg66gg6g6g666g666g6g6g6g6gg6gg666g66ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggg666gg66g666g66gg666gg8gg6g6gg66ggggg6g6gg66ggggg666ggggg666gg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggg6g6g6g6gg6gg6g6gg6gg8ggg6g6g6ggggggg6g6g6ggggggg6g6ggggg6g6ggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggg666g6g6gg6gg6g6gg6gg8gggg6gg6ggggggg666g6ggggggg66gggggg666ggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggg6ggg6g6gg6gg6g6gg6gg8ggg6g6g6gggg8gggg6g6gggg8gg6g6gg8gg6ggggg8gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
g666g6ggg66gg666g6g6gg6ggg8gg6g6gg66g8ggg666gg66g8ggg6g6g8ggg6gggg8ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggsgsggssgsssgsgsgsssgssgggssgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggsgsgsgsgsgsgsgsggsggsgsgsgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggsgsgsgsgssggssgggsggsgsgsgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggsssgsgsgsgsgsgsggsggsgsgsgsgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggsssgssggsgsgsgsgsssgsgsgsssgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggg666g8g8ggbbggbbggbbgg8gg666gg8gggggg6g6gg66ggggg666g8g8ggbbgbbbgbbggg8gg666gg8ggggggggggggggggggggggggggggggggggggggggggggg
gg8gg6g6gg8ggbgggbgbgbggg8ggg6g6ggg8ggggg6g6g6gggg8gg6g6gg8ggbggggbggbgbg8ggg6g6ggg8gggggggggggggggggggggggggggggggggggggggggggg
g888g66gg888gbgggbgbgbbbg8ggg666ggg8ggggg666g6ggg888g66gg888gbbbggbggbgbg8ggg666ggg8gggggggggggggggggggggggggggggggggggggggggggg
gg8gg6g6gg8ggbgggbgbgggbg8ggg6g6ggg8gg8gggg6g6gggg8gg6g6gg8ggggbggbggbgbg8ggg6ggggg8gggggggggggggggggggggggggggggggggggggggggggg
ggggg6g6g8g8ggbbgbbggbbggg8gg6g6gg8gg8ggg666gg66ggggg6g6g8g8gbbggbbbgbgbgg8gg6gggg8ggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
eleeelllelleellleeeeelleelleellleeelelleelllellleeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeelllelllelllelleeeelelllelleelllellleee666ee
eleeeeleeleleleeeeeeeeleeeleeleeeeleeeleeeeleleeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeleeeleleleeleeeleeleleeleeleleeeleeeeeeee
eleeeeleelelelleeeeeeeleeeleellleeleeeleelllellleeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeellleelleleleeleeeleellleeleelllellleeelllee
eleeeeleeleleleeeeeeeeleeeleeeeleeleeeleeleeeeeleeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeleeeeeleleleeleeeleeleleeleeeeleleeeeeeeeee
elllelllelelellleeeeelllelllellleleeelllelllellleeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeelllelllelllellleleeelllellleeelellleeelllee
eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee

__sfx__
00010000000000a1501d150001003750038500395003a5003b5003c5003d5003e500365002b500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000e750177501f750247502a7502f750347502775019750117500d7500f7501375015750197501d75021750277502c75030750327502e75028750237501c75016750107500975009750000000000000000
000800000000000000020500205001050010500005000050000500005000050000500000000000000000000005000050000400004000030000200001000000000000000000000000000000000000000000000000
