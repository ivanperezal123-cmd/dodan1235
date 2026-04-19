-- ══════════════════════════════════════════════════════════════════════
-- Die of Death — Animation System v5
-- Replica EXACTA de SetRunAnim/SetWalkAnim/SetIdleAnim/ApplyNewAnimations
-- ══════════════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RS               = game:GetService("ReplicatedStorage")

local SERVER = "http://127.0.0.1:5757"

local _httpFn = nil
do
    local attempts = {
        function() return request end,
        function() return http_request end,
        function() return http and http.request end,
    }
    for _, attempt in ipairs(attempts) do
        local ok, fn = pcall(attempt)
        if ok and type(fn) == "function" then _httpFn = fn; break end
    end
    if _httpFn then print("[DOD_AN] HTTP ✅")
    else warn("[DOD_AN] Sin HTTP — señales al server desactivadas") end
end

local function httpPost(path, body)
    if not _httpFn then return end
    task.spawn(function()
        pcall(_httpFn, {
            Url     = SERVER .. path,
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = body,
        })
    end)
end

local LocalPlayer = Players.LocalPlayer
local Character   = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid    = Character:WaitForChild("Humanoid")

-- ── PERSONAJES ────────────────────────────────────────────────────────
local CHARS = {
    Pursuer = {
        rsAnimPath = {"Characters","Killer","Pursuer","Default","Animations"},
        Abilities = {
            M1   = { id = "rbxassetid://78618685223511", speed = 1 },
            Q    = {
                { id = "rbxassetid://89729648321106", speed = 1 },
                { id = "rbxassetid://96288633191198", speed = 1 },
            },
            R    = { { id = "rbxassetid://109803302620003", speed = 1 } },
            F    = {
                { id = "rbxassetid://130725432915474", speed = 1 },
                { id = "rbxassetid://102302720518230", speed = 1, duration = 6, forcedDuration = true },
            },
            Stun = { id = "rbxassetid://87593869628310", speed = 1, duration = 3 },
        },
        keys = { M1=true, Q=true, E=false, R=true, F=true, G=true },
    },
    Artful = {
        rsAnimPath = {"Characters","Killer","Artful","Default","Animations"},
        Abilities = {
            M1 = { id = "rbxassetid://80787680522855", speed = 1 },
            Q  = { { id = "rbxassetid://93500762918403", speed = 1 } },
            E  = { { id = "rbxassetid://73671880665307", speed = 1 } },
            R  = { { id = "rbxassetid://112076293590914", speed = 1 } },
            F  = { { id = "rbxassetid://131794393567380", speed = 1 } },  -- spawn bot artful
        },
        keys = { M1=true, Q=true, E=true, R=true, F=true, G=false },
    },
}

-- ── ANIMS UNIVERSALES R6 (IDs oficiales Roblox) ──────────────────────────────
local U_IDLE      = "rbxassetid://180435571"   -- Idle 1 R6 oficial
local U_WALK      = "rbxassetid://180426354"   -- Walk R6 oficial (también usado para run)
local U_TOOLHOLD  = "rbxassetid://182393478"   -- Tool Hold (Q durante 2s → pared)

-- ── ESTADO ────────────────────────────────────────────────────────────
local currentChar     = "Pursuer"
local abilityBusy     = false
local isStunned       = false
local lastClick       = {}
local ATTACK_CD       = 0.3
local STUN_CD         = 1.0
local FADE            = 0.1
local CurrentAtkTrack = nil
local inputConns      = {}
local systemActive    = false
local universalActive = false  -- modo universal R6

-- ── STALK (Pursuer F — toggle ON/OFF puro, sin tiempo límite) ─────────────────
local stalkActive     = false
local stalkLoopTrack  = nil
local stalkNoclipConn = nil
local stalkCamConn    = nil
local stalkOldWS      = 10
local stalkOldSS      = 26

-- ══════════════════════════════════════════════════════════════════════
-- REPLICA EXACTA DE DOD.LUA
-- ══════════════════════════════════════════════════════════════════════

local function ReturnAnimFolder()
    if Character:FindFirstChild("Animations") then
        return Character:WaitForChild("Animations")
    end
    return nil
end

local function SetRunAnim(run)
    pcall(function()
        local stopper = Humanoid or Character:FindFirstChildOfClass("AnimationController")
        for _, v in next, stopper:GetPlayingAnimationTracks() do v:Stop() end
    end)
    local AnimationFolder = ReturnAnimFolder()
    if not AnimationFolder then return end
    pcall(function() if AnimationFolder:FindFirstChild("HurtSprint")   then AnimationFolder.HurtSprint.AnimationId   = run end end)
    pcall(function() if AnimationFolder:FindFirstChild("NormalSprint") then AnimationFolder.NormalSprint.AnimationId = run end end)
    pcall(function() if AnimationFolder:FindFirstChild("OldSprint")    then AnimationFolder.OldSprint.AnimationId    = run end end)
    pcall(function() if AnimationFolder:FindFirstChild("Sprint")       then AnimationFolder.Sprint.AnimationId       = run end end)
end

local function SetWalkAnim(walk)
    pcall(function()
        local stopper = Humanoid or Character:FindFirstChildOfClass("AnimationController")
        for _, v in next, stopper:GetPlayingAnimationTracks() do v:Stop() end
    end)
    local AnimationFolder = ReturnAnimFolder()
    if not AnimationFolder then return end
    pcall(function() if AnimationFolder:FindFirstChild("Walk")    then AnimationFolder.Walk.AnimationId    = walk end end)
    pcall(function() if AnimationFolder:FindFirstChild("OldWalk") then AnimationFolder.OldWalk.AnimationId = walk end end)
end

local function SetIdleAnim(idle)
    pcall(function()
        local stopper = Humanoid or Character:FindFirstChildOfClass("AnimationController")
        for _, v in next, stopper:GetPlayingAnimationTracks() do v:Stop() end
    end)
    local AnimationFolder = ReturnAnimFolder()
    if not AnimationFolder then return end
    pcall(function() if AnimationFolder:FindFirstChild("Idle")    then AnimationFolder.Idle.AnimationId    = idle end end)
    pcall(function() if AnimationFolder:FindFirstChild("OldIdle") then AnimationFolder.OldIdle.AnimationId = idle end end)
end

local function ApplyNewAnimations()
    pcall(function()
        workspace:SetAttribute("AnimationsEnabled", false)
        task.wait()
        workspace:SetAttribute("AnimationsEnabled", true)
    end)
end

-- ══════════════════════════════════════════════════════════════════════
-- SISTEMA DE ANIMACIONES DE MOVIMIENTO — Heartbeat loop
-- Detecta velocidad del HRP cada frame y cambia idle/walk/sprint
-- Funciona tanto en lobby como en partida
-- ══════════════════════════════════════════════════════════════════════

local movementConn   = nil
local movementTracks = {}

local function stopMovementSystem()
    if movementConn then movementConn:Disconnect(); movementConn = nil end
    for _, t in pairs(movementTracks) do
        pcall(function() t:Stop(0) end)
    end
    movementTracks = {}
end

local function loadTrackFromId(animId)
    if not animId or animId == "" then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    local ok, tr = pcall(function()
        local animator = Humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = Humanoid
        end
        return animator:LoadAnimation(anim)
    end)
    return ok and tr or nil
end

