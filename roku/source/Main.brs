'*************************************************************
'** Hello World example
'** Copyright (c) 2015 Roku, Inc.  All rights reserved.
'** Use of the Roku Platform is subject to the Roku SDK Licence Agreement:
'** https://docs.roku.com/doc/developersdk/en-us
'*************************************************************

Sub Init()
	
	m.files = CreateObject("roFileSystem")
    CacheFile("https://raw.githubusercontent.com/leastfavorite/horseracetests-roku/8a41e821962b018e9fe14cd969d6e67ad94006d8/roku/maps/1.png", "map.png")
    CacheFile("https://raw.githubusercontent.com/leastfavorite/horseracetests-roku/8a41e821962b018e9fe14cd969d6e67ad94006d8/roku/maps/1.json", "map.json")
    CacheFile("https://raw.githubusercontent.com/leastfavorite/horseracetests-roku/8a41e821962b018e9fe14cd969d6e67ad94006d8/roku/images/sunflower.png", "horse.png")

	m.PI = 3.14159265
	m.R = 16

	m.horse = CreateObject("roBitmap", "tmp:/horse.png")
	m.horseRegion = CreateObject("roRegion", m.horse, 0, 0, 2 * m.R, 2 * m.R)
	m.map = CreateObject("roBitmap", "tmp:/map.png")
	m.walls = ParseJson(ReadAsciiFile("tmp:/map.json"))
	
	m.port = CreateObject("roMessagePort")

	m.screen = CreateObject("roScreen", True)
	m.screen.SetMessagePort(m.port)
	m.screen.SetAlphaEnable(True)
	
	m.compositor = CreateObject("roCompositor")
	m.compositor.SetDrawTo(m.screen, &h0)
	
	m.sprites = []
	m.sprites[0] = m.compositor.NewSprite(0, 0, m.horseRegion)
	m.sprites[0].SetData({ x: 175.0, y: 153.0, theta: Rnd(0) * 2 * m.PI })
	m.sprites[1] = m.compositor.NewSprite(0, 0, m.horseRegion)
	m.sprites[1].SetData({ x: 175.0, y: 110.0, theta: Rnd(0) * 2 * m.PI })
	
	m.clock = CreateObject("roTimespan")
	m.clock.Mark()
	
End Sub

Sub Draw()
	for each sprite in m.sprites
		data = sprite.GetData()
		sprite.MoveTo(data.x - m.R, data.y - m.R)
	end for

	m.screen.DrawObject(0, 0, m.map)

	for each polygon in m.walls
		for i = 0 to polygon.Count() - 1
			p1 = polygon[i]
			p2 = polygon[(i + 1) mod polygon.Count()]
			m.screen.DrawLine(p1.x, p1.y, p2.x, p2.y, &hFF0000FF)
		end for
	end for
	m.compositor.DrawAll()
End Sub

