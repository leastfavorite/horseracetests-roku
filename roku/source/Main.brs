' todo
' one-way walls

Sub Init()
  m.debug = True

  m.horseBitmap = CreateObject("roBitmap", "pkg:/images/horses.png")
  m.countdownBitmap = CreateObject("roBitmap", "pkg:/images/bets.png")
  m.goalBitmap = CreateObject("roBitmap", "pkg:/images/goal.png")

  m.PI = 3.1415926
  m.R = 16

  m.port = CreateObject("roMessagePort")

  m.screen = CreateObject("roScreen", True)
  m.screen.SetMessagePort(m.port)
  m.screen.SetAlphaEnable(True)

  m.W = m.screen.GetWidth()
  m.H = m.screen.GetHeight()

  m.horses = CreateObject("roArray", 8, False)
  for i = 0 to 7
    region = CreateObject("roRegion", m.horseBitmap, i*(2*m.R), 0, 2*m.R, 2*m.R)
    m.horses[i] = { region: region }
  end for

  cbw = m.countdownBitmap.GetWidth()
  cbh = m.countdownBitmap.GetHeight() / 10
  countdownRegions = CreateObject("roArray", 10, False)
  for i = 0 to 9
    countdownRegions[i] = CreateObject("roRegion", m.countdownBitmap, 0, i*cbh, cbw, cbh)
    countdownRegions[i].SetTime(1000)
  end for
  m.countdown = { regions: countdownRegions, w: cbw, h: cbh }

  m.clock = CreateObject("roTimespan")
  m.clock.Mark()

  m.screenshot = CreateObject("roBitmap", { width: m.W, height: m.H, AlphaEnable: True, name: "Screenshot" })

  Reset()

End Sub

Function Draw(screen as Object)

  if m.state = "victory" then
    p = (m.transitionTimer + 5000.0) / 5000.0
    fp = 1.0 - 2 ^ (-10.0 * p)

    scale = 1.0 + 10.0 * p

    focalX = (1.0 - fp) * (m.W / 2.0) + fp * m.winner.x
    focalY = (1.0 - fp) * (m.H / 2.0) + fp * m.winner.y

    x = m.W / 2.0 - focalX * scale
    y = m.H / 2.0 - focalY * scale
    screen.DrawScaledObject(x, y, scale, scale, m.screenshot, &hFFFFFFFF)
  else
    DrawGame(screen)
  end if
End Function

Function DrawGame(screen as Object)
  screen.DrawObject(0, 0, m.map)

  screen.DrawObject(m.data.goal.x - m.R, m.data.goal.y - m.R, m.goalBitmap)

  for each horse in m.horses
    screen.DrawObject(horse.x - m.R, horse.y - m.R, horse.region)
  end for

  EXTENT = 24
  if m.debug then
    for each horse in m.horses
      x1 = horse.x
      y1 = horse.y
      x2 = horse.x + Cos(horse.theta) * EXTENT * horse.speed
      y2 = horse.y + Sin(horse.theta) * EXTENT * horse.speed
      screen.DrawLine(x1, y1, x2, y2, &hFFFF00FF)
    end for
  end if

  if m.state = "countdown" then
    cd = m.countdown
    ind = (m.transitionTimer + 10000) / 1000
    screen.DrawObject(cd.x, cd.y, cd.regions[ind])
  end if

End Function

Function Reset()
  m.transitionTimer = -10000
  m.state = "countdown"

  m.map = CreateObject("roBitmap", "pkg:/maps/1.png")
  m.data = ParseJson(ReadAsciiFile("pkg:/maps/1.json"))

  for i = 0 to 7
    spawn = m.data.spawns[i]
    m.horses[i].x = 0.0 + spawn.x
    m.horses[i].y = 0.0 + spawn.y
    m.horses[i].theta = Rnd(0) * 2.0 * m.PI
    m.horses[i].speed = 1.0
  end for

  cTheta = Rnd(0) * m.PI * 2
  m.countdown.xv = Cos(cTheta)
  m.countdown.yv = Sin(cTheta)
  m.countdown.x = Rnd(0) * (m.W - m.countdown.w)
  m.countdown.y = Rnd(0) * (m.H - m.countdown.h)
End Function

Function Update(ms as float)
  m.transitionTimer += ms
  if m.state = "countdown" then
    MoveCountdown(ms)
    if m.transitionTimer >= 0 then
      m.state = "playing"
    end if
  else if m.state = "playing" then
    MoveHorses(ms)

    for each h in m.horses
      dx = h.x - m.data.goal.x
      dy = h.y - m.data.goal.y
      if dx * dx + dy * dy < 4 * m.R * m.R then

        DrawGame(m.screenshot)
        m.winner = h
        m.state = "victory"
        m.transitionTimer = -5000
        exit for
      end if
    end for
  else if m.state = "victory"
    if m.transitionTimer >= 0 then
      Reset()
    end if
  end if
End Function