local function startMovementSystem(charName)
    stopMovementSystem()

    local cfg = CHARS[charName]

    -- Navegar RS hasta la carpeta de animaciones
    local ok, animFolder = pcall(function()
        local f = RS
        for _, part in ipairs(cfg.rsAnimPath) do
            f = f:WaitForChild(part)
        end
        return f
    end)
    if not ok or not animFolder then
        warn("[DOD_AN] No se encontró animFolder para " .. charName)
        return
    end

    local function getId(...)
        for _, name in ipairs({...}) do
            local v = animFolder:FindFirstChild(name)
            if v and v.AnimationId ~= "" then return v.AnimationId end
        end
        return nil
    end

    local idleId   = getId("Idle",   "OldIdle")
    local walkId   = getId("Walk",   "OldWalk")
    local sprintId = getId("Sprint", "OldSprint", "NormalSprint", "HurtSprint")

    if not idleId then warn("[DOD_AN] Sin idle id para " .. charName); return end

    local idleTrack   = loadTrackFromId(idleId)
    local walkTrack   = walkId   and loadTrackFromId(walkId)   or nil
    local sprintTrack = sprintId and loadTrackFromId(sprintId) or nil

    if not idleTrack then warn("[DOD_AN] No se pudo cargar idle track"); return end

    -- Prioridades (habilidades usan Action4, movimiento tiene que ser menor)
    idleTrack.Priority = Enum.AnimationPriority.Idle
    if walkTrack   then walkTrack.Priority   = Enum.AnimationPriority.Movement end
    if sprintTrack then sprintTrack.Priority = Enum.AnimationPriority.Action   end

    movementTracks = { idle = idleTrack, walk = walkTrack, sprint = sprintTrack }

    -- Parar todo lo que esté corriendo antes de empezar
    pcall(function()
        for _, t in ipairs(Humanoid:GetPlayingAnimationTracks()) do
            t:Stop(0)
        end
    end)

    idleTrack:Play(0.1)

    local RunService = game:GetService("RunService")
    local hrp        = Character:WaitForChild("HumanoidRootPart")
    local WALK_MIN   = 0.5    -- velocidad mínima para walk
    local SPRINT_MIN = 15     -- velocidad mínima para sprint
    local lastState  = "idle"

    movementConn = RunService.Heartbeat:Connect(function()
        if not Character or not Character.Parent then return end
        if not hrp or not hrp.Parent then return end

        local vel   = hrp.AssemblyLinearVelocity
        local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude

        local newState
        if speed >= SPRINT_MIN and sprintTrack then
            newState = "sprint"
        elseif speed >= WALK_MIN then
            newState = "walk"
        else
            newState = "idle"
        end

        if newState == lastState then return end
        lastState = newState

        -- Parar todas
        if idleTrack   and idleTrack.IsPlaying   then idleTrack:Stop(0.15)   end
        if walkTrack   and walkTrack.IsPlaying   then walkTrack:Stop(0.15)   end
        if sprintTrack and sprintTrack.IsPlaying then sprintTrack:Stop(0.15) end

        -- Arrancar la correcta
        if newState == "idle" then
            idleTrack:Play(0.15)
        elseif newState == "walk" then
            if walkTrack then walkTrack:Play(0.15) else idleTrack:Play(0.15) end
        elseif newState == "sprint" then
            sprintTrack:Play(0.15)
        end
    end)

    print("[DOD_AN] movimiento iniciado: " .. charName .. " | idle=" .. idleId)
end

local function applyMovementAnims(charName)
    task.spawn(function()
        startMovementSystem(charName)
    end)
end

-- ── NOTIFY AL BOT ─────────────────────────────────────────────────────────────
local function notifyArtfulSpawn()
    httpPost("/artful/spawn", '{"trigger":true}')
end

-- En modo DoD Artful, Q siempre activa bot1 (fotosontosis)
local function notifyArtfulWall(active, lx, ly, lz)
    if active then
        local body = string.format(
            '{"active":true,"lx":%.4f,"ly":%.4f,"lz":%.4f,"formation":"side"}',
            lx or 0, ly or 0, lz or 1)
        httpPost("/artful/wall1", body)
    else
        httpPost("/artful/wall1", '{"active":false}')
    end
end

-- ══════════════════════════════════════════════════════════════════════
-- SISTEMA UNIVERSAL R6 — usa IDs públicos, sin depender de RS ni DoD
-- ══════════════════════════════════════════════════════════════════════
local universalConn   = nil
local universalTracks = {}

local function stopUniversalMovement()
    if universalConn then universalConn:Disconnect(); universalConn = nil end
    for _, t in pairs(universalTracks) do
        pcall(function()
            if type(t) == "userdata" then
                if t.Stop then t:Stop(0)
                elseif t.Disconnect then t:Disconnect() end
            end
        end)
    end
    universalTracks = {}
    pcall(function() Humanoid.WalkSpeed = 16 end)
end

local function startUniversalMovement()
    stopUniversalMovement()
    stopMovementSystem()

    local RunService = game:GetService("RunService")
    local UIS2       = game:GetService("UserInputService")
    local hrp        = Character:WaitForChild("HumanoidRootPart")
    local baseSpeed  = Humanoid.WalkSpeed

    local function loadU(id, prio)
        if not id or id == "" then return nil end
        local anim = Instance.new("Animation")
        anim.AnimationId = id
        local animator = Humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator"); animator.Parent = Humanoid
        end
        local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
        if not ok then return nil end
        tr.Priority = prio
        return tr
    end

    local idleTrack = loadU(U_IDLE, Enum.AnimationPriority.Idle)
    local walkTrack = loadU(U_WALK, Enum.AnimationPriority.Movement)

    if not idleTrack then
        warn("[DOD_AN] Universal: no se pudo cargar idle"); return
    end

    pcall(function()
        for _, t in ipairs(Humanoid:GetPlayingAnimationTracks()) do t:Stop(0) end
    end)

    universalTracks = { idle = idleTrack, walk = walkTrack }
    idleTrack:Play(0.15)

    local WALK_MIN    = 0.5
    local lastState   = "idle"
    local ctrlWasHeld = false

    universalConn = RunService.Heartbeat:Connect(function()
        if not Character or not Character.Parent then return end
        if not hrp or not hrp.Parent then return end

        local vel   = hrp.AssemblyLinearVelocity
        local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude

        local ctrlHeld = UIS2:IsKeyDown(Enum.KeyCode.LeftControl)
                      or UIS2:IsKeyDown(Enum.KeyCode.RightControl)
        if ctrlHeld and not ctrlWasHeld then
            pcall(function() Humanoid.WalkSpeed = baseSpeed + 4 end)
            ctrlWasHeld = true
        elseif not ctrlHeld and ctrlWasHeld then
            pcall(function() Humanoid.WalkSpeed = baseSpeed end)
            ctrlWasHeld = false
        end

        local newState = speed >= WALK_MIN and "walk" or "idle"
        if newState == lastState then return end
        lastState = newState

        if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(0.15) end
        if walkTrack and walkTrack.IsPlaying then walkTrack:Stop(0.15) end

        if newState == "idle" then
            idleTrack:Play(0.15)
        else
            if walkTrack then walkTrack:Play(0.15) else idleTrack:Play(0.15) end
        end
    end)

    print("[DOD_AN] Universal activo | Ctrl=run | Q=Tool Hold → pared")
end

-- ── PARED DUAL: tecla configurable, dos bots, tres formaciones ──────────────
local wallKey       = Enum.KeyCode.Q   -- tecla activa (configurable desde GUI)
local wallFormation = "side"           -- "side" | "stack"
local wallBusy      = false
local wallStep      = 0  -- 0=ninguno, 1=bot1 activo, 2=bot2 activo
local formationMode = nil  -- nil = normal | "side" | "stack" → Q dispara todos en formación