Function Update(ms as float)
	R = m.R
	SPEED = 0.1
	EPSILON = 1.1
	for each sprite in m.sprites
		data = sprite.GetData()
		x = data.x
		y = data.y
		theta = data.theta
		
		x = x + SPEED * ms * Cos(theta)
		y = y + SPEED * ms * Sin(theta)
		
		collided = False
		for each polygon in m.walls
			for each pt in polygon
				ax = 0.0 + x - pt.x
				ay = 0.0 + y - pt.y
				vx = Cos(theta)
				vy = Sin(theta)
				adv = ax*vx+ay*vy
				ada = ax*ax+ay*ay
				
				if ada > R*R then
					continue for
				end if
				
				det = adv * adv - ada + R*R
				t = -adv - Sqr(det)
				
				if t < 0 and t > -R then
					x = x + EPSILON*t*vx
					y = y + EPSILON*t*vy
					
					ax = 0.0 + x - pt.x
					ay = 0.0 + y - pt.y
					theta = m.PI + 2 * Atan2(ay, ax) - theta
					
					collided = True
					exit for
				end if
			end for
			if collided then exit for
			for i = 0 to polygon.Count() - 1
				p1 = polygon[i]
				p2 = polygon[(i + 1) mod polygon.Count()]
				ax = 0.0 + p2.x - p1.x
				ay = 0.0 + p2.y - p1.y
				bx = 0.0 + x - p1.x
				by = 0.0 + y - p1.y
				qs = (ax*bx+ay*by)/(ax*ax+ay*ay)

				if qs <= 0.0 or qs >= 1.0 then
					continue for
				end if

				qx = ax * qs
				qy = ay * qs
				vx = Cos(theta)
				vy = Sin(theta)

				aax = 0.0 + x - qx - p1.x
				aay = 0.0 + y - qy - p1.y

				qqs = (ax*vx+ay*vy)/(ax*ax+ay*ay)
				bbx = vx-qqs*ax
				bby = vy-qqs*ay

				ada = aax*aax + aay*aay
				adb = aax*bbx + aay*bby
				bdb = bbx*bbx + bby*bby

				det = adb*adb - bdb*(ada-R*R)
				t = (- adb - Sqr(det)) / (bdb)
				if t >= 0 or t <= -R then
					continue for
				end if
				x = x + vx * EPSILON*t
				y = y + vy * EPSILON*t
				ref = Atan2(ay, ax)
				theta = ref + ref - theta
				collided = True
				exit for
			end for
			if collided then exit for
		end for
		sprite.SetData({ x: x, y: y, theta: theta })
	end for
			
	for i = 0 to m.sprites.Count() - 1
		for j = i+1 to m.sprites.Count() - 1
			sprite1 = m.sprites[i]
			data1 = sprite1.GetData()
			x1 = data1.x
			y1 = data1.y
			theta1 = data1.theta

			sprite2 = m.sprites[j]
			data2 = sprite2.GetData()
			x2 = data2.x
			y2 = data2.y
			theta2 = data2.theta
					
			dx = x1 - x2
			dy = y1 - y2
			c = dx*dx+dy*dy-4*R*R
			
			if c >= 0 then
				continue for
			end if
					
			dvx = Cos(theta1) - Cos(theta2)
			dvy = Sin(theta1) - Sin(theta2)
			b = (dx*dvx+dy*dvy)
			a = (dvx*dvx+dvy*dvy)
					
			t = - (b+Sqr(b*b - a*c)) / a
					
			x1 = x1 + EPSILON*t*Cos(theta1)
			y1 = y1 + EPSILON*t*Sin(theta1)

			x2 = x2 + EPSILON*t*Cos(theta2)
			y2 = y2 + EPSILON*t*Sin(theta2)
			
			normal = Atan2(y2-y1, x2-x1)
			theta1 = m.PI + normal + normal - theta1
			theta2 = m.PI + normal + normal - theta2
					
			sprite1.SetData({ x: x1, y: y1, theta: theta1 })
			sprite2.SetData({ x: x2, y: y2, theta: theta2 })
			
		end for
	end for
End Function

Sub Main()
	Init()

    while(true)
        msg = m.port.GetMessage()
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if

        ms = m.clock.TotalMilliseconds()
		if ms > 100 then ms = 100
        m.clock.Mark()

		Update(ms)
		Draw()

        m.screen.SwapBuffers()
    end while
End Sub

'--- UTILITY FUNCTIONS ---

Function CacheFile(url as string, file as string, overwrite = false as boolean) as string
    tmpFile = "tmp:/" + file
    if overwrite or not m.files.Exists(tmpFile)
        http = CreateObject("roUrlTransfer")
        http.SetUrl(url)
        ret = http.GetToFile(tmpFile)
        if ret = 200
            print "CacheFile: "; url; " to "; tmpFile
        else
            print "File not cached! http return code: "; ret
            tmpFile = ""
        end if
    end if
    return tmpFile
End Function

Function Atan2(y, x) As Float
    x = 0.0 + x
    y = 0.0 + y

    if x > 0 then
        return Atn(y / x)
    else if x < 0 and y >= 0 then
        return Atn(y / x) + m.PI
    else if x < 0 then
        return Atn(y / x) - m.PI
    else if x = 0 and y > 0 then
        return m.PI / 2
    else if x = 0 and y <= 0 then
		return -m.PI / 2
	end if
    return 0.0
End Function
