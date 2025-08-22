'*************************************************************
'** Hello World example
'** Copyright (c) 2015 Roku, Inc.  All rights reserved.
'** Use of the Roku Platform is subject to the Roku SDK Licence Agreement:
'** https://docs.roku.com/doc/developersdk/en-us
'*************************************************************

Function CreateSprite(compositor, path, x, y) As Object

    bmp = CreateObject("roBitmap", "pkg:/images/sunflower.png")
    region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
    sprite = compositor.NewSprite(x, y, region, 999)
    sprite.SetData({ x: 0.0 + x, y: 0.0 + y, theta: Rnd(0) * 6.283 })
    return sprite

End Function

Function Atan2(y, x) As Float
    x = 0.0 + x
    y = 0.0 + y

    if x > 0 then
        return Atn(y / x)
    else if x < 0 and y >= 0 then
        return Atn(y / x) + 3.1416
    else if x < 0 then
        return Atn(y / x) - 3.1416
    else if x = 0 and y > 0 then
        return 3.1416 / 2
    end if

    return -3.1416 / 2.0

End Function

sub Main()

    screen = CreateObject("roScreen", True)
    m.port = CreateObject("roMessagePort")
    compositor = CreateObject("roCompositor")
    compositor.SetDrawTo(screen, &h00000000)
    clock = CreateObject("roTimespan")
    clock.Mark()
    screen.setMessagePort(m.port)
    screen.SetAlphaEnable(True)

    wallHeight = 25
    walls = []
    walls[0] = { x: 0, y: 0, w: screen.GetWidth(), h: wallHeight }
    walls[1] = { x: 0, y: 0, w: wallHeight, h: screen.GetHeight() }
    walls[2] = { x: screen.GetWidth() - wallHeight, y: 0, w: wallHeight, h: screen.GetHeight() }
    walls[3] = { x: 0, y: screen.GetHeight() - wallHeight, w: screen.GetWidth(), h: wallHeight }
    walls[4] = { x: 0, y: 250, w: 250 + wallHeight, h: wallHeight }
    walls[5] = { x: 250, y: 0, w: wallHeight, h: 100 }


    sprites = []
    sprites[0] = CreateSprite(compositor, "pkg:/images/sunflower.png", 50, 50)
    sprites[1] = CreateSprite(compositor, "pkg:/images/sunflower.png", 50, 100)
    sprites[2] = CreateSprite(compositor, "pkg:/images/sunflower.png", 50, 150)
    sprites[3] = CreateSprite(compositor, "pkg:/images/sunflower.png", 50, 200)

    while(true)
        msg = m.port.GetMessage()
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if

        ms = clock.TotalMilliseconds()
        clock.Mark()

        speed = 0.1
        size = 16
        for each sprite in sprites
            data = sprite.GetData()

            theta = data.theta
            dx = Cos(theta) * speed * ms
            dy = Sin(theta) * speed * ms

            x = data.x + dx
            y = data.y + dy

            collided = False

            for each wall in walls
                if wall.x < x and wall.x + wall.w > x then
                    dy = wall.y - y
                    if dy > 0 and dy < size and Sin(theta) > 0 then
                        correction = 1.000 * (size - dy) / Sin(theta)
                        print "y1"
                        print correction
                        x = x - correction * Cos(theta)
                        y = y - correction * Sin(theta)
                        theta = -theta
                        collided = True
                    end if

                    dy = (wall.y + wall.h) - y
                    if dy < 0 and dy > -size and Sin(theta) < 0 then
                        correction = 1.000 * (size + dy) / Sin(theta)
                        print "y2"
                        print correction
                        x = x - correction * Cos(theta)
                        y = y - correction * Sin(theta)
                        theta = -theta
                        collided = True
                    end if
                end if

                if wall.y < y and wall.y + wall.h > y and Cos(theta) > 0 then
                    dx = wall.x - x
                    if dx > 0 and dx < size then
                        correction = 1.000 * (size - dx) / Cos(theta)
                        print "x1"
                        print correction
                        x = x - correction * Cos(theta)
                        y = y - correction * Sin(theta)
                        theta = 3.1416-theta
                        collided = True
                    end if

                    dx = (wall.x + wall.w) - x
                    if dx < 0 and dx > -size and Cos(theta) < 0 then
                        correction = 1.000 * (size + dx) / Cos(theta)
                        print "x2"
                        print correction
                        x = x - correction * Cos(theta)
                        y = y - correction * Sin(theta)
                        theta = 3.1416-theta
                        collided = True
                    end if
                end if

                ' if wall.y < y + size and wall.y + wall.h > y + size then
                '     if wall.x - x - size <= size and wall.x - x - size >= 0 then
                '         x = wall.x - size - size
                '         theta = 3.1416 - theta
                '         collided = True
                '     else if wall.w + wall.x - x > 0 and wall.w + wall.x - x < size then
                '         x = wall.x + wall.w
                '         theta = 3.1416 - theta
                '         collided = True
                '     end if
                ' end if
                '
                ' points = []
                ' points[0] = {x: wall.x, y: wall.y}
                ' points[1] = {x: wall.x + wall.w, y: wall.y}
                ' points[2] = {x: wall.x, y: wall.y + wall.h}
                ' points[3] = {x: wall.x + wall.w, y: wall.y + wall.h}
                '
                ' for each point in points
                '     dx = 0.0 + point.x - (x + size)
                '     dy = 0.0 + point.y - (y + size)
                '
                '     dist = dx * dx + dy * dy
                '     if dist < size * size then
                '         atan = Atan2(dy, dx)
                '         theta = atan + atan - theta
                '         collided = True
                '     end if
                '
                ' end for

            end for

            if collided then
                theta = theta + Rnd(0) * 1.5707 - 0.7853
            end if
            sprite.SetData({ theta: theta, x: x, y: y })
            sprite.MoveTo(x - size, y - size)
        end for

        compositor.DrawAll()
        for each wall in walls
            screen.DrawRect(wall.x, wall.y, wall.w, wall.h, &h000080FF)
        end for

        screen.SwapBuffers()
    end while
end sub