-- Dict de wall bots (igual que IGNORED_BOTS en botz) → O(1) lookup
local WALL_BOTS_DICT = {
    ["fotosontosis"] = 1,
    ["pedrato527"]   = 2,
    ["antitortas3000"] = 3,
}
local WALL_BOTS_NAMES = { "fotosontosis", "pedrato527", "antitortas3000" }

-- Detecta qué wall bots están conectados (patrón botz: itera Players una vez)
local function getConnectedWallBots()
    local connected = {}
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        local idx = WALL_BOTS_DICT[p.Name:lower()]
        if idx then connected[idx] = p.Name:lower() end
    end
    return connected  -- {1="fotosontosis", 2="pedrato527"} según quién esté
end

-- Reproducir Tool Hold en el personaje del owner
local function playToolHold()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator"); animator.Parent = hum
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = U_TOOLHOLD
    local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and tr then
        tr.Priority = Enum.AnimationPriority.Action4
        tr.Looped   = true
        tr:Play(0.1)
        task.wait(2)
        tr:Stop(0.2)
    end
end

-- Capturar look vector del HRP del owner
local function getLook()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local lv = hrp.CFrame.LookVector
        return lv.X, lv.Y, lv.Z
    end
    return 0, 0, 1
end

-- Enviar señal al endpoint PROPIO del bot (wall1 o wall2)
-- Cuando no hay formationMode activo se manda "none" para que el bot no aplique offset lateral
local function sendWall(botIndex, lx, ly, lz)
    local endpoint = "/artful/wall" .. botIndex
    local fmt = formationMode or "none"
    local body = string.format(
        '{"active":true,"lx":%.4f,"ly":%.4f,"lz":%.4f,"formation":"%s"}',
        lx, ly, lz, fmt)
    httpPost(endpoint, body)
    print("[DOD_AN] " .. endpoint .. " → formation=" .. fmt)
end

local function fireWall()
    if not universalActive then return end
    if wallBusy then return end
    wallBusy = true
    task.spawn(function()
        local connected = getConnectedWallBots()

        local available = {}
        for i = 1, #WALL_BOTS_NAMES do
            if connected[i] then table.insert(available, i) end
        end

        if #available == 0 then wallBusy = false; return end

        playToolHold()
        local lx, ly, lz = getLook()

        if formationMode then
            -- Modo formación: todos los bots a la vez con la formación activa
            for i = 1, #WALL_BOTS_NAMES do
                if connected[i] then
                    local body = string.format(
                        '{"active":true,"lx":%.4f,"ly":%.4f,"lz":%.4f,"formation":"%s"}',
                        lx, ly, lz, formationMode)
                    httpPost("/artful/wall" .. i, body)
                end
            end
        else
            -- Comportamiento normal: un bot a la vez en orden
            if wallStep >= #available then wallStep = 0 end
            local botIdx = available[wallStep + 1]
            sendWall(botIdx, lx, ly, lz)
            wallStep = (wallStep + 1) % #available
        end

        wallBusy = false
    end)
end

game:GetService("UserInputService").InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == wallKey then fireWall() end
end)

-- ══════════════════════════════════════════════════════════════════════
-- SISTEMA PORTAL v2
-- Al activar  → fotosontosis se TP adelante del owner cubriéndolo (instante)
-- Click mapa  → raycast al cursor → coordenadas al servidor
--              pedrato527 sube en ese punto como pared
--              cuando pedrato termina → owner se TPea atrás de pedrato
-- ══════════════════════════════════════════════════════════════════════
do
    local portalActive   = false
    local portalBusy     = false   -- evita doble click mientras pedrato sube
    local portalClickCon = nil
    local portalPollTh   = nil

    local UIS2 = game:GetService("UserInputService")

    local function portalPost(path, body)
        local fn = request or (http and http.request) or nil
        if not fn then return end
        task.spawn(function()
            pcall(fn, {
                Url     = SERVER .. path,
                Method  = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body    = body,
            })
        end)
    end

    local function portalGet(path)
        local fn = request or (http and http.request) or nil
        if not fn then return nil end
        local ok, res = pcall(fn, { Url = SERVER .. path, Method = "GET" })
        if ok and res and res.StatusCode == 200 then return res.Body end
        return nil
    end

    -- TP del owner detrás de pedrato al terminar la subida
    -- Pedrato mira hacia el owner (facingDir = -lookVector del click),
    -- así que "atrás de pedrato" = posición de pedrato + su lookVector * 3
    local function portalTpOwner(px, py, pz, lx, lz)
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local pedrLook = Vector3.new(lx, 0, lz)
        if pedrLook.Magnitude < 0.01 then pedrLook = Vector3.new(0, 0, 1) end
        pedrLook = pedrLook.Unit
        -- Pedrato mira hacia afuera → owner queda atrás = pos - pedrLook * 3
        local dest = Vector3.new(px, py, pz) - pedrLook * 3
        pcall(function()
            hrp.CFrame = CFrame.new(dest, dest + pedrLook)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        print("[PORTAL] Owner tpeado detrás de pedrato ✅")
    end

    -- Polling: espera ready=true del servidor (pedrato terminó de subir)
    local function portalStartPoll()
        if portalPollTh then task.cancel(portalPollTh); portalPollTh = nil end
        portalPollTh = task.spawn(function()
            while portalActive do
                task.wait(0.12)
                local body = portalGet("/artful/portal")
                if not body then continue end
                if body:find('"ready"%s*:%s*true') then
                    local px = tonumber(body:match('"px"%s*:%s*([%-%.%d]+)')) or 0
                    local py = tonumber(body:match('"py"%s*:%s*([%-%.%d]+)')) or 0
                    local pz = tonumber(body:match('"pz"%s*:%s*([%-%.%d]+)')) or 0
                    local lx = tonumber(body:match('"lx"%s*:%s*([%-%.%d]+)')) or 0
                    local lz = tonumber(body:match('"lz"%s*:%s*([%-%.%d]+)')) or 1
                    portalTpOwner(px, py, pz, lx, lz)
                    portalPost("/artful/portal", '{"reset":true}')
                    portalBusy  = false
                    portalActive = false
                    portalDisconnectClick()
                    -- Avisar a la GUI para que actualice el botón
                    if _G.__PORTAL_ON_DONE then _G.__PORTAL_ON_DONE() end
                    break
                end
            end
            portalPollTh = nil
        end)
    end

    -- Fotosontosis se cubre adelante del owner instantáneamente (sin subir)
    -- Se manda como wall1 activo pero el bot lo resuelve con activatePortalCover
    local function portalCoverOwner()
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local lv = hrp.CFrame.LookVector
        portalPost("/artful/portal", '{"reset":true}')
        -- Flag especial "cover":true → botart sabe que tiene que hacer el TP
        -- instantáneo en vez de la subida normal
        local body = string.format(
            '{"active":true,"cover":true,"lx":%.4f,"ly":%.4f,"lz":%.4f,"formation":"side"}',
            lv.X, lv.Y, lv.Z)
        portalPost("/artful/portal/cover", body)
        print("[PORTAL] fotosontosis → cover owner")
    end

    -- Click en el mapa: raycast → coordenadas → pedrato sube ahí
    local function portalOnClick()
        if portalBusy then return end

        local cam = workspace.CurrentCamera
        if not cam then return end
        local mousePos = UIS2:GetMouseLocation()
        local ray      = cam:ViewportPointToRay(mousePos.X, mousePos.Y)

        local rcParams = RaycastParams.new()
        local excl = {}
        if LocalPlayer.Character then table.insert(excl, LocalPlayer.Character) end
        rcParams.FilterDescendantsInstances = excl
        rcParams.FilterType = Enum.RaycastFilterType.Exclude

        local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, rcParams)
        if not result then return end

        local wp = result.Position
        -- Dirección del click: desde el owner hacia el punto clicado (aplanada en Y)
        local ownerHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local clickDir = Vector3.new(0, 0, 1)
        if ownerHRP then
            local flat = Vector3.new(wp.X - ownerHRP.Position.X, 0, wp.Z - ownerHRP.Position.Z)
            if flat.Magnitude > 0.1 then clickDir = flat.Unit end
        end

        portalBusy = true
        -- Mandar destino a servidor + activar pedrato (wall2)
        -- lx/lz = clickDir (de donde viene el portal), pedrato mirará hacia el owner (-clickDir)
        local body = string.format(
            '{"active":true,"lx":%.4f,"ly":%.4f,"lz":%.4f,"wx":%.3f,"wy":%.3f,"wz":%.3f,"formation":"side"}',
            clickDir.X, 0, clickDir.Z, wp.X, wp.Y, wp.Z)
        portalPost("/artful/wall2portal", body)
        portalStartPoll()
        print(string.format("[PORTAL] Click → pedrato va a %.1f %.1f %.1f", wp.X, wp.Y, wp.Z))
    end

    local function portalConnectClick()
        if portalClickCon then return end
        portalClickCon = UIS2.InputBegan:Connect(function(inp, gp)
            if gp then return end
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            portalOnClick()
        end)
    end

    local function portalDisconnectClick()
        if portalClickCon then portalClickCon:Disconnect(); portalClickCon = nil end
        if portalPollTh   then task.cancel(portalPollTh); portalPollTh = nil end
        portalBusy = false
    end

    _G.__PORTAL_TOGGLE = function(v)
        portalActive = v
        if v then
            portalPost("/artful/portal", '{"reset":true}')
            portalBusy = false
            portalCoverOwner()   -- fotosontosis cubre al owner al activar
            portalConnectClick() -- espera click para pedrato
        else
            portalDisconnectClick()
            portalPost("/artful/portal", '{"reset":true}')
        end
    end

    print("[PORTAL v2] sistema cargado ✅")