Function MoveCountdown(ms as float)
  COUNTDOWN_SPEED = 0.15

  cd = m.countdown
  cd.x += cd.xv * ms * COUNTDOWN_SPEED
  cd.y += cd.yv * ms * COUNTDOWN_SPEED

  if cd.x < 0 then
    cd.xv = Abs(cd.xv)
  else if cd.x > m.W - cd.w then
    cd.xv = -Abs(cd.xv)
  end if

  if cd.y < 0 then
    cd.yv = Abs(cd.yv)
  else if cd.y > m.H - cd.h then
    cd.yv = -Abs(cd.yv)
  end if
End Function

Function MoveHorses(ms as float)
  SPEED_UP = 1.01
  MAX_HORSE_SPEED = 1.5

  R = m.R
  GLOBAL_SPEED = 0.1
  EPSILON = 1.1
  for each h in m.horses
    h.speed *= SPEED_UP
    if h.speed > MAX_HORSE_SPEED then h.speed = MAX_HORSE_SPEED

    h.x += GLOBAL_SPEED * h.speed * ms * Cos(h.theta)
    h.y += GLOBAL_SPEED * h.speed * ms * Sin(h.theta)

    collided = False
    for each polygon in m.data.walls
      for each pt in polygon
        ax = 0.0 + h.x - pt.x
        ay = 0.0 + h.y - pt.y
        vx = Cos(h.theta)
        vy = Sin(h.theta)
        adv = ax*vx+ay*vy
        ada = ax*ax+ay*ay

        if ada > R*R then
          continue for
        end if

        det = adv * adv - ada + R*R
        t = -adv - Sqr(det)

        if t < 0 and t > -R then
          h.x += EPSILON * t * vx
          h.y += EPSILON * t * vy

          ax = 0.0 + h.x - pt.x
          ay = 0.0 + h.y - pt.y
          normal = Atan2(ay, ax) + m.PI / 2.0
          h.theta = 2.0 * normal - h.theta

          collided = True
          h.speed = 1.0
          exit for
        end if
      end for
      if collided then exit for

      for i = 0 to polygon.Count() - 1
        p1 = polygon[i]
        p2 = polygon[(i + 1) mod polygon.Count()]
        ax = 0.0 + p2.x - p1.x
        ay = 0.0 + p2.y - p1.y
        bx = 0.0 + h.x - p1.x
        by = 0.0 + h.y - p1.y
        qs = (ax*bx+ay*by)/(ax*ax+ay*ay)

        if qs <= 0.0 or qs >= 1.0 then
          continue for
        end if

        qx = ax * qs
        qy = ay * qs
        vx = Cos(h.theta)
        vy = Sin(h.theta)

        aax = h.x - qx - p1.x
        aay = h.y - qy - p1.y

        qqs = (ax*vx+ay*vy)/(ax*ax+ay*ay)
        bbx = vx-qqs*ax
        bby = vy-qqs*ay

        ada = aax*aax + aay*aay
        adb = aax*bbx + aay*bby
        bdb = bbx*bbx + bby*bby

        det = adb*adb - bdb*(ada-R*R)
        t = (-adb - Sqr(det)) / bdb

        if t >= 0 or t <= -R then
          continue for
        end if

        h.x += vx * EPSILON*t
        h.y += vy * EPSILON*t

        ref = Atan2(ay, ax)
        h.theta = ref + ref - h.theta
        collided = True
        h.speed = 1.0
        exit for
      end for
      if collided then exit for
    end for
  end for

  for i = 0 to m.horses.Count() - 1
    for j = i+1 to m.horses.Count() - 1
      h1 = m.horses[i]
      h2 = m.horses[j]

      sprite2 = m.horses[j]
      x2 = sprite2.x
      y2 = sprite2.y
      theta2 = sprite2.theta
      speed2 = sprite2.speed

      dx = h1.x - h2.x
      dy = h1.y - h2.y
      c = dx*dx+dy*dy-4*R*R

      if c >= 0 then
        continue for
      end if

      dvx = h1.speed * Cos(h1.theta) - h2.speed * Cos(h2.theta)
      dvy = h1.speed * Sin(h1.theta) - h2.speed * Sin(h2.theta)
      b = (dx*dvx+dy*dvy)
      a = (dvx*dvx+dvy*dvy)

      t = - (b+Sqr(b*b - a*c)) / a

      h1.x += EPSILON * t * h1.speed * Cos(h1.theta)
      h1.y += EPSILON * t * h1.speed * Sin(h1.theta)

      h2.x += EPSILON * t * h2.speed * Cos(h2.theta)
      h2.y += EPSILON * t * h2.speed * Sin(h2.theta)

      normal = Atan2(h2.y - h1.y, h2.x - h1.x) + m.PI / 2.0

      h1.theta = 2.0 * normal - h1.theta
      h1.speed = 1.0

      h2.theta = 2.0 * normal - h2.theta
      h2.speed = 1.0
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
    if ms > 40 then ms = 40
    m.clock.Mark()

    Update(ms)

    Draw(m.screen)

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