end

-- ══════════════════════════════════════════════════════════════════════
-- HABILIDADES
-- ══════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════
-- INVISIBILIDAD  (usada por el stalk)
-- ══════════════════════════════════════════════════════════════════════
local function applyInvisibility(bool)
    if bool == false then
        task.spawn(function()
            for _, v in next, Humanoid:GetPlayingAnimationTracks() do
                v.Priority = Enum.AnimationPriority.Core
                v:AdjustSpeed(0); v:Stop(0)
            end
        end)
        if stalkNoclipConn then stalkNoclipConn:Disconnect(); stalkNoclipConn = nil end
        if stalkCamConn then
            stalkCamConn:Disconnect(); stalkCamConn = nil
            pcall(function() workspace.CurrentCamera.CameraSubject = Humanoid end)
        end
    else
        local function nocollision()
            for _, v in pairs(Character:GetDescendants()) do
                if v and v:IsA("BasePart") and v.CanCollide and v.Name ~= "HumanoidRootPart" then
                    v.CanCollide = false
                end
            end
            local hrp = Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CanCollide = true end
        end
        stalkNoclipConn = game:GetService("RunService").Stepped:Connect(nocollision)
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if hrp then workspace.CurrentCamera.CameraSubject = hrp end
        stalkCamConn = workspace.CurrentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
            local h = Character:FindFirstChild("HumanoidRootPart")
            if h then workspace.CurrentCamera.CameraSubject = h end
        end)
        local Anim = Instance.new("Animation")
        Anim.AnimationId = "rbxassetid://90444351114401"
        local la = Humanoid:LoadAnimation(Anim)
        la.Priority = Enum.AnimationPriority.Action4
        repeat task.wait() until la.Length > 0
        la:Play(); repeat task.wait() until la.IsPlaying
        la:AdjustSpeed(0); la.TimePosition = 2.2
    end
end

-- Desactiva el stalk: fade-in + restaurar velocidades
local function deactivateStalk()
    if not stalkActive then return end
    stalkActive = false
    if stalkLoopTrack and stalkLoopTrack.IsPlaying then stalkLoopTrack:Stop(0.1) end
    stalkLoopTrack = nil
    for i = 1, 10 do
        for _, v in next, Character:GetDescendants() do
            if (v:IsA("BasePart") or v:IsA("SpecialMesh")) and v.Name ~= "HumanoidRootPart" then
                pcall(function() v.Transparency = math.max(0, v.Transparency - 0.1) end)
            end
        end
        task.wait(0.05)
    end
    applyInvisibility(false)
    Character:SetAttribute("WalkSpeed",  stalkOldWS)
    Character:SetAttribute("SprintSpeed", stalkOldSS)
end

-- Activa el stalk: sonidos + fade-out + invis + boost
local function activateStalk()
    stalkActive = true
    stalkOldWS  = Character:GetAttribute("WalkSpeed")  or 10
    stalkOldSS  = Character:GetAttribute("SprintSpeed") or 26

    local hrp    = Character:FindFirstChild("HumanoidRootPart")
    local RS_srv = game:GetService("ReplicatedStorage")
    local anim8r = Humanoid:FindFirstChildOfClass("Animator")
    if not anim8r then anim8r = Instance.new("Animator"); anim8r.Parent = Humanoid end

    -- Clonar sonidos Stalk del Pursuer al HRP si no existen
    if hrp then
        for i = 1, 4 do
            local sn = (i == 1) and "Stalk" or ("Stalk" .. i)
            if not hrp:FindFirstChild(sn) then
                pcall(function()
                    RS_srv.Characters.Killer.Pursuer.Avoider.HumanoidRootPart[sn]:Clone().Parent = hrp
                end)
            end
        end
    end

    local function mkAnim(id)
        local a = Instance.new("Animation"); a.AnimationId = id
        local ok, t = pcall(function() return anim8r:LoadAnimation(a) end)
        return ok and t or nil
    end

    local stalk_start = mkAnim("rbxassetid://130725432915474")
    local stalk_loop  = mkAnim("rbxassetid://102302720518230")
    stalkLoopTrack = stalk_loop

    Character:SetAttribute("WalkSpeed",  0)
    Character:SetAttribute("SprintSpeed", 0)
    if stalk_start then stalk_start:Play() end

    -- Sonido × 2
    for i = 1, 2 do
        if not stalkActive then return end
        if i == 2 then task.wait(1.5) end
        if hrp then
            local rn = math.random(1, 4)
            local sn = (rn == 1) and "Stalk" or ("Stalk" .. rn)
            pcall(function() if hrp:FindFirstChild(sn) then hrp[sn]:Play() end end)
        end
    end

    task.wait(2)
    if not stalkActive then return end

    -- Boost de velocidad con delay (igual a dod.lua)
    task.delay(0.6, function()
        if not stalkActive then return end
        Character:SetAttribute("WalkSpeed",  stalkOldWS / 1.5)
        Character:SetAttribute("SprintSpeed", stalkOldSS / 1.5)
        task.wait(1.2)
        if not stalkActive then return end
        Character:SetAttribute("WalkSpeed",  27)
        Character:SetAttribute("SprintSpeed", 55)
    end)

    -- Fade-out
    if stalk_loop then stalk_loop:Play() end
    for i = 1, 10 do
        if not stalkActive then return end
        for _, v in next, Character:GetDescendants() do
            if (v:IsA("BasePart") or v:IsA("SpecialMesh")) and v.Name ~= "HumanoidRootPart" then
                pcall(function() v.Transparency = v.Transparency + 0.1 end)
            end
        end
        task.wait(0.13)
    end
    if not stalkActive then return end
    if stalk_loop and stalk_loop.IsPlaying then stalk_loop:Stop() end
    -- Se queda invisible hasta que el jugador presione F de nuevo
    applyInvisibility(true)
end

-- Toggle: F activa si está off, desactiva si está on
local function toggleStalk()
    if stalkActive then task.spawn(deactivateStalk)
    else               task.spawn(activateStalk)  end
end

local function getAnimator()
    local a = Humanoid:FindFirstChildOfClass("Animator")
    if not a then a = Instance.new("Animator"); a.Parent = Humanoid end
    return a
end

local function loadTrack(id)
    if not id or id == "" then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    local ok, t = pcall(function()
        local tr = getAnimator():LoadAnimation(anim)
        tr.Priority = Enum.AnimationPriority.Action4  -- más alto que movimiento (Action2/3)
        return tr
    end)
    return ok and t or nil
end

local SERVER_URL = "http://127.0.0.1:5757"

local function playSequence(arr, key)
    if abilityBusy or isStunned then return end
    if (tick() - (lastClick[key] or 0)) < ATTACK_CD then return end
    lastClick[key] = tick()
    abilityBusy = true
    -- Capturar look del owner AL MOMENTO de presionar Q
    local pressLook = Vector3.new(0, 0, 1)  -- default
    pcall(function()
        local myHRP = Character:FindFirstChild("HumanoidRootPart")
        if myHRP then
            local lv = myHRP.CFrame.LookVector
            pressLook = Vector3.new(lv.X, lv.Y, lv.Z)
        end
    end)
    task.spawn(function()
        for _, data in ipairs(arr) do
            if not Character.Parent then break end
            local tr = loadTrack(data.id)
            if not tr then break end
            tr:AdjustSpeed(data.speed or 1)
            tr.Looped = false  -- forzar no-loop para que IsPlaying termine siempre
            tr:Play(FADE)
            CurrentAtkTrack = tr
            if data.duration and data.forcedDuration then
                task.wait(data.duration)
                if tr and tr.IsPlaying then tr:Stop(0.3) end
            elseif data.duration then
                task.wait(data.duration)
            else
                -- timeout de seguridad: máx 10s para que nunca quede colgado
                local t0 = tick()
                repeat task.wait(0.05) until not tr.IsPlaying or not Character.Parent or (tick()-t0) > 10
                if tr.IsPlaying then tr:Stop(0.1) end
            end
        end
        -- Q de Artful → activar pared con la misma lógica de pasos que universal
        if key == "Q" and currentChar == "Artful" then
            local lx, ly, lz = pressLook.X, pressLook.Y, pressLook.Z
            local connected = getConnectedWallBots()
            local available = {}
            for i = 1, #WALL_BOTS_NAMES do
                if connected[i] then table.insert(available, i) end
            end
            if #available > 0 then
                if formationMode then
                    -- Modo formación: todos a la vez
                    for i = 1, #WALL_BOTS_NAMES do
                        if connected[i] then
                            local body = string.format(
                                '{"active":true,"lx":%.4f,"ly":%.4f,"lz":%.4f,"formation":"%s"}',
                                lx, ly, lz, formationMode)
                            httpPost("/artful/wall" .. i, body)
                        end
                    end
                else
                    if wallStep >= #available then wallStep = 0 end
                    local botIdx = available[wallStep + 1]
                    sendWall(botIdx, lx, ly, lz)
                    wallStep = (wallStep + 1) % #available
                end
            end
        end
        -- F de Artful → notificar spawn del bot
        if key == "F" and currentChar == "Artful" then
            notifyArtfulSpawn()
        end
        abilityBusy = false
    end)
end

local function playSingle(id, key)
    if abilityBusy or isStunned then return end
    if (tick() - (lastClick[key] or 0)) < ATTACK_CD then return end
    lastClick[key] = tick()
    local tr = loadTrack(id)
    if tr then tr:Play(FADE); CurrentAtkTrack = tr end
end

local function playStun(stunData)
    if isStunned then return end
    if (tick() - (lastClick["G"] or 0)) < STUN_CD then return end
    lastClick["G"] = tick()
    isStunned = true; abilityBusy = true
    if CurrentAtkTrack and CurrentAtkTrack.IsPlaying then CurrentAtkTrack:Stop(FADE) end
    local tr = loadTrack(stunData.id)
    if tr then tr:AdjustSpeed(stunData.speed or 1); tr:Play(FADE) end
    task.delay(stunData.duration or 3, function()
        if tr and tr.IsPlaying then tr:Stop(0.3) end
        isStunned = false; abilityBusy = false
    end)
end

-- ── INPUT ─────────────────────────────────────────────────────────────
local function disconnectInputs()
    for _, c in ipairs(inputConns) do c:Disconnect() end
    inputConns = {}
end

local function connectInputs()
    disconnectInputs()
    local ab = CHARS[currentChar].Abilities
    local ks = CHARS[currentChar].keys
    local conn = UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and ks.M1 and ab.M1 then
            playSingle(ab.M1.id, "M1")
        elseif inp.KeyCode == Enum.KeyCode.Q and ks.Q  and ab.Q  then playSequence(ab.Q,  "Q")
        elseif inp.KeyCode == Enum.KeyCode.E and ks.E  and ab.E  then playSequence(ab.E,  "E")
        elseif inp.KeyCode == Enum.KeyCode.R and ks.R  and ab.R  then playSequence(ab.R,  "R")
        elseif inp.KeyCode == Enum.KeyCode.F and ks.F  and ab.F  then
            if currentChar == "Pursuer" then toggleStalk()
            else playSequence(ab.F, "F") end
        elseif inp.KeyCode == Enum.KeyCode.G and ks.G  and ab.Stun then playStun(ab.Stun)
        end
    end)
    table.insert(inputConns, conn)
end

-- ── SISTEMA ───────────────────────────────────────────────────────────
local function activate()
    systemActive = true
    abilityBusy  = false  -- limpiar siempre al activar por si quedó colgado
    isStunned    = false
    applyMovementAnims(currentChar)
    connectInputs()
end

local function deactivate()
    systemActive = false
    disconnectInputs()
    stopMovementSystem()
    stopUniversalMovement()
    universalActive = false
    abilityBusy = false; isStunned = false
    if stalkActive then task.spawn(deactivateStalk) end
end

local function switchCharacter(name)
    local wasActive = systemActive
    if wasActive then disconnectInputs() end
    currentChar = name
    lastClick   = {}
    abilityBusy = false  -- limpiar al cambiar personaje por si quedó colgado
    isStunned   = false
    if wasActive then
        applyMovementAnims(currentChar)
        connectInputs()
    end
end

-- ── RESPAWN ───────────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character     = newChar
    Humanoid      = newChar:WaitForChild("Humanoid")
    abilityBusy   = false; isStunned = false
    CurrentAtkTrack = nil; lastClick = {}
    -- Limpiar stalk sin fade (personaje nuevo, ya no importa la trans anterior)
    stalkActive = false; stalkLoopTrack = nil
    stalkNoclipConn = nil; stalkCamConn = nil
    stopMovementSystem()
    stopUniversalMovement()
    if systemActive then
        task.wait(1)
        if universalActive then startUniversalMovement()
        else applyMovementAnims(currentChar) end
        connectInputs()
    end
end)


-- ════════════════════════════════════════════════════════════════════
-- GUI  ESTILO COOLKID — negro + borde rojo | páginas < >
-- RightAlt = ocultar/mostrar
-- ════════════════════════════════════════════════════════════════════
local CoreGui = game:GetService("CoreGui")
pcall(function() CoreGui:FindFirstChild("DOD_AnimGUI"):Destroy() end)

-- httpPost ya definido arriba (reutilizado en GUI)

local sg = Instance.new("ScreenGui")
sg.Name = "DOD_AnimGUI"; sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
sg.IgnoreGuiInset = true; sg.Parent = CoreGui

-- ── VENTANA ──────────────────────────────────────────────────────────────────
local WIN_W, WIN_H = 300, 420
local win = Instance.new("Frame", sg)
win.Name             = "win"
win.Size             = UDim2.fromOffset(WIN_W, WIN_H)
win.Position         = UDim2.fromOffset(100, 80)
win.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
win.BorderColor3     = Color3.fromRGB(255, 0, 0)
win.BorderSizePixel  = 3
win.Active           = true
win.Draggable        = true  -- coolkid usa Draggable nativo

-- ── TÍTULO ───────────────────────────────────────────────────────────────────
local titleBar = Instance.new("Frame", win)
titleBar.Size             = UDim2.new(1,0,0,40)
titleBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
titleBar.BorderColor3     = Color3.fromRGB(255,0,0)
titleBar.BorderSizePixel  = 3

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size                 = UDim2.new(1,-30,1,0)
titleLbl.Position             = UDim2.fromOffset(0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                 = "🎮 Panel de Control"
titleLbl.TextColor3           = Color3.fromRGB(255,255,255)
titleLbl.TextSize             = 22
titleLbl.Font                 = Enum.Font.SourceSansBold

local hideBtn = Instance.new("TextButton", titleBar)
hideBtn.Size             = UDim2.fromOffset(26,26)
hideBtn.Position         = UDim2.new(1,-28,0.5,-13)
hideBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
hideBtn.BorderColor3     = Color3.fromRGB(255,0,0)
hideBtn.BorderSizePixel  = 2
hideBtn.Text             = "X"
hideBtn.TextColor3       = Color3.fromRGB(255,255,255)
hideBtn.TextSize         = 18
hideBtn.Font             = Enum.Font.SourceSansBold
hideBtn.MouseButton1Click:Connect(function() win.Visible = not win.Visible end)

-- ── ÁREA DE CONTENIDO ────────────────────────────────────────────────────────
local contentFrame = Instance.new("Frame", win)
contentFrame.Position             = UDim2.fromOffset(0,42)
contentFrame.Size                 = UDim2.new(1,0,0,335)
contentFrame.BackgroundTransparency = 1

-- ── NAV  < página > ──────────────────────────────────────────────────────────
local navFrame = Instance.new("Frame", win)
navFrame.Position             = UDim2.new(0,0,1,-42)
navFrame.Size                 = UDim2.new(1,0,0,42)
navFrame.BackgroundColor3     = Color3.fromRGB(0,0,0)
navFrame.BorderColor3         = Color3.fromRGB(255,0,0)
navFrame.BorderSizePixel      = 3

local pageLbl = Instance.new("TextLabel", navFrame)
pageLbl.Size                 = UDim2.new(1,0,1,0)
pageLbl.BackgroundTransparency = 1
pageLbl.Text                 = "Página 1 / 4"
pageLbl.TextColor3           = Color3.fromRGB(200,200,200)
pageLbl.TextSize             = 16
pageLbl.Font                 = Enum.Font.SourceSans

local prevBtn = Instance.new("TextButton", navFrame)
prevBtn.Size             = UDim2.fromOffset(55,34)
prevBtn.Position         = UDim2.fromOffset(4,4)
prevBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
prevBtn.BorderColor3     = Color3.fromRGB(255,0,0)
prevBtn.BorderSizePixel  = 2
prevBtn.Text             = "<"
prevBtn.TextColor3       = Color3.fromRGB(255,255,255)
prevBtn.TextSize         = 20
prevBtn.Font             = Enum.Font.SourceSansBold

local nextBtn = Instance.new("TextButton", navFrame)
nextBtn.Size             = UDim2.fromOffset(55,34)
nextBtn.Position         = UDim2.new(1,-59,0,4)
nextBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
nextBtn.BorderColor3     = Color3.fromRGB(255,0,0)
nextBtn.BorderSizePixel  = 2
nextBtn.Text             = ">"
nextBtn.TextColor3       = Color3.fromRGB(255,255,255)
nextBtn.TextSize         = 20
nextBtn.Font             = Enum.Font.SourceSansBold

-- ── HELPERS GUI ──────────────────────────────────────────────────────────────
local pages = {}
local currentPage = 1
local MAX_PAGES   = 6

local function mkBtn(parent, text, yPos, cb)
    local b = Instance.new("TextButton", parent)
    b.Size             = UDim2.new(1,-20,0,44)
    b.Position         = UDim2.fromOffset(10, yPos)
    b.BackgroundColor3 = Color3.fromRGB(0,0,0)
    b.BorderColor3     = Color3.fromRGB(255,0,0)
    b.BorderSizePixel  = 2
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255,255,255)
    b.TextSize         = 18
    b.Font             = Enum.Font.SourceSans
    b.MouseButton1Click:Connect(cb)
    return b
end

local function mkLbl(parent, text, yPos, color)
    local l = Instance.new("TextLabel", parent)
    l.Size                 = UDim2.new(1,-20,0,22)
    l.Position             = UDim2.fromOffset(10, yPos)
    l.BackgroundTransparency = 1
    l.Text                 = text
    l.TextColor3           = color or Color3.fromRGB(180,180,180)
    l.TextSize             = 14
    l.Font                 = Enum.Font.SourceSans
    l.TextXAlignment       = Enum.TextXAlignment.Left
    return l
end

-- ── PÁGINAS ───────────────────────────────────────────────────────────────────
for i = 1, MAX_PAGES do
    local p = Instance.new("Frame", contentFrame)
    p.Size                 = UDim2.new(1,0,1,0)
    p.BackgroundTransparency = 1
    p.Visible              = i == 1
    pages[i] = p
end

local function loadPage(n)
    currentPage = n
    for i, p in ipairs(pages) do p.Visible = i==n end
    pageLbl.Text    = "Página "..n.." / "..MAX_PAGES
    prevBtn.Visible = n > 1
    nextBtn.Visible = n < MAX_PAGES
end

prevBtn.MouseButton1Click:Connect(function() if currentPage>1 then loadPage(currentPage-1) end end)
nextBtn.MouseButton1Click:Connect(function() if currentPage<MAX_PAGES then loadPage(currentPage+1) end end)

-- ══════════════════════════════════════════════════════════════════════════════
-- PÁGINA 1: ANIMACIONES DOD
-- ══════════════════════════════════════════════════════════════════════════════
local p1 = pages[1]

local statusLbl = mkLbl(p1, "Sistema: inactivo", 0, Color3.fromRGB(140,140,140))
statusLbl.TextSize = 15

local charLbl = mkLbl(p1, "Personaje: Pursuer", 20, Color3.fromRGB(255,180,60))
charLbl.TextSize = 15; charLbl.Font = Enum.Font.SourceSansBold

local function refreshCharUI()
    charLbl.Text      = "Personaje: "..currentChar
    charLbl.TextColor3 = currentChar=="Pursuer"
        and Color3.fromRGB(255,180,60) or Color3.fromRGB(120,200,255)
end

mkBtn(p1, "Cambiar → Pursuer", 44, function()
    switchCharacter("Pursuer"); refreshCharUI()
end)
mkBtn(p1, "Cambiar → Artful", 94, function()
    switchCharacter("Artful"); refreshCharUI()
end)
mkBtn(p1, "✅ Activar sistema", 144, function()
    activate()
    statusLbl.Text      = "Sistema: ACTIVO ("..currentChar..")"
    statusLbl.TextColor3 = Color3.fromRGB(80,255,100)
end)
mkBtn(p1, "🚫 Desactivar sistema", 194, function()
    deactivate()
    statusLbl.Text      = "Sistema: inactivo"
    statusLbl.TextColor3 = Color3.fromRGB(140,140,140)
end)

local keysLbl = mkLbl(p1, "Teclas: ...", 244, Color3.fromRGB(160,160,160))
keysLbl.Size = UDim2.new(1,-20,0,40); keysLbl.TextWrapped = true

local function refreshKeys()
    local ks = CHARS[currentChar].keys
    local parts = {}
    for k, v in pairs(ks) do if v then table.insert(parts, k) end end
    table.sort(parts)
    keysLbl.Text = "Teclas: "..table.concat(parts," | ")
end
refreshKeys()

local _orig = switchCharacter
switchCharacter = function(name)
    _orig(name); refreshKeys(); refreshCharUI()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PÁGINA 2: BOT ARTFUL
-- ══════════════════════════════════════════════════════════════════════════════
local p2 = pages[2]

local artMode = 0
local artModeLbl = mkLbl(p2, "Bot: OFF", 0, Color3.fromRGB(140,140,140))
artModeLbl.TextSize = 15; artModeLbl.Font = Enum.Font.SourceSansBold

local artModeColors = {
    [0] = Color3.fromRGB(140,140,140),
    [1] = Color3.fromRGB(80,220,100),
    [2] = Color3.fromRGB(255,200,50),
    [3] = Color3.fromRGB(255,60,60),
}
local artModeNames = { [0]="OFF", [1]="Siguiendo owner", [2]="Nearest", [3]="Killer" }

local artModeBtn
local function refreshArtMode()
    artModeLbl.Text      = "Bot: "..artModeNames[artMode]
    artModeLbl.TextColor3 = artModeColors[artMode]
    if artMode == 0 then artModeBtn.Text = "▶ Activar (seguir owner)"
    elseif artMode == 1 then artModeBtn.Text = "➡ Modo Nearest"
    elseif artMode == 2 then artModeBtn.Text = "➡ Modo Killer"
    else artModeBtn.Text = "🔁 Modo Owner" end
end

artModeBtn = mkBtn(p2, "▶ Activar (seguir owner)", 22, function()
    artMode = (artMode % 3) + 1
    httpPost("/artful/mode", '{"mode":'..artMode..'}')
    refreshArtMode()
end)

mkBtn(p2, "⏹ Stop bot", 72, function()
    artMode = 0
    httpPost("/artful/mode", '{"mode":0}')
    refreshArtMode()
end)

mkBtn(p2, "🔗 TP bot → Owner", 122, function()
    httpPost("/artful/tp", '{"tp":true}')
end)

mkBtn(p2, "📍 TP bot → Base (21,289,-38)", 172, function()
    httpPost("/artful/tpbase", '{"tp":true}')
end)

mkBtn(p2, "🎬 Iniciar anims del bot", 222, function()
    httpPost("/artful/anims", '{"start":true}')
end)

-- La pared de Fotosontosis es automática al presionar Q — no necesita botón
local wallInfoLbl = mkLbl(p2, "🧱 Pared: automática al presionar Q", 278, Color3.fromRGB(100,180,100))

-- ══════════════════════════════════════════════════════════════════════════════
-- PÁGINA 3: UTILIDADES / BOT SISTEMA
-- ══════════════════════════════════════════════════════════════════════════════
local p3 = pages[3]

mkBtn(p3, "🚪 Bot: Salir del juego", 0, function()
    httpPost("/artful/leave", '{"leave":true}')
end)

mkBtn(p3, "🔄 Bot: Rejoin", 50, function()
    httpPost("/artful/rejoin", '{"rejoin":true}')
end)

mkBtn(p3, "❌ Cerrar esta GUI", 100, function()
    sg:Destroy()
end)

mkLbl(p3, "RightAlt = ocultar / mostrar", 152, Color3.fromRGB(120,120,120))
mkLbl(p3, "Base del bot: X=21  Y=289  Z=-38", 174, Color3.fromRGB(120,120,120))
mkLbl(p3, "Bot se auto-TP a base si se aleja 400+", 196, Color3.fromRGB(120,120,120))

-- ══════════════════════════════════════════════════════════════════════════════
-- PÁGINA 4: MODO UNIVERSAL R6 + PAREDES
-- ══════════════════════════════════════════════════════════════════════════════
local p4 = pages[4]

-- ── Activar/desactivar ───────────────────────────────────────────────
local uStatusLbl = mkLbl(p4, "Estado: inactivo", 0, Color3.fromRGB(140,140,140))
uStatusLbl.TextSize = 15

local uBtn
uBtn = mkBtn(p4, "▶ Activar sistema", 22, function()
    universalActive = not universalActive
    if universalActive then
        startUniversalMovement()
        uBtn.Text             = "⏹ Desactivar sistema"
        uStatusLbl.Text       = "Estado: ACTIVO"
        uStatusLbl.TextColor3 = Color3.fromRGB(80,255,100)
    else
        stopUniversalMovement()
        uBtn.Text             = "▶ Activar sistema"
        uStatusLbl.Text       = "Estado: inactivo"
        uStatusLbl.TextColor3 = Color3.fromRGB(140,140,140)
        if systemActive then applyMovementAnims(currentChar) end
    end
end)

-- ── Bots conectados ──────────────────────────────────────────────────
local connLbl = mkLbl(p4, "Bots: verificando...", 72, Color3.fromRGB(160,160,160))
connLbl.TextSize = 13

local function refreshConnected()
    local connected = getConnectedWallBots()
    local parts = {}
    for idx, name in ipairs(WALL_BOTS_NAMES) do
        if connected[idx] then
            table.insert(parts, "✅ " .. name)
        else
            table.insert(parts, "❌ " .. name)
        end
    end
    connLbl.Text = table.concat(parts, "   ")
end
refreshConnected()

mkBtn(p4, "🔄 Actualizar bots", 90, function()
    refreshConnected()
end)

-- ── Tecla configurable ───────────────────────────────────────────────
local keyLbl = mkLbl(p4, "Tecla pared: Q  |  1°Q=fotoson  2°Q=pedrato", 262, Color3.fromRGB(180,180,180))
keyLbl.TextSize = 12

local bindingKey = false
local keyBindBtn
keyBindBtn = mkBtn(p4, "🎮 Cambiar tecla (presioná una)", 280, function()
    if bindingKey then return end
    bindingKey = true
    keyBindBtn.Text      = "Esperando tecla..."
    keyBindBtn.TextColor3 = Color3.fromRGB(255,200,0)
    local conn
    conn = game:GetService("UserInputService").InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
        conn:Disconnect()
        wallKey         = inp.KeyCode
        keyLbl.Text     = "Tecla pared: " .. tostring(inp.KeyCode.Name)
        keyBindBtn.Text = "🎮 Cambiar tecla (presioná una)"
        keyBindBtn.TextColor3 = Color3.fromRGB(255,255,255)
        bindingKey = false
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- PÁGINA 5: PORTAL
-- ══════════════════════════════════════════════════════════════════════════════
local p5 = pages[5]

-- Estado visual de la fase del portal
local portalOnState = false

local portalTitleLbl = mkLbl(p5, "🌀 PORTAL", 0, Color3.fromRGB(120,220,255))
portalTitleLbl.TextSize = 20; portalTitleLbl.Font = Enum.Font.SourceSansBold

local portalDescLbl = mkLbl(p5, "Al activar → fotoson cubre al owner al instante", 26, Color3.fromRGB(180,180,180))
portalDescLbl.TextSize = 12; portalDescLbl.TextWrapped = true
portalDescLbl.Size = UDim2.new(1,-20,0,34)

local portalDesc2Lbl = mkLbl(p5, "Click en el mapa → pedrato sube ahí → TP owner", 62, Color3.fromRGB(180,180,180))
portalDesc2Lbl.TextSize = 12; portalDesc2Lbl.TextWrapped = true
portalDesc2Lbl.Size = UDim2.new(1,-20,0,34)

-- Indicador de fase actual
local portalFaseLbl = mkLbl(p5, "Estado: inactivo", 100, Color3.fromRGB(140,140,140))
portalFaseLbl.TextSize = 14; portalFaseLbl.Font = Enum.Font.SourceSansBold

-- Botón principal ON/OFF
local portalToggleBtn
portalToggleBtn = mkBtn(p5, "🌀 Activar Portal", 128, function()
    portalOnState = not portalOnState
    if _G.__PORTAL_TOGGLE then _G.__PORTAL_TOGGLE(portalOnState) end
    if portalOnState then
        portalToggleBtn.Text       = "⏹ Desactivar Portal"
        portalToggleBtn.TextColor3 = Color3.fromRGB(120,220,255)
        portalFaseLbl.Text         = "🛡 Fotoson cubriendo — click en el mapa"
        portalFaseLbl.TextColor3   = Color3.fromRGB(120,220,255)
    else
        portalToggleBtn.Text       = "🌀 Activar Portal"
        portalToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
        portalFaseLbl.Text         = "Estado: inactivo"
        portalFaseLbl.TextColor3   = Color3.fromRGB(140,140,140)
    end
end)

-- Callback que el sistema llama cuando el portal termina (TP del owner hecho)
_G.__PORTAL_ON_DONE = function()
    portalOnState = false
    portalToggleBtn.Text       = "🌀 Activar Portal"
    portalToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    portalFaseLbl.Text         = "✅ Portal completo — desactivado"
    portalFaseLbl.TextColor3   = Color3.fromRGB(80,255,120)
end

-- Botón reset manual por si algo sale mal
mkBtn(p5, "🔁 Reset portal", 178, function()
    local fn = request or (http and http.request) or nil
    if fn then
        task.spawn(function()
            pcall(fn, {
                Url     = "http://127.0.0.1:5757/artful/portal",
                Method  = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body    = '{"reset":true}',
            })
        end)
    end
    portalFaseLbl.Text       = "Estado: reseteado"
    portalFaseLbl.TextColor3 = Color3.fromRGB(255,180,0)
    task.delay(1.5, function()
        if portalOnState then
            portalFaseLbl.Text       = "Estado: ON — esperando click 1"
            portalFaseLbl.TextColor3 = Color3.fromRGB(120,220,255)
        else
            portalFaseLbl.Text       = "Estado: inactivo"
            portalFaseLbl.TextColor3 = Color3.fromRGB(140,140,140)
        end
    end)
end)

-- Nota informativa
local portalNotaLbl = mkLbl(p5, "⚠ El Portal usa click izquierdo.\nDesactivá el modo Punto antes de usarlo.", 234, Color3.fromRGB(255,200,60))
portalNotaLbl.TextSize = 11; portalNotaLbl.TextWrapped = true
portalNotaLbl.Size = UDim2.new(1,-20,0,40)

-- Actualizar label de fase (polling ligero)
task.spawn(function()
    while true do
        task.wait(0.3)
        if not portalOnState then continue end
        local fn = request or (http and http.request) or nil
        if not fn then continue end
        local ok, res = pcall(fn, { Url = "http://127.0.0.1:5757/artful/portal", Method = "GET" })
        if not ok or not res or res.StatusCode ~= 200 then continue end
        local body = res.Body
        local ready = body:find('"ready"%s*:%s*true') ~= nil
        local fase  = tonumber(body:match('"fase"%s*:%s*(%d+)')) or 0
        if ready then
            portalFaseLbl.Text       = "✅ Portal completo — owner tpeado"
            portalFaseLbl.TextColor3 = Color3.fromRGB(80,255,120)
        elseif fase == 2 then
            portalFaseLbl.Text       = "⏳ Pedrato subiendo..."
            portalFaseLbl.TextColor3 = Color3.fromRGB(255,200,60)
        elseif portalOnState then
            portalFaseLbl.Text       = "🛡 Fotoson cubriendo — click en el mapa"
            portalFaseLbl.TextColor3 = Color3.fromRGB(120,220,255)
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- PÁGINA 6: FORMACIONES
-- ══════════════════════════════════════════════════════════════════════════════
local p6 = pages[6]

local fmtTitleLbl = mkLbl(p6, "🧱 FORMACIONES", 0, Color3.fromRGB(255,200,80))
fmtTitleLbl.TextSize = 20; fmtTitleLbl.Font = Enum.Font.SourceSansBold

local fmtDescLbl = mkLbl(p6, "Activa un modo y presioná Q (o la tecla de pared) para disparar todos en formación.", 26, Color3.fromRGB(160,160,160))
fmtDescLbl.TextWrapped = true; fmtDescLbl.Size = UDim2.new(1,-20,0,40)

local fmtModeLbl = mkLbl(p6, "Modo activo: ninguno", 72, Color3.fromRGB(140,140,140))
fmtModeLbl.TextSize = 13; fmtModeLbl.Font = Enum.Font.SourceSansBold

local fmtSideBtn, fmtStackBtn

local function updateFmtUI()
    if formationMode == "side" then
        fmtSideBtn.BorderColor3  = Color3.fromRGB(80,255,100)
        fmtStackBtn.BorderColor3 = Color3.fromRGB(255,0,0)
        fmtModeLbl.Text          = "Modo activo: AL LADO ✅"
        fmtModeLbl.TextColor3    = Color3.fromRGB(80,255,100)
    elseif formationMode == "stack" then
        fmtSideBtn.BorderColor3  = Color3.fromRGB(255,0,0)
        fmtStackBtn.BorderColor3 = Color3.fromRGB(80,255,100)
        fmtModeLbl.Text          = "Modo activo: UNO ENCIMA ✅"
        fmtModeLbl.TextColor3    = Color3.fromRGB(80,255,100)
    else
        fmtSideBtn.BorderColor3  = Color3.fromRGB(255,0,0)
        fmtStackBtn.BorderColor3 = Color3.fromRGB(255,0,0)
        fmtModeLbl.Text          = "Modo activo: ninguno"
        fmtModeLbl.TextColor3    = Color3.fromRGB(140,140,140)
    end
end

fmtSideBtn = mkBtn(p6, "↔ Al lado", 100, function()
    formationMode = formationMode == "side" and nil or "side"
    updateFmtUI()
end)

fmtStackBtn = mkBtn(p6, "↕ Uno encima del otro", 152, function()
    formationMode = formationMode == "stack" and nil or "stack"
    updateFmtUI()
end)

mkBtn(p6, "✖ Desactivar formación", 210, function()
    formationMode = nil
    updateFmtUI()
end)

-- ── INIT & TOGGLE ─────────────────────────────────────────────────────────────
loadPage(1)

UserInputService.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightAlt then
        win.Visible = not win.Visible
    end
end)

-- ── Toggle global para cmd.lua ────────────────────────────────────────────────
_G.__DODAN_TOGGLE = function()
    win.Visible = not win.Visible
end

print("[DOD_AN v5] Cargado ✅ | RightAlt = toggle | CoolKid style")
