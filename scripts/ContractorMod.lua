--
-- ContractorMod
-- Specialization for managing several characters when playing solo game
-- Update attached to update event of the map
--
-- @author  yumi
-- free for noncommercial-usage
--

source(Utils.getFilename("scripts/ContractorModWorker.lua", g_currentModDirectory))

ContractorMod = {};
ContractorMod.myCurrentModDirectory = g_currentModDirectory;

ContractorMod.debug = false --true --
-- TODO:
-- Passenger: Try to add cameras
-- Passenger: Worker continues until no more character in the vehicle

-- @doc First code called during map loading (before we can actually interact)
function ContractorMod:loadMap(name)
  if ContractorMod.debug then print("ContractorMod:loadMap(name)") end
  self.initializing = true
  if self.initialized then
    return;
  end;
  self.initialized = true;
end;

function ContractorMod:deleteMap()
  if ContractorMod.debug then print("ContractorMod:deleteMap()") end
  self.initialized = false;
  self.workers = nil;
end;
 
-- @doc register InputBindings
function ContractorMod:registerActionEvents()
  if ContractorMod.debug then print("ContractorMod:registerActionEvents()") end
  --@FS19 Should we overwrite SwitchVehicle() instead of adding our key here ? 
  for _,actionName in pairs({ "ContractorMod_NEXTWORKER",  
                              "ContractorMod_PREVWORKER",
                              "ContractorMod_WORKER1",
                              "ContractorMod_WORKER2",
                              "ContractorMod_WORKER3",
                              "ContractorMod_WORKER4",
                              "ContractorMod_WORKER5",
                              "ContractorMod_WORKER6",
                              "ContractorMod_WORKER7",
                              "ContractorMod_WORKER8" }) do
    -- print("actionName "..actionName)
    local __, eventName, event, action = InputBinding.registerActionEvent(g_inputBinding, actionName, self, ContractorMod.actionCallback ,false ,true ,false ,true)
    -- print("__ "..tostring(__))
    print("eventName "..eventName)
    -- print("event "..tostring(event))
    -- print("action "..tostring(action))
    if __ then
      g_inputBinding.events[eventName].displayIsVisible = false
    end
    -- DebugUtil.printTableRecursively(actionName, " ", 1, 2);
    --__, eventName = self:addActionEvent(self.actionEvents, actionName, self, ContractorMod.actionCallback, false, true, false, true)
  end
end

-- @doc registerActionEvents need to be called regularly
function ContractorMod:appRegisterActionEvents()
  if ContractorMod.debug then print("ContractorMod:appRegisterActionEvents()") end
  ContractorMod:registerActionEvents()
end
-- Only needed for global action event 
FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, ContractorMod.appRegisterActionEvents);

-- @doc Called by update method only once at the beginning when nothing is initialized yet
function ContractorMod:init()
  if ContractorMod.debug then print("ContractorMod:init()") end
  -- Forbid switching between vehicles
  -- g_currentMission.isToggleVehicleAllowed = false;

  self.currentID = 1.
  self.numWorkers = 4.
  self.workers = {}
  self.initializing = true
  self.shouldExit = false           --Enable to forbid having 2 workers in the same vehicle
  self.shouldStopWorker = true      --Enable to distinguish LeaveVehicle when switchingWorker and when leaving due to player request
  self.enableSeveralDrivers = false --Should be always true when passenger works correctly
  self.displayOnFootWorker = false
  self.switching = false

  self:manageModsConflicts()
  --@FS19self:manageSpecialVehicles() --g_currentMission.nodeToVehicle is nil

  local savegameDir;
  if g_currentMission.missionInfo.savegameDirectory then
    savegameDir = g_currentMission.missionInfo.savegameDirectory;
  end;
  if not savegameDir and g_careerScreen.currentSavegame and g_careerScreen.currentSavegame.savegameIndex then
    savegameDir = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.currentSavegame.savegameIndex);
  end;
  if not savegameDir and g_currentMission.missionInfo.savegameIndex ~= nil then
    savegameDir = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.missionInfo.savegameIndex);
  end;
  self.savegameFolderPath = savegameDir;
  self.ContractorModXmlFilePath = self.savegameFolderPath .. '/ContractorMod.xml';
  print(self.ContractorModXmlFilePath)
  if not self:initFromSave() or #self.workers <= 0 then
    if not self:initFromParam() or #self.workers <= 0 then
      -- default values
      if ContractorMod.debug then print("ContractorMod: No savegame: set default values") end
      local farmId = 1
      local workerStyle = {};
      workerStyle.playerColorIndex = 0;
      workerStyle.playerBodyIndex = 1;
      workerStyle.playerHatIndex = 0;
      workerStyle.playerAccessoryIndex = 0;
      workerStyle.playerHairIndex = 0;
      workerStyle.playerJacketIndex = 0;
      local worker = ContractorModWorker:new("Alex", 1, "male", workerStyle, farmId, true)
      table.insert(self.workers, worker)
      workerStyle.playerColorIndex = 1;
      worker = ContractorModWorker:new("Barbara", 2, "female", workerStyle, farmId, true)
      table.insert(self.workers, worker)
      workerStyle.playerColorIndex = 2;
      worker = ContractorModWorker:new("Chris", 3, "male", workerStyle, farmId, true)
      table.insert(self.workers, worker)
      workerStyle.playerColorIndex = 3;
      worker = ContractorModWorker:new("David", 4, "male", workerStyle, farmId, true)
      table.insert(self.workers, worker)
      self.numWorkers = 4
      self.enableSeveralDrivers = true
    end
  end
end


function ContractorMod:onSwitchVehicle(action)
	print("-- ContractorMod:onSwitchVehicle");
  self.switching = true
  if action == "SWITCH_VEHICLE" then
    print('ContractorMod_NEXTWORKER pressed')
    local nextID = 0
    if ContractorMod.debug then print("ContractorMod: self.currentID " .. tostring(self.currentID)) end
    if ContractorMod.debug then print("ContractorMod: self.numWorkers " .. tostring(self.numWorkers)) end
    if self.currentID < self.numWorkers then
      nextID = self.currentID + 1
    else
      nextID = 1
    end
    if ContractorMod.debug then print("ContractorMod: nextID " .. tostring(nextID)) end
    self:setCurrentContractorModWorker(nextID)
  elseif action == "SWITCH_VEHICLE_BACK" then
    print('ContractorMod_PREVWORKER pressed')
    if ContractorMod.debug then print("ContractorMod:update(dt) ContractorMod_PREVWORKER") end
    local prevID = 0
    if self.currentID > 1 then
      prevID = self.currentID - 1
    else
      prevID = self.numWorkers
    end    
    self:setCurrentContractorModWorker(prevID)
  end
end

function ContractorMod:replaceOnSwitchVehicle(superfunc, action, direction)
  ContractorMod:onSwitchVehicle(action)
end
BaseMission.onSwitchVehicle = Utils.overwrittenFunction(BaseMission.onSwitchVehicle, ContractorMod.replaceOnSwitchVehicle);


function ContractorMod:actionCallback(actionName, keyStatus)
	print("-- ContractorMod:actionCallback");
  print("actionName "..tostring(actionName));
  print("keyStatus "..tostring(keyStatus));
  -- if keyStatus > 0 then
  --   -- DebugUtil.printTableRecursively(self, " ", 1, 2);
	-- 	if actionName == "ContractorMod_NEXTWORKER" then
	-- 		print('ContractorMod_NEXTWORKER presseed')
  --     local nextID = 0
  --     if ContractorMod.debug then print("ContractorMod: self.currentID " .. tostring(self.currentID)) end
  --     if ContractorMod.debug then print("ContractorMod: self.numWorkers " .. tostring(self.numWorkers)) end
  --     if self.currentID < self.numWorkers then
  --       nextID = self.currentID + 1
  --     else
  --       nextID = 1
  --     end
  --     if ContractorMod.debug then print("ContractorMod: nextID " .. tostring(nextID)) end
  --     self:setCurrentContractorModWorker(nextID)
	-- 	elseif actionName == "ContractorMod_PREVWORKER" then
	-- 		print('ContractorMod_PREVWORKER presseed')
  --     if ContractorMod.debug then print("ContractorMod:update(dt) ContractorMod_PREVWORKER") end
  --     local prevID = 0
  --     if self.currentID > 1 then
  --       prevID = self.currentID - 1
  --     else
  --       prevID = self.numWorkers
  --     end    
  --     self:setCurrentContractorModWorker(prevID)
  --   else
    if string.sub(actionName, 1, 20) == "ContractorMod_WORKER" then
      local workerIndex = tonumber(string.sub(actionName, -1))
      if self.numWorkers >= workerIndex then
        self:setCurrentContractorModWorker(workerIndex)
      end
		end
	-- end
end

-- @doc Load ContractorMod parameters from savegame
function ContractorMod:initFromSave()
  if ContractorMod.debug then print("ContractorMod:initFromSave") end
  if g_currentMission ~= nil and g_currentMission:getIsServer() then
    -- Copy ContractorMod.xml from zip to mods dir
    ContractorMod:CopyContractorModXML()
    if self.savegameFolderPath and self.ContractorModXmlFilePath then
      createFolder(self.savegameFolderPath);
      local xmlFile;
      if fileExists(self.ContractorModXmlFilePath) then
        xmlFile = loadXMLFile('ContractorMod', self.ContractorModXmlFilePath);
      else
        xmlFile = createXMLFile('ContractorMod', self.ContractorModXmlFilePath, 'ContractorMod');
        saveXMLFile(xmlFile);
        delete(xmlFile);
        return false;
      end;

      if xmlFile ~= nil then
        local xmlKey = "ContractorMod.workers"
        local numWorkers = 0
        numWorkers = getXMLInt(xmlFile, xmlKey .. string.format("#numWorkers"));
        if numWorkers ~= nil then
          --print("numWorkers " .. tostring(numWorkers))

          local displayOnFootWorker = getXMLBool(xmlFile, xmlKey .. string.format("#displayOnFootWorker"));
          if displayOnFootWorker ~= nil then
            self.displayOnFootWorker = displayOnFootWorker
          else
            self.displayOnFootWorker = false
          end

          for i = 1, numWorkers do
            local key = xmlKey .. string.format(".worker(%d)", i - 1)
            local workerName = getXMLString(xmlFile, key.."#name");
            local gender = getXMLString(xmlFile, key .. string.format("#gender"));
            if gender == nil then
                gender = "male"
            end
            local playerColorIndex = getXMLInt(xmlFile, key .. string.format("#playerColorIndex"));
            if playerColorIndex == nil then
              playerColorIndex = 0
            end
            local playerBodyIndex = getXMLInt(xmlFile, key .. string.format("#playerBodyIndex"));
            if playerBodyIndex == nil then
              playerBodyIndex = 1
            end
            local playerHatIndex = getXMLInt(xmlFile, key .. string.format("#playerHatIndex"));
            if playerHatIndex == nil then
              playerHatIndex = 0
            end
            local playerAccessoryIndex = getXMLInt(xmlFile, key .. string.format("#playerAccessoryIndex"));
            if playerAccessoryIndex == nil then
              playerAccessoryIndex = 0
            end
            local playerHairIndex = getXMLInt(xmlFile, key .. string.format("#playerHairIndex"));
            if playerHairIndex == nil then
              playerHairIndex = 0
            end
            local playerJacketIndex = getXMLInt(xmlFile, key .. string.format("#playerJacketIndex"));
            if playerJacketIndex == nil then
              playerJacketIndex = 0
            end
            if ContractorMod.debug then print(workerName) end
            local workerStyle = {};
            workerStyle.playerColorIndex = playerColorIndex;
            workerStyle.playerBodyIndex = playerBodyIndex;
            workerStyle.playerHatIndex = playerHatIndex;
            workerStyle.playerAccessoryIndex = playerAccessoryIndex;
            workerStyle.playerHairIndex = playerHairIndex;
            workerStyle.playerJacketIndex = playerJacketIndex;
            local worker = ContractorModWorker:new(workerName, i, gender, workerStyle, self.displayOnFootWorker)
            if ContractorMod.debug then print(getXMLString(xmlFile, key.."#position")) end
            local x, y, z = StringUtil.getVectorFromString(getXMLString(xmlFile, key.."#position"));
            if ContractorMod.debug then print("x "..tostring(x)) end
            local xRot, yRot, zRot = StringUtil.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
            if x ~= nil and y ~= nil and z ~= nil and xRot ~= nil and yRot ~= nil and zRot ~= nil then
              worker.x = x
              worker.y = y
              worker.z = z
              worker.dx = xRot
              worker.dy = yRot
              worker.rotY = yRot
              worker.dz = zRot
              local vehicleID = getXMLFloat(xmlFile, key.."#vehicleID");
              if vehicleID > 0 then
                local vehicle = NetworkUtil.getObject(vehicleID)
                if vehicle ~= nil then
                  if ContractorMod.debug then print("ContractorMod: vehicle not nil") end
                  worker.currentVehicle = vehicle
                  local currentSeat = getXMLInt(xmlFile, key.."#currentSeat");
                  if currentSeat ~= nil then
                    worker.currentSeat = currentSeat
                  end
                end
              end
            end;
            table.insert(self.workers, worker)
            -- Display visual drivers when loading savegame
            -- Done here since we don't know which of the drivers entering during initialization
            if worker.currentVehicle ~= nil and worker.currentSeat ~= nil then
              ContractorMod:placeVisualWorkerInVehicle(worker, worker.currentVehicle, worker.currentSeat)
            end
          end
          local enableSeveralDrivers = getXMLBool(xmlFile, xmlKey .. string.format("#enableSeveralDrivers"));
          if enableSeveralDrivers ~= nil then
            self.enableSeveralDrivers = enableSeveralDrivers
          else
            self.enableSeveralDrivers = false
          end
        end
        self.numWorkers = numWorkers
        return true
      end
    end
  end
end

-- @doc Load ContractorMod parameters from default parameters (for new game)
function ContractorMod:initFromParam()
  if ContractorMod.debug then print("ContractorMod:initFromParam") end
  if g_currentMission ~= nil and g_currentMission:getIsServer() then
    -- Copy ContractorMod.xml from zip to mods dir
    ContractorMod:CopyContractorModXML()
    if ContractorMod.myCurrentModDirectory then
      local xmlFilePath = ContractorMod.myCurrentModDirectory .. "../ContractorMod.xml"
      local xmlFile;
      if fileExists(xmlFilePath) then
        xmlFile = loadXMLFile('ContractorMod', xmlFilePath);
      else
        return false;
      end;

      if xmlFile ~= nil then
        local xmlKey = "ContractorMod.workers"
        local numWorkers = 0
        numWorkers = getXMLInt(xmlFile, xmlKey .. string.format("#numWorkers"));
        if numWorkers ~= nil then

          local displayOnFootWorker = getXMLBool(xmlFile, xmlKey .. string.format("#displayOnFootWorker"));
          if displayOnFootWorker ~= nil then
            self.displayOnFootWorker = displayOnFootWorker
          else
            self.displayOnFootWorker = false
          end
          if ContractorMod.debug then print("ContractorMod: numWorkers " .. tostring(numWorkers)) end
          for i = 1, numWorkers do
            local key = xmlKey .. string.format(".worker(%d)", i - 1)
            local workerName = getXMLString(xmlFile, key.."#name");
            local gender = getXMLString(xmlFile, key .. string.format("#gender"));
            if gender == nil then
                gender = "male"
            end
            local playerColorIndex = getXMLInt(xmlFile, key .. string.format("#playerColorIndex"));
            if playerColorIndex == nil then
              playerColorIndex = 0
            end
            local playerBodyIndex = getXMLInt(xmlFile, key .. string.format("#playerBodyIndex"));
            if playerBodyIndex == nil then
              playerBodyIndex = 0
            end
            local playerHatIndex = getXMLInt(xmlFile, key .. string.format("#playerHatIndex"));
            if playerHatIndex == nil then
              playerHatIndex = 0
            end
            local playerAccessoryIndex = getXMLInt(xmlFile, key .. string.format("#playerAccessoryIndex"));
            if playerAccessoryIndex == nil then
              playerAccessoryIndex = 0
            end
            local playerHairIndex = getXMLInt(xmlFile, key .. string.format("#playerHairIndex"));
            if playerHairIndex == nil then
              playerHairIndex = 0
            end
            local playerJacketIndex = getXMLInt(xmlFile, key .. string.format("#playerJacketIndex"));
            if playerJacketIndex == nil then
              playerJacketIndex = 0
            end
            if ContractorMod.debug then print(workerName) end
            local workerStyle = {};
            workerStyle.playerColorIndex = playerColorIndex;
            workerStyle.playerBodyIndex = playerBodyIndex;
            workerStyle.playerHatIndex = playerHatIndex;
            workerStyle.playerAccessoryIndex = playerAccessoryIndex;
            workerStyle.playerHairIndex = playerHairIndex;
            workerStyle.playerJacketIndex = playerJacketIndex;
            if ContractorMod.debug then print(workerName) end
            local worker = ContractorModWorker:new(workerName, i, gender, workerStyle, self.displayOnFootWorker)
            if ContractorMod.debug then print(getXMLString(xmlFile, key.."#position")) end
            local x, y, z = StringUtil.getVectorFromString(getXMLString(xmlFile, key.."#position"));
            if ContractorMod.debug then print("x "..tostring(x)) end
            local xRot, yRot, zRot = StringUtil.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
            if x ~= nil and y ~= nil and z ~= nil and xRot ~= nil and yRot ~= nil and zRot ~= nil then
              worker.x = x
              worker.y = y
              worker.z = z
              worker.dx = xRot
              worker.dy = yRot
              worker.dz = zRot
            end;
            table.insert(self.workers, worker)
          end
          local enableSeveralDrivers = getXMLBool(xmlFile, xmlKey .. string.format("#enableSeveralDrivers"));
          if enableSeveralDrivers ~= nil then
            self.enableSeveralDrivers = enableSeveralDrivers
          else
            self.enableSeveralDrivers = false
          end
        end
        self.numWorkers = numWorkers
        return true
      end
    end
  end
end

-- @doc Copy default parameters from mod mod zip file to mods directory so end-user can edit it
function ContractorMod:CopyContractorModXML()
  if ContractorMod.debug then print("ContractorMod:CopyContractorModXML") end
  if g_currentMission ~= nil and g_currentMission:getIsServer() then
    if ContractorMod.myCurrentModDirectory then
      local xmlFilePath = ContractorMod.myCurrentModDirectory .. "../ContractorMod.xml"
      if ContractorMod.debug then print("ContractorMod:CopyContractorModXML_1") end
      local xmlFile;
      if not fileExists(xmlFilePath) then
        if ContractorMod.debug then print("ContractorMod:CopyContractorModXML_2") end
        local xmlSourceFilePath = ContractorMod.myCurrentModDirectory .. "ContractorMod.xml"
        local xmlSourceFile;
        if fileExists(xmlSourceFilePath) then
          if ContractorMod.debug then print("ContractorMod:CopyContractorModXML_3") end
          xmlSourceFile = loadXMLFile('ContractorMod', xmlSourceFilePath);
          --xmlFile = createXMLFile('ContractorMod', xmlFilePath, 'ContractorMod');
          saveXMLFileTo(xmlSourceFile, xmlFilePath);
          if ContractorMod.debug then print("ContractorMod:CopyContractorModXML_4") end
        end
      end;
    end
  end
end

-- Remove characters (driver & passengers) from vehicle when sold or when exiting game
function ContractorMod:ManageSoldVehicle(vehicle, callDelete)
  local vehicleName = ""
  if vehicle ~= nil then
    if vehicle.name ~= nil then
      vehicleName = vehicle.name
    end
  end
  if ContractorMod.debug then print("ContractorMod:ManageSoldVehicle " .. vehicleName) end
  if self.workers ~= nil then
    if #self.workers > 0 then
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.currentVehicle == vehicle then
          if ContractorMod.debug then print("ContractorMod: This worker was in a vehicle that has been removed : " .. worker.name) end
          if callDelete == nil then
            worker.x, worker.y, worker.z = getWorldTranslation(worker.currentVehicle.rootNode);
            if worker.y ~= nil then
              worker.y = worker.y + 2 --to avoid being under the ground
            end
            worker.dx, worker.dy, worker.dz = localDirectionToWorld(worker.currentVehicle.rootNode, 0, 0, 1);
          end
          -- Remove passengers
          for p = 1, #worker.currentVehicle.passengers do
            if worker.currentVehicle.passengers[p] ~= nil then
              worker.currentVehicle.passengers[p]:delete()
            end
          end
          worker.currentVehicle = nil
          -- Remove mapHotSpot
          --@FS19: g_currentMission.ingameMap:deleteMapHotspot(worker.mapHotSpot) g_currentMission.ingameMap is nil
          g_currentMission:removeMapHotspot(worker.mapHotSpot)
          worker.mapHotSpot:delete()
          worker.mapHotSpot = nil
          --break
        end
      end
    end
  end
end
function ContractorMod:removeVehicle(vehicle, callDelete)
  ContractorMod:ManageSoldVehicle(vehicle, callDelete)
end
BaseMission.removeVehicle = Utils.prependedFunction(BaseMission.removeVehicle, ContractorMod.removeVehicle);

-- @doc Called after entering a vehicle to avoid 2 drivers in the same vehicle
function ContractorMod:ManageEnterVehicle(vehicle, playerStyle)
  local vehicleName = ""
  if vehicle ~= nil then
    if vehicle.name ~= nil then
      vehicleName = vehicle.name
    end
  end
  if ContractorMod.debug then print("ContractorMod:appendedEnterVehicle >>" .. vehicleName) end

  local doExit = false
  if self.workers ~= nil then
    if #self.workers > 0 and not self.initializing and not self.enableSeveralDrivers then
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.currentVehicle == vehicle then
          if worker.name ~= self.workers[self.currentID].name then
            if ContractorMod.debug then print("ContractorMod: "..worker.name .. " already in ") end
            if worker.isPassenger == false then
              if ContractorMod.debug then print("as driver") end
              doExit = true
            else
              if ContractorMod.debug then print("as passenger") end
              doExit = false
            end
          else
            doExit = false
          end
        end
      end
    end
  end
  if doExit then
    if ContractorMod.debug then print("ContractorMod: Player will leave " ) end
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ContractorMod_VEHICLE_NOT_FREE"))
    self.shouldExit = true
  end
  -- @FS19 Do we still this code ??
  if self.switching and vehicle.steeringEnabled then  -- true and false
    -- Switching and no AI
    if SpecializationUtil.hasSpecialization(AIVehicle, vehicle.specializations) then
      -- Stop AI if vehicle can be hired (else will crash on cars)
      vehicle:stopAIVehicle();
    end
    vehicle.isHired = false
    --HelperUtil.releaseHelper(vehicle.currentHelper)
    if ContractorMod.debug then print("ContractorMod: switching-noAI " .. tostring(vehicle.isHired)) end
    if ContractorMod.debug then print("ContractorMod: switching-noAI " .. tostring(vehicle.spec_enterable.vehicleCharacter)) end
  else
    if ContractorMod.debug then print("ContractorMod: 253 " .. tostring(vehicle.isHired)) end
  end

  --[[
  if self.workers ~= nil then
    local currentWorker = self.workers[self.currentID]
    if currentWorker.isNewPassenger then
      local activeCam = getCamera()
      if (activeCam ~= nil) then
        -- Change camera here
        -- get current camera position
        local x, y, z = getTranslation(activeCam)
        print("x:"..tostring(x).." y:"..tostring(y).." z:"..tostring(z))
        -- local passengerNode = vehicle.passengers[currentWorker.seatIndex]
        -- print(tostring(passengerNode))
        -- local characterNode = vehicle.vehicleCharacter
        -- print(tostring(characterNode))
        -- local transformCam = localToLocal(passengerNode, characterNode)
        -- print(tostring(transformCam))
        -- move it for passenger
        -- setTranslation(vehicle.activeCamera.cameraPositionNode, (x - 1), y, z)
        -- vehicle.activeCamera:resetCamera()
      end
    end
  end ]]

  if ContractorMod.debug then print("ContractorMod: 251 " .. tostring(self.switching) .. " : " .. tostring(vehicle.steeringEnabled)) end
  if ContractorMod.debug then print("ContractorMod:appendedEnterVehicle <<" .. vehicleName) end
  if vehicle ~= nil then
    if ContractorMod.debug then print("isHired " .. tostring(vehicle.isHired) .. " disableChar " .. tostring(vehicle.disableCharacterOnLeave) .. " steering " .. tostring(vehicle.steeringEnabled)) end
  end
end
function ContractorMod:onEnterVehicle(vehicle, playerStyle)
  --print("ContractorMod:onEnterVehicle " .. vehicle.name)
  ContractorMod:ManageEnterVehicle(vehicle, playerStyle)
end
BaseMission.onEnterVehicle = Utils.appendedFunction(BaseMission.onEnterVehicle, ContractorMod.onEnterVehicle);

-- @doc Load VehicleCharacter for a passenger and put it at the given location
function ContractorMod.addPassenger(vehicle, x, y, z, rx, ry, rz)
    if ContractorMod.debug then print("ContractorMod.addPassenger") end
        local id = loadI3DFile(ContractorMod.myCurrentModDirectory.."passenger.i3d", false, false, false)
        local passengerNode = getChildAt(id, 0)
        link(vehicle.components[1].node, passengerNode)
        local ChildIndex = getChildIndex(passengerNode)
        setTranslation(passengerNode, x, y, z)
        setRotation(passengerNode, rx, ry, rz)
        
        local xmltext = " \z
        <vehicle> \z
        <enterable> \z
        <characterNode node=\"0>"..ChildIndex.."\" cameraMinDistance=\"1.5\" spineRotation=\"-90 0 90\" > \z
            <target ikChain=\"rightFoot\" targetNode=\"0>"..ChildIndex.."|1\" /> \z
            <target ikChain=\"leftFoot\"  targetNode=\"0>"..ChildIndex.."|2\" /> \z
            <target ikChain=\"rightArm\"  targetNode=\"0>"..ChildIndex.."|3\" /> \z
            <target ikChain=\"leftArm\"   targetNode=\"0>"..ChildIndex.."|4\" /> \z
        </characterNode></enterable></vehicle> \z
        "
        local xmlFile = loadXMLFileFromMemory("passengerConfig", xmltext)
        local passenger = VehicleCharacter:new(vehicle)
        --@FS19: How to load passenger ? should so like vehicleSetCharacter
        passenger:load(xmlFile, "vehicle.enterable.characterNode")

        --[[ Trying to add camera like passenger
        local cameraId = loadI3DFile(ContractorMod.myCurrentModDirectory.."camera.i3d", false, false, false)
        local cameraNode = getChildAt(cameraId, 0)
        link(vehicle.components[1].node, cameraNode)
        local cameraChildIndex = getChildIndex(cameraNode)
        setTranslation(cameraNode, x, y, z)
        setRotation(cameraNode, rx, ry, rz)
print("child "..cameraChildIndex)
        print("Passenger: x:"..tostring(x).." y:"..tostring(y).." z:"..tostring(z))
        local xmlCameraText = " \z
        <vehicle> \z
        <cameras count=\"1\"> \z
            <camera1 index=\"0>"..cameraChildIndex.."\" rotatable=\"true\" limit=\"true\" rotMinX=\"-1.1\" rotMaxX=\"0.4\" transMin=\"0\" transMax=\"0\" useMirror=\"true\" isInside=\"true\" /> \z
        </cameras></vehicle> \z
        "
        local xmlCameraFile = loadXMLFileFromMemory("passengerCameraConfig", xmlCameraText)
        local camera = VehicleCamera:new(vehicle)
        camera:loadFromXML(xmlCameraFile, "vehicle.cameras")]]
        -- get vehicleCharacter position (from xml ?)
        -- local characterNode = vehicle.vehicleCharacter.nodeId
        -- print(tostring(characterNode))
        -- local x1, y2, z1 = getTranslation(characterNode)
        -- print("x1:"..tostring(x1).." y1:"..tostring(y1).." z1:"..tostring(z1))
        -- compute transform
        -- local transformCam = localToLocal(passengerNode, characterNode)
        -- print(tostring(transformCam))
        -- add new camera

        return passenger
end

-- @doc Called when loading a vehicle (load game or buy new vehicle) to retrive and add passengers info
function ContractorMod:ManageNewVehicle(i3dNode, arguments)
    if ContractorMod.debug then print("ContractorMod.ManageNewVehicle") end

    --DebugUtil.printTableRecursively(self, 1, 1, 2);

    if SpecializationUtil.hasSpecialization(Enterable, self.specializations) then
      self.passengers = {}
      local foundConfig = false
      -- Don't display warning by default in log, only if displayWarning = true
      local xmlPath = "ContractorMod.passengerSeats"
      local modDirectoryXMLFilePath = ContractorMod.myCurrentModDirectory .. "../ContractorMod.xml"
      local displayWarning = false
      if fileExists(modDirectoryXMLFilePath) then
        local xmlFile = loadXMLFile('ContractorMod', modDirectoryXMLFilePath);
        displayWarning = Utils.getNoNil(getXMLBool(xmlFile, xmlPath.."#displayWarning"), false);
      end
      -- xml file in zip containing mainly base game vehicles
      foundConfig = ContractorMod:loadPassengersFromXML(self, ContractorMod.myCurrentModDirectory.."passengerseats.xml");
      if foundConfig == false then
        -- Try xml file in mods dir containing user mods
        foundConfig = ContractorMod:loadPassengersFromXML(self, modDirectoryXMLFilePath);
      end
      if foundConfig == false and displayWarning == true then
        print("[ContractorMod]No passenger seat configured for vehicle "..self.configFileName)
        print("[ContractorMod]Please edit ContractorMod.xml to set passenger position")
      end
    end
end
Vehicle.loadFinished = Utils.appendedFunction(Vehicle.loadFinished, ContractorMod.ManageNewVehicle);


-- function ContractorMod:ManageNewPlayer(a, b, c, d, e, f, g, h, i, j, k)
--   if ContractorMod.debug then print("ContractorMod.ManageNewPlayer") end
--   -- DebugUtil.printTableRecursively(self, 1, 1, 2);
--   print("a:"..tostring(a))
--   print("b:"..tostring(b))
--   -- DebugUtil.printTableRecursively(b, 1, 1, 2);
--   print("c:"..tostring(c))
--   print("d:"..tostring(d))
--   print("e:"..tostring(e))
--   -- DebugUtil.printTableRecursively(e, 1, 1, 2);
--   print("f:"..tostring(f))
--   print("g:"..tostring(g))
--   -- DebugUtil.printTableRecursively(g, 1, 1, 2);
--   print("h:"..tostring(h))
--   print("i:"..tostring(i))
--   print("j:"..tostring(j))
--   print("k:"..tostring(k))
-- end
-- Player.loadVisuals = Utils.appendedFunction(Player.loadVisuals, ContractorMod.ManageNewPlayer);

-- function ContractorMod:ManageKeyEvent(a, b, c, d, e)
--   if ContractorMod.debug then print("ContractorMod.ManageKeyEvent") end
--   -- DebugUtil.printTableRecursively(self, 1, 1, 2);
--   print("a:"..tostring(a))
--   print("b:"..tostring(b))
--   -- DebugUtil.printTableRecursively(b, 1, 1, 2);
--   print("c:"..tostring(c))
--   print("d:"..tostring(d))
--   print("e:"..tostring(e))
-- end
-- InputBinding.keyEvent = Utils.appendedFunction(InputBinding.keyEvent, ContractorMod.ManageKeyEvent);

-- @doc Define empty passenger for special vehicles like trains, crane
function ContractorMod:manageSpecialVehicles()
  if ContractorMod.debug then print("ContractorMod:manageSpecialVehicles") end
  for k, v in pairs(g_currentMission.nodeToVehicle) do --@FS19: to check nodeToObject
    if v ~= nil then
      local loco = v.motorType
      if loco ~= nil and loco == "locomotive" then
        -- no passengers for train
        v.passengers = {}
      else
        if v.stationCraneId ~= nil then
          -- no passengers for Station Crane
          v.passengers = {}
        end
      end
    end
  end
end

-- @doc Retrive passengers info from xml files for standard and mods enterable vehicles
function ContractorMod:loadPassengersFromXML(vehicle, xmlFilePath)
  if ContractorMod.debug then print("ContractorMod:loadPassengersFromXML") end
  local foundConfig = false
  if fileExists(xmlFilePath) then 
    local xmlFile = loadXMLFile('ContractorMod', xmlFilePath);
    local i = 0
    local xmlVehicleName = ''
    while hasXMLProperty(xmlFile, "ContractorMod.passengerSeats"..string.format(".Passenger(%d)", i)) do
        xmlPath = "ContractorMod.passengerSeats"..string.format(".Passenger(%d)", i)
        xmlVehicleName = getXMLString(xmlFile, xmlPath.."#vehiclesName")
        --@FS19if ContractorMod.debug then print("Trying to add passenger to "..xmlVehicleName) end
        --> ==Manage DLC & mods thanks to dural==
        --replace $pdlcdir by the full path
        if string.sub(xmlVehicleName, 1, 8):lower() == "$pdlcdir" then
          --xmlVehicleName = getUserProfileAppPath() .. "pdlc/" .. string.sub(xmlVehicleName, 10)
          --required for steam users
          xmlVehicleName = Utils.getFilename(xmlVehicleName)	--@FS19: is it the right function
        elseif string.sub(xmlVehicleName, 1, 7):lower() == "$moddir" then --20171116 - fix for Horsch CTF vehicle pack
          xmlVehicleName = Utils.getFilename(xmlVehicleName)	--@FS19: is it the right function
        end
        --< ======================================
        if vehicle.configFileName == xmlVehicleName then
          foundConfig = true
          local seatIndex = getXMLInt(xmlFile, xmlPath.."#seatIndex")
          local x = getXMLFloat(xmlFile, xmlPath.."#x")
          local y = getXMLFloat(xmlFile, xmlPath.."#y")
          local z = getXMLFloat(xmlFile, xmlPath.."#z")
          local rx = getXMLFloat(xmlFile, xmlPath.."#rx")
          local ry = getXMLFloat(xmlFile, xmlPath.."#ry")
          local rz = getXMLFloat(xmlFile, xmlPath.."#rz")
          if seatIndex == 1 and x == 0.0 and y == 0.0 and z == 0.0 then
            print("[ContractorMod]Passenger seat not configured yet for vehicle "..xmlVehicleName)
          end
          if seatIndex > 0 then
            print('Adding seat for '..xmlVehicleName)
            vehicle.passengers[seatIndex] = ContractorMod.addPassenger(vehicle, x, y, z, rx, ry, rz)
          end
        end
        i = i + 1
    end
  end
  return foundConfig
end

-- function ContractorMod:loadCharacter(a, b)
--   print("ContractorMod:loadCharacter")
--   print("a:"..tostring(a))
--   print("b:"..tostring(b))
--   print("ContractorMod: b")
--   printCallstack()
--   --DebugUtil.printTableRecursively(b, " ", 1, 4);
-- end
-- VehicleCharacter.loadCharacter = Utils.appendedFunction(VehicleCharacter.loadCharacter, ContractorMod.loadCharacter)

-- function ContractorMod:addSpecialization(a, b, c, d, e)
--   print("ContractorMod:addSpecialization")
--   print("a:"..tostring(a))
--   print("b:"..tostring(b))
--   print("a:"..tostring(c))
--   print("a:"..tostring(d))
--   print("a:"..tostring(e))
--   printCallstack()
-- end
-- VehicleTypeManager.addSpecialization =  Utils.appendedFunction(VehicleTypeManager.addSpecialization, ContractorMod.addSpecialization)

-- function ContractorMod:getVehicleTypes(a, b, c, d, e)
--   print("ContractorMod:getVehicleTypes")
--   print("a:"..tostring(a))
--   print("b:"..tostring(b))
--   print("a:"..tostring(c))
--   print("a:"..tostring(d))
--   print("a:"..tostring(e))
--   printCallstack()
-- end
-- VehicleTypeManager.getVehicleTypes =  Utils.appendedFunction(VehicleTypeManager.getVehicleTypes, ContractorMod.getVehicleTypes)

-- @doc Load and display characters in vehicle for drivers & passengers instead of default methods
function ContractorMod:placeVisualWorkerInVehicle(worker, vehicle, seat)
    if ContractorMod.debug then print("ContractorMod:placeVisualWorkerInVehicle") end
    if vehicle.spec_enterable.vehicleCharacter == nil and ContractorMod.debug then print("ContractorMod: vehicle.spec_enterable.vehicleCharacter == nil" ) end          
    if vehicle.passengers == nil then print("ContractorMod: vehicle.passengers == nil" ) end          

    if ContractorMod.debug then print("ContractorMod: playerStyle "..tostring(worker.playerStyle.selectedColorIndex)) end

    local character = vehicle:getVehicleCharacter()
  if seat == 0 and character ~= nil then
    -- Driver
    print("setVehicleCharacter as driver")
    -- local playerModel = g_playerModelManager:getPlayerModelByIndex(spec.playerStyle.selectedModelIndex)
    character = vehicle:setVehicleCharacter(worker.xmlFile, worker.playerStyle)
    -- vehicle.vehicleCharacter:loadCharacter(worker.xmlFile, worker.playerStyle)
    --IKUtil.updateIKChains(vehicle.spec_enterable.vehicleCharacter.ikChains);
    --character:setAllowCharacterUpdate(true)
  else
    -- Passenger
    if vehicle.passengers ~= nil then
      if vehicle.passengers[seat] ~= nil then
        print("setVehicleCharacter as passenger")
        character = vehicle:setVehicleCharacter(worker.xmlFile, worker.playerStyle)
        -- vehicle.passengers[seat]:loadCharacter(worker.xmlFile, worker.playerStyle)
        --IKUtil.updateIKChains(vehicle.passengers[seat].ikChains);
      else
        if vehicle.spec_enterable.vehicleCharacter ~= nil then
          -- no more passenger allowed
          if ContractorMod.debug then print("ContractorMod: Passenger will leave " ) end
          g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ContractorMod_NO_MORE_PASSENGER"))
          ContractorMod.shouldExit = true
        end
        -- if vehicle.vehicleCharacter == nil ==> belt system without visible character
      end
    end
  end
end


function ContractorMod:ReplaceEnterVehicle(superFunc, isControlling, playerStyle, farmId)

  -- @FS19
    -- local tmpXmlFilename = PlayerUtil.playerIndexToDesc[playerIndex].xmlFilename
    -- PlayerUtil.playerIndexToDesc[playerIndex].xmlFilename = ContractorMod.workers[ContractorMod.currentID].xmlFile
      local tmpXmlFilename = g_currentMission.player.xmlFilename
      g_currentMission.player.xmlFilename = ContractorMod.workers[ContractorMod.currentID].xmlFile
      -- Find free passengerSeat.
      -- 0 is drivers seat
      local seat
      local firstFreepassengerSeat = -1 -- no seat assigned. nil: not in vehicle.
      for seat = 0, 4 do
        local seatUsed = false
        for i = 1, ContractorMod.numWorkers do
          local worker = ContractorMod.workers[i]
          if worker.currentSeat == seat and worker.currentVehicle == self then
            seatUsed = true
            break
          end
        end
        if seatUsed == false and ( self.passengers[1] ~= nil or seat == 0 ) then
          firstFreepassengerSeat = seat
          break
        end
      end

      local tmpVehicleCharacter = self.vehicleCharacter
      local tmpPlayerStyle = self.playerStyle
      local tmpFarmId = self.farmId
      self.vehicleCharacter = nil -- Keep it from beeing modified
      superFunc(self, isControlling, ContractorMod.workers[ContractorMod.currentID].playerStyle, farmId)
      self.vehicleCharacter = tmpVehicleCharacter
      self.playerStyle = tmpPlayerStyle
      self.farmId = tmpFarmId
      
      -- When Initializing we are called when ContractorMod.currentID is not set.
      -- When switching vehicle we are called for drivers already entered but then currentSeat ~= nil.
      if ContractorMod.workers[ContractorMod.currentID].currentSeat == nil and not ContractorMod.initializing  then 
        ContractorMod.workers[ContractorMod.currentID].currentSeat = firstFreepassengerSeat
        ContractorMod:placeVisualWorkerInVehicle(ContractorMod.workers[ContractorMod.currentID], self, firstFreepassengerSeat)
        if firstFreepassengerSeat > 0 then
          if ContractorMod.debug then print("passenger entering") end
          ContractorMod.workers[ContractorMod.currentID].isNewPassenger = true
          -- TODO: Test somewhere if current worker is passenger/driver => update camera position
          -- get playerRoot vehicle
          -- compute seat - playerRoot transfo
          -- apply transfo to inside camera
          if ContractorMod.debug then print("Passenger should not be able to drive") end
        end
      end
  -- @FS19
    -- PlayerUtil.playerIndexToDesc[playerIndex].xmlFilename = tmpXmlFilename
    g_currentMission.player.xmlFilename = tmpXmlFilename
end
Enterable.enterVehicle = Utils.overwrittenFunction(Enterable.enterVehicle, ContractorMod.ReplaceEnterVehicle)

function ContractorMod:ReplaceSetRandomVehicleCharacter()
  print("ContractorMod:ReplaceSetRandomVehicleCharacter")
end
Enterable.setRandomVehicleCharacter = Utils.overwrittenFunction(Enterable.setRandomVehicleCharacter, ContractorMod.ReplaceSetRandomVehicleCharacter)


-- function ContractorMod:ReplaceOnStartAiVehicle(superFunc, isControlling, playerIndex, playerStyle)
--     if ContractorMod.debug then print("ContractorMod:ReplaceOnStartAiVehicle") end
--     local tmpVehicleCharacter = self.vehicleCharacter
--     self.vehicleCharacter = nil -- Keep it from beeing modified
--     superFunc(self)
--     self.vehicleCharacter = tmpVehicleCharacter
-- end
-- AIVehicle.onStartAiVehicle = Utils.overwrittenFunction(AIVehicle.onStartAiVehicle, ContractorMod.ReplaceOnStartAiVehicle)

-- function ContractorMod:ReplaceOnStopAiVehicle(superFunc, isControlling, playerIndex, playerStyle)
--     if ContractorMod.debug then print("ContractorMod:ReplaceOnStopAiVehicle") end
--     local tmpVehicleCharacter = self.vehicleCharacter
--     self.vehicleCharacter = nil -- Keep it from beeing modified
--     superFunc(self)
--     self.vehicleCharacter = tmpVehicleCharacter
-- end
-- AIVehicle.onStopAiVehicle = Utils.overwrittenFunction(AIVehicle.onStopAiVehicle, ContractorMod.ReplaceOnStopAiVehicle)

-- Enterable:enter()        => loadCharacter if isHired == false
-- Enterable:leaveVehicle() => deleteCharacter if disableCharacterOnLeave == true
function ContractorMod:ManageBeforeEnterVehicle(vehicle, playerStyle)
  local vehicleName = ""
  if vehicle ~= nil then
    if vehicle.name ~= nil then
      vehicleName = vehicle.name
    end
  end
  if ContractorMod.debug then print("ContractorMod:prependedEnterVehicle >>" .. vehicleName) end
  
  local doExit = false
  if self.workers ~= nil then
    if #self.workers > 0 and not self.initializing and not self.enableSeveralDrivers then
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.currentVehicle == vehicle then
          if worker.name ~= self.workers[self.currentID].name then
            if ContractorMod.debug then print("ContractorMod: "..worker.name .. " already in ") end
            if worker.isPassenger == false then
              if ContractorMod.debug then print("as driver") end
              doExit = true
            else
              if ContractorMod.debug then print("as passenger") end
              doExit = false
            end
          else
            doExit = false
          end
        end
      end
    end
  end
  if doExit then
    if ContractorMod.debug then print("ContractorMod: Player will leave before enter" ) end
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ContractorMod_VEHICLE_NOT_FREE"))
    if vehicle.spec_enterable.vehicleCharacter ~= nil then
      vehicle.spec_enterable.vehicleCharacter:delete();
    end
  end

  if self.switching then
    if not self.initializing then
      vehicle.isHired = true
    end
    -- Needed ??
    vehicle.currentHelper = g_helperManager:getRandomHelper()
    if ContractorMod.debug then print("ContractorMod: switching " .. tostring(vehicle.isHired)) end
  else
    vehicle.isHired = false
  end
  
  if ContractorMod.debug then print("ContractorMod: 268 " .. tostring(vehicle.isHired)) end
    -- vehicle.disableCharacterOnLeave = false;
  -- else
  vehicle.disableCharacterOnLeave = true;
  -- end
  
  if ContractorMod.debug then print("ContractorMod:prependedEnterVehicle <<" .. vehicle.typeName) end
  if vehicle ~= nil then
    if ContractorMod.debug then print("isHired " .. tostring(vehicle.isHired) .. " disableChar " .. tostring(vehicle.disableCharacterOnLeave) .. " steering " .. tostring(vehicle.steeringEnabled)) end
  end
end
function ContractorMod:beforeEnterVehicle(vehicle, playerStyle)
  if ContractorMod.debug then print("ContractorMod:beforeEnterVehicle " .. vehicle.typeName) end
  --print("arg1 "..tostring(playerStyle))
  DebugUtil.printTableRecursively(playerStyle, " ", 1, 1)
  ContractorMod:ManageBeforeEnterVehicle(vehicle, playerStyle)
end
BaseMission.onEnterVehicle = Utils.prependedFunction(BaseMission.onEnterVehicle, ContractorMod.beforeEnterVehicle);

function ContractorMod:preOnStopAiVehicle()
  if ContractorMod.debug then print("ContractorMod:preOnStopAiVehicle ") end
  --backup character
  self.tmpCharacter = self.vehicleCharacter;
  --won't be deleted next if nil
  self.vehicleCharacter = nil
end
AIVehicle.onStopAiVehicle = Utils.prependedFunction(AIVehicle.onStopAiVehicle, ContractorMod.preOnStopAiVehicle);

function ContractorMod:appOnStopAiVehicle()
  if ContractorMod.debug then print("ContractorMod:appOnStopAiVehicle ") end
  --restore character
  self.vehicleCharacter = self.tmpCharacter ;
  self.tmpCharacter = nil
end
AIVehicle.onStopAiVehicle = Utils.appendedFunction(AIVehicle.onStopAiVehicle, ContractorMod.appOnStopAiVehicle);

function ContractorMod:ReplaceOnStopFollowMe(superFunc, reason, noEventSend)
  if ContractorMod.debug then print("ContractorMod:ReplaceOnStopFollowMe") end
  local tmpVehicleCharacter = self.vehicleCharacter
  self.vehicleCharacter = nil -- Keep it from beeing modified
  superFunc(self, reason, noEventSend)
  self.vehicleCharacter = tmpVehicleCharacter
end

function ContractorMod:ReplaceOnStartFollowMe(superFunc, followObj, helperIndex, noEventSend)
  if ContractorMod.debug then print("ContractorMod:ReplaceOnStartFollowMe") end
  local tmpVehicleCharacter = self.vehicleCharacter
  self.vehicleCharacter = nil -- Keep it from beeing modified
  superFunc(self, followObj, helperIndex, noEventSend)
  self.vehicleCharacter = tmpVehicleCharacter
end

function ContractorMod:ReplaceStartCoursePlay(superFunc, vehicle)
  if ContractorMod.debug then print("ContractorMod:ReplaceStartCoursePlay") end
  local tmpVehicleCharacter = vehicle.spec_enterable.vehicleCharacter
  vehicle.spec_enterable.vehicleCharacter = nil -- Keep it from beeing modified
  superFunc(self, vehicle)
  vehicle.spec_enterable.vehicleCharacter = tmpVehicleCharacter
end

function ContractorMod:ReplaceStopCoursePlay(superFunc, vehicle)
  if ContractorMod.debug then print("ContractorMod:ReplaceStopCoursePlay") end
  local tmpVehicleCharacter = vehicle.spec_enterable.vehicleCharacter
  vehicle.spec_enterable.vehicleCharacter = nil -- Keep it from beeing modified
  superFunc(self, vehicle)
  vehicle.spec_enterable.vehicleCharacter = tmpVehicleCharacter
end

-- @doc Prevent from removing driver character
function ContractorMod:replaceGetDisableVehicleCharacterOnLeave(superfunc)
  if ContractorMod.debug then print("ContractorMod:replaceGetDisableVehicleCharacterOnLeave ") end
  if ContractorMod.switching then
    ContractorMod.switching = false
    print("return false")
    return false
  end
  if ContractorMod.passengerLeaving then
    ContractorMod.passengerLeaving = false
    print("return false")
    return false
  end
  return true
end
Enterable.getDisableVehicleCharacterOnLeave = Utils.overwrittenFunction(Enterable.getDisableVehicleCharacterOnLeave, ContractorMod.replaceGetDisableVehicleCharacterOnLeave);

-- @doc Make some checks before leaving a vehicle to manage passengers and hired worker
function ContractorMod:ManageLeaveVehicle(controlledVehicle)
  if ContractorMod.debug then print("ContractorMod:prependedLeaveVehicle >>") end
  if controlledVehicle ~= nil then
    if ContractorMod.debug then print("isHired " .. tostring(controlledVehicle.isHired) .. " disableChar " .. tostring(controlledVehicle.disableCharacterOnLeave) .. " steering " .. tostring(controlledVehicle.steeringEnabled)) end
  end

  if controlledVehicle ~= nil then
    if self.shouldStopWorker then
    
    local occupants = 0
    
    for i = 1, self.numWorkers do
      local worker = self.workers[i]
      if worker.currentVehicle == controlledVehicle then
        occupants = occupants + 1
      end
    end
      if occupants == 1 then -- Last driver leaving
        --Leaving vehicle
        if ContractorMod.debug then print("controlled vehicle " .. controlledVehicle.typeName) end
        if ContractorMod.debug then print("controlledVehicle.spec_enterable.isControlled " .. tostring(controlledVehicle.spec_enterable.isControlled)) end
        --if not controlledVehicle.spec_enterable.isControlled then
        if controlledVehicle:getIsAIActive() then
        --@FS19 if not controlledVehicle.steeringEnabled and controlledVehicle.stationCraneId == nil then
          --Leaving and AI activated
          g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, g_i18n:getText("ContractorMod_WORKER__STOP"))
          --Manage CoursePlay vehicles
          if controlledVehicle.cp ~= nil then
            if controlledVehicle.cp.isDriving then
             -- Try to stop the CP vehicle
              if ContractorMod.debug then print("setCourseplayFunc stop") end
              controlledVehicle:setCourseplayFunc('stop', nil, false, 1);
            else
              controlledVehicle:stopAIVehicle();
            end
          else
            controlledVehicle:stopAIVehicle();
          end
          --Leaving and no AI activated
          --Bear
          controlledVehicle.disableCharacterOnLeave = true;
        end
      else
        -- Drivers left
        controlledVehicle.disableCharacterOnLeave = false;
      end
      if ContractorMod.workers[ContractorMod.currentID].currentSeat == 0 then
        if ContractorMod.debug then print("ContractorMod: driver leaving") end
        if controlledVehicle.vehicleCharacter ~= nil then
          -- to manage vehicles without character like belt system
          controlledVehicle.vehicleCharacter:delete()
        end
      else
        if controlledVehicle.passengers[ContractorMod.workers[ContractorMod.currentID].currentSeat] ~= nil then
          controlledVehicle.passengers[ContractorMod.workers[ContractorMod.currentID].currentSeat]:delete()
          ContractorMod.workers[ContractorMod.currentID].isNewPassenger = false
          if ContractorMod.debug then print("passenger leaving") end
          self.passengerLeaving = true
          if controlledVehicle.vehicleCharacter ~= nil then
            if controlledVehicle.isEntered then
              -- Seems new issue after patch 1.5: character not visible when exiting passenger with inCab camera
              if ContractorMod.debug then print("ContractorMod:setCharacterVisibility") end
              controlledVehicle.vehicleCharacter:setCharacterVisibility(true)
            end
          end
        end
      end
      ContractorMod.workers[ContractorMod.currentID].currentSeat = nil
    else
      --Switching
      if controlledVehicle.spec_enterable.isControlled then
      --if controlledVehicle.steeringEnabled then
        if ContractorMod.debug then print("ContractorMod: steeringEnabled TRUE") end
        --No AI activated
        --controlledVehicle.isHired = true;
        --controlledVehicle.currentHelper = g_helperManager:getRandomHelper()
        controlledVehicle.disableCharacterOnLeave = false;
        controlledVehicle.isHirableBlocked = true;
        controlledVehicle.forceIsActive = true;
        controlledVehicle.stopMotorOnLeave = false;
        if controlledVehicle.vehicleCharacter ~= nil then
          if controlledVehicle.isEntered then
            -- Seems new issue after patch 1.5: character not visible when switching with inCab camera
            if ContractorMod.debug then print("ContractorMod:setCharacterVisibility") end
            controlledVehicle.vehicleCharacter:setCharacterVisibility(true)
          end
        end
      else
        if ContractorMod.debug then print("ContractorMod: steeringEnabled FALSE") end
        controlledVehicle.isHired = true;
        controlledVehicle.currentHelper = g_helperManager:getRandomHelper()
        controlledVehicle.disableCharacterOnLeave = false;
      end
    end
    -- if self.switching then
      -- controlledVehicle.disableCharacterOnLeave = false;
    -- else
      -- controlledVehicle.disableCharacterOnLeave = true;
    -- end
    if self.shouldExit then
      if ContractorMod.debug then print("ContractorMod: self.shouldExit") end
        controlledVehicle.disableCharacterOnLeave = false;
        controlledVehicle.isHirableBlocked = true;
        controlledVehicle.forceIsActive = true;
        controlledVehicle.stopMotorOnLeave = false;
        if controlledVehicle.vehicleCharacter ~= nil then
          if controlledVehicle.isEntered then
            -- Seems new issue after patch 1.5: character not visible when switching with inCab camera
            if ContractorMod.debug then print("ContractorMod:setCharacterVisibility") end
            controlledVehicle.vehicleCharacter:setCharacterVisibility(true)
          end
        end
    end 
    if ContractorMod.debug then print("ContractorMod:prependedLeaveVehicle <<" .. controlledVehicle.typeName) end
  end
  if controlledVehicle ~= nil then
    if ContractorMod.debug then print("isHired " .. tostring(controlledVehicle.isHired) .. " disableChar " .. tostring(controlledVehicle.disableCharacterOnLeave) .. " steering " .. tostring(controlledVehicle.steeringEnabled)) end
  end
end
function ContractorMod:onLeaveVehicle()
  if ContractorMod.debug then print("ContractorMod:onLeaveVehicle ") end
  local controlledVehicle = g_currentMission.controlledVehicle
  if controlledVehicle ~= nil then
    ContractorMod:ManageLeaveVehicle(controlledVehicle)
  end
end
BaseMission.onLeaveVehicle = Utils.prependedFunction(BaseMission.onLeaveVehicle, ContractorMod.onLeaveVehicle);

-- @doc Save workers info to restore them when starting game
function ContractorMod:onSaveCareerSavegame()
  if ContractorMod.debug then print("ContractorMod:onSaveCareerSavegame ") end
  if self.workers ~= nil then
    local xmlFile;
    if fileExists(self.ContractorModXmlFilePath) then
      xmlFile = loadXMLFile('ContractorMod', self.ContractorModXmlFilePath);
    else
      xmlFile = createXMLFile('ContractorMod', self.ContractorModXmlFilePath, 'ContractorMod');
      saveXMLFile(xmlFile);
    end;

    if xmlFile ~= nil then
      local rootXmlKey = "ContractorMod"

      -- update current worker position
      local currentWorker = self.workers[self.currentID]
      if currentWorker ~= nil then
        currentWorker:beforeSwitch(true)
      end
      
      local workerKey = rootXmlKey .. ".workers"
      setXMLInt(xmlFile, workerKey.."#numWorkers", self.numWorkers);
      setXMLBool(xmlFile, workerKey .."#enableSeveralDrivers", self.enableSeveralDrivers);
      setXMLBool(xmlFile, workerKey .."#displayOnFootWorker", self.displayOnFootWorker);

      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        local key = string.format(rootXmlKey .. ".workers.worker(%d)", i - 1);
        setXMLString(xmlFile, key.."#name", worker.name);
        setXMLString(xmlFile, key.."#gender", worker.gender);
        setXMLInt(xmlFile, key.."#playerColorIndex", worker.playerStyle.selectedColorIndex);
        setXMLInt(xmlFile, key.."#playerBodyIndex", worker.playerStyle.selectedBodyIndex);
        setXMLInt(xmlFile, key.."#playerHatIndex", worker.playerStyle.selectedHatIndex);
        setXMLInt(xmlFile, key.."#playerAccessoryIndex", worker.playerStyle.selectedAccessoryIndex);
        setXMLInt(xmlFile, key.."#playerHairIndex", worker.playerStyle.selectedHairIndex);
        setXMLInt(xmlFile, key.."#playerJacketIndex", worker.playerStyle.selectedJacketIndex);
        if worker.currentSeat ~= nil then
          setXMLInt(xmlFile, key.."#currentSeat", worker.currentSeat);
        end
        local pos = worker.x..' '..worker.y..' '..worker.z
        setXMLString(xmlFile, key.."#position", pos);
        local rot = worker.dx..' '..worker.dy..' '..worker.dz
        setXMLString(xmlFile, key.."#rotation", rot);
        local vehicleID = 0.
        if worker.currentVehicle ~= nil then
          vehicleID = NetworkUtil.getObjectId(worker.currentVehicle)
        end
        setXMLFloat(xmlFile, key.."#vehicleID", vehicleID);
      end
      saveXMLFile(xmlFile);
    end
  end
end

-- @doc Will call dedicated save method
SavegameController.onSaveComplete = Utils.prependedFunction(SavegameController.onSaveComplete, function(self)
    -- if self.isValid and self.xmlKey ~= nil then
    ContractorMod:onSaveCareerSavegame()
    -- end
end);

-- @doc Draw worker name and hotspots on map
function ContractorMod:draw()
  --if ContractorModWorker.debug then print("ContractorMod:draw()") end
  --Display current worker name
  if self.workers ~= nil then
    if #self.workers > 0 and g_currentMission.hud.isVisible then
      local currentWorker = self.workers[self.currentID]
      if currentWorker ~= nil then
        --Display current worker name
        currentWorker:displayName()
      end
      for i = 1, self.numWorkers do
        local worker = self.workers[i]
        if worker.mapHotSpot ~= nil then
          g_currentMission:removeMapHotspot(worker.mapHotSpot)
          worker.mapHotSpot:delete()
          worker.mapHotSpot = nil
        end
        --@FS19 Display workers on the minimap: To review marker and text size
        local _, textSize = getNormalizedScreenValues(0, 9);
        local _, textOffsetY = getNormalizedScreenValues(0, 24);
        local width, height = getNormalizedScreenValues(12, 12);
        if worker.currentVehicle == nil then
          --worker.mapHotSpot = g_currentMission.ingameMap:createMapHotspot(tostring(worker.name), tostring(worker.name), ContractorMod.myCurrentModDirectory .. "images/worker" .. tostring(i) .. ".dds", nil, nil, worker.x, worker.z, g_currentMission.ingameMap.mapArrowWidth / 3, g_currentMission.ingameMap.mapArrowHeight / 3, false, false, false, 0);
          worker.mapHotSpot = MapHotspot:new(tostring(worker.name), MapHotspot.CATEGORY_AI)
          worker.mapHotSpot:setSize(width, height)
          -- worker.mapHotSpot:setLinkedNode(0)
          worker.mapHotSpot:setText(tostring(worker.name))
          -- worker.mapHotSpot:setBorderedImage(nil, getNormalizedUVs({768, 768, 256, 256}), {worker.color[1], worker.color[2], worker.color[3], 1.0})
          worker.mapHotSpot:setImage(nil, getNormalizedUVs({768, 768, 256, 256}), {worker.color[1], worker.color[2], worker.color[3], 1.0})
          worker.mapHotSpot:setBackgroundImage(nil, getNormalizedUVs({768, 768, 256, 256}))
          worker.mapHotSpot:setIconScale(0.7)
          worker.mapHotSpot:setTextOptions(textSize, nil, textOffsetY, {worker.color[1], worker.color[2], worker.color[3], 1.0}, Overlay.ALIGN_VERTICAL_MIDDLE)
          worker.mapHotSpot:setWorldPosition(worker.x, worker.z)
          -- nil, getNormalizedUVs({768, 768, 256, 256}), {worker.color[1], worker.color[2], worker.color[3], 1.0},
          -- worker.x, worker.z, width, height, false, false, true, 0, true,
          -- MapHotspot.CATEGORY_DEFAULT, textSize, textOffsetY, {worker.color[1], worker.color[2], worker.color[3], 1.0},
          --nil, getNormalizedUVs({768, 768, 256, 256}), Overlay.ALIGN_VERTICAL_MIDDLE, 0.7));
        else
          if worker.currentVehicle.components ~= nil then
            --worker.mapHotSpot = g_currentMission:addMapHotspot(tostring(worker.name), tostring(worker.name), ContractorMod.myCurrentModDirectory .. "images/worker" .. tostring(i) .. ".dds", nil, nil, worker.x, worker.z, g_currentMission.ingameMap.mapArrowWidth / 3, g_currentMission.ingameMap.mapArrowHeight / 3, false, false, false, worker.currentVehicle.components[1].node, true);
            worker.mapHotSpot = MapHotspot:new(tostring(worker.name), MapHotspot.CATEGORY_AI)
            worker.mapHotSpot:setSize(width, height)
            worker.mapHotSpot:setLinkedNode(worker.currentVehicle.components[1].node)
            worker.mapHotSpot:setText(tostring(worker.name))
            worker.mapHotSpot:setImage(nil, getNormalizedUVs({768, 768, 256, 256}), {worker.color[1], worker.color[2], worker.color[3], 1.0})
            worker.mapHotSpot:setBackgroundImage(nil, getNormalizedUVs({768, 768, 256, 256}))
            worker.mapHotSpot:setIconScale(0.7)
            worker.mapHotSpot:setTextOptions(textSize, nil, textOffsetY, {worker.color[1], worker.color[2], worker.color[3], 1.0}, Overlay.ALIGN_VERTICAL_MIDDLE)
            --   nil, getNormalizedUVs({768, 768, 256, 256}), {worker.color[1], worker.color[2], worker.color[3], 1.0},
            -- worker.x, worker.z, width, height, false, false, true, worker.currentVehicle.components[1].node, true,
            -- MapHotspot.CATEGORY_DEFAULT, textSize, textOffsetY, {worker.color[1], worker.color[2], worker.color[3], 1.0},
            -- nil, getNormalizedUVs({768, 768, 256, 256}), Overlay.ALIGN_VERTICAL_MIDDLE, 0.7);
          else
            -- TODO: Analyze in which situation this happens
            if ContractorMod.debug then print("ContractorMod: worker.currentVehicle.components == nil" ) end          
          end
        end
        if (worker.mapHotSpot ~= nil) then
          g_currentMission:addMapHotspot(worker.mapHotSpot)
        end
      end
    end
  end
end

-- @doc Launch init at first call and then update workers positions and states
function ContractorMod:update(dt)
  if self.workers == nil then
    -- default values
    self:init()
    if #self.workers > 0 then
      self.switching = true
      self.shouldStopWorker = false
      -- Activate each vehicle once to show farmer in them
       for i = 2, self.numWorkers do
         local worker = self.workers[i]
         if worker.currentVehicle ~= nil then
           if worker.meshThirdPerson and self.displayOnFootWorker then
             setVisibility(worker.meshThirdPerson, false)
             setVisibility(worker.animRootThirdPerson, false)
           end
           --if ContractorMod.debug then print("sendEvent VehicleEnterRequestEvent " .. worker.name .. " : " .. worker.currentVehicle.typeName) end
           g_client:getServerConnection():sendEvent(VehicleEnterRequestEvent:new(worker.currentVehicle, worker.playerStyle, worker.farmId));
           g_currentMission:onLeaveVehicle()
         else
           if worker.meshThirdPerson and self.displayOnFootWorker then
             if ContractorMod.debug then print("ContractorMod: setVisibility(worker.meshThirdPerson"); end
             setVisibility(worker.meshThirdPerson, true)
             setVisibility(worker.animRootThirdPerson, true)
             local playerOffSet = g_currentMission.player.baseInformation.capsuleTotalHeight * 0.5
             setTranslation(worker.graphicsRootNode, worker.x, worker.y - playerOffSet, worker.z)
             setRotation(worker.graphicsRootNode, 0, worker.rotY, 0)
           end
         end
       end
      self.switching = false
      self.shouldStopWorker = true
    end
    local firstWorker = self.workers[self.currentID]
    if g_currentMission.player and g_currentMission.player ~= nil then
      if ContractorMod.debug then print("ContractorMod: moveToAbsolute"); end
      setTranslation(g_currentMission.player.rootNode, firstWorker.x, firstWorker.y, firstWorker.z);
      g_currentMission.player:moveToAbsolute(firstWorker.x, firstWorker.y, firstWorker.z);
      g_client:getServerConnection():sendEvent(PlayerTeleportEvent:new(firstWorker.x, firstWorker.y, firstWorker.z, true, true));
      g_currentMission.player.rotY = firstWorker.rotY
      if firstWorker.currentVehicle ~= nil then
        firstWorker:afterSwitch()
      end
    end
    self.initializing = false
  end
  
  if #self.workers > 0 then
    for i = 1, self.numWorkers do
      worker = self.workers[i]
      if i == self.currentID then
        -- For current player character
        if g_currentMission.controlledVehicle == nil then
          -- local passengerHoldingVehicle = g_currentMission.passengerHoldingVehicle;
          -- if passengerHoldingVehicle ~= nil then
          --   worker.isPassenger = true
          --   worker.currentVehicle = passengerHoldingVehicle;
          --   worker.passengerPlace = g_currentMission.passengerPlace
          -- else
            -- not in a vehicle
            worker.x, worker.y, worker.z = getWorldTranslation(g_currentMission.player.rootNode);
            worker.isPassenger = false
            worker.passengerPlace = 0
            worker.currentVehicle = nil;
          -- end
        else
          -- in a vehicle
          worker.x, worker.y, worker.z = getWorldTranslation(g_currentMission.controlledVehicle.rootNode); -- for miniMap update
          worker.currentVehicle = g_currentMission.controlledVehicle;
          -- forbid motor stop when switching between workers
          worker.currentVehicle.motorStopTimer = worker.currentVehicle.motorStopTimerDuration
          -- Trick to make FollowMe work as expected when stopping it
          if worker.currentVehicle.followMeIsStarted ~= nil then
            if worker.currentVehicle.followMeIsStarted then
              if worker.currentVehicle.followMeIsStarted ~= worker.followMeIsStarted then
                --Starting FollowMe
                if ContractorMod.debug then print("FollowMe has been started for current vehicle") end
                worker.followMeIsStarted = worker.currentVehicle.followMeIsStarted
              end
            else
              if worker.currentVehicle.followMeIsStarted ~= worker.followMeIsStarted then
                --Stopping FollowMe
                if ContractorMod.debug then print("FollowMe has been stopped for current vehicle") end
                worker.currentVehicle.isHired = false;
                worker.currentVehicle.steeringEnabled = true;
                worker.followMeIsStarted = worker.currentVehicle.followMeIsStarted
              end
            end
          end
        end
      else
        -- For other characters
        if worker.currentVehicle ~= nil and worker.currentVehicle.rootNode ~= nil then
          -- update if in a vehicle
          worker.x, worker.y, worker.z = getWorldTranslation(worker.currentVehicle.rootNode); -- for miniMap update
          -- forbid motor stop when switching between workers
          worker.currentVehicle.motorStopTimer = worker.currentVehicle.motorStopTimerDuration
          
          -- Trick to make FollowMe work as expected when stopping it
          if worker.currentVehicle.followMeIsStarted ~= nil then
            if worker.currentVehicle.followMeIsStarted then
              if worker.currentVehicle.followMeIsStarted ~= worker.followMeIsStarted then
                --Starting FollowMe
                if ContractorMod.debug then print("FollowMe has been started") end
                worker.followMeIsStarted = worker.currentVehicle.followMeIsStarted
              end
            else
              if worker.currentVehicle.followMeIsStarted ~= worker.followMeIsStarted then
                --Stopping FollowMe
                if ContractorMod.debug then print("FollowMe has been stopped") end
                worker.currentVehicle.isHired = false;
                worker.currentVehicle.steeringEnabled = true;
                worker.followMeIsStarted = worker.currentVehicle.followMeIsStarted
              end
            end
          end
        else
          worker.playerStateMachine:update(dt)
        end
      end
    end
    if self.shouldExit then
      if ContractorMod.debug then print("ContractorMod: Player leaving the vehicle") end
      g_currentMission:onLeaveVehicle()
      self.shouldExit = false
    end
  end
  
--[[ MOVED to actionCallback
  if Input.isKeyPressed(Input.KEY_tab) then
    if ContractorMod.debug then print("ContractorMod:update(dt) ContractorMod_NEXTWORKER") end
    local nextID = 0
    if ContractorMod.debug then print("ContractorMod: self.currentID " .. tostring(self.currentID)) end
    if ContractorMod.debug then print("ContractorMod: self.numWorkers " .. tostring(self.numWorkers)) end
    if self.currentID < self.numWorkers then
      nextID = self.currentID + 1
    else
      nextID = 1
    end
    if ContractorMod.debug then print("ContractorMod: nextID " .. tostring(nextID)) end
    self:setCurrentContractorModWorker(nextID)
  elseif Input.isKeyPressed(KEY_lshift) and Input.isKeyPressed(KEY_tab) then
    if ContractorMod.debug then print("ContractorMod:update(dt) ContractorMod_PREVWORKER") end
    local prevID = 0
    if self.currentID > 1 then
      prevID = self.currentID - 1
    else
      prevID = self.numWorkers
    end    
    self:setCurrentContractorModWorker(prevID)
  end--[[
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER1) then
    if self.numWorkers >= 1 then
      self:setCurrentContractorModWorker(1)
    end
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER2) then
    if self.numWorkers >= 2 then
      self:setCurrentContractorModWorker(2)
    end
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER3) then
    if self.numWorkers >= 3 then
      self:setCurrentContractorModWorker(3)
    end
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER4) then
    if self.numWorkers >= 4 then
      self:setCurrentContractorModWorker(4)
    end
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER5) then
    if self.numWorkers >= 5 then
      self:setCurrentContractorModWorker(5)
    end
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER6) then
    if self.numWorkers >= 6 then
      self:setCurrentContractorModWorker(6)
    end
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER7) then
    if self.numWorkers >= 7 then
      self:setCurrentContractorModWorker(7)
    end
  elseif InputBinding.keyEvent(InputBinding.ContractorMod_WORKER8) then
    if self.numWorkers >= 8 then
      self:setCurrentContractorModWorker(8)
    end
  end
  ]]
end

-- @doc Change active worker
function ContractorMod:setCurrentContractorModWorker(setID)
  if ContractorMod.debug then print("ContractorMod:setCurrentContractorModWorker(setID) " .. tostring(setID)) end
  local currentWorker = self.workers[self.currentID]
  if currentWorker ~= nil then
    self.shouldStopWorker = false
    self.switching = true
    currentWorker:beforeSwitch()
  end
  self.currentID = setID
  currentWorker = self.workers[self.currentID]
  if currentWorker ~= nil then
    currentWorker:afterSwitch()
    self.shouldStopWorker = true
    self.switching = false
  end
end

-- @doc Enable to overwrite other mods functions
function ContractorMod:manageModsConflicts()
	--***********************************************************************************
	--** taking care of FollowMe & CoursePlay Mods (thanks Dural for this code sample)
	--***********************************************************************************		
  if g_modIsLoaded["FS17_DCK_FollowMe"] then		
		local mod1 = getfenv(0)["FS17_DCK_FollowMe"]		
		if mod1 ~= nil and mod1.FollowMe ~= nil then
      ContractorMod.mod1 = mod1
      if ContractorMod.debug then print("We have found FollowMe mod and will encapsulate some functions") end
      mod1.FollowMe.onStopFollowMe = Utils.overwrittenFunction(mod1.FollowMe.onStopFollowMe, ContractorMod.ReplaceOnStopFollowMe)
      mod1.FollowMe.onStartFollowMe = Utils.overwrittenFunction(mod1.FollowMe.onStartFollowMe, ContractorMod.ReplaceOnStartFollowMe)
		end
  end
  if g_modIsLoaded["FS17_Courseplay"] then		
		local mod2 = getfenv(0)["FS17_Courseplay"]		
		if mod2 ~= nil and mod2.courseplay ~= nil then
      ContractorMod.mod2 = mod2
      if ContractorMod.debug then print("We have found Courseplay mod and will encapsulate some functions") end
      mod2.courseplay.start = Utils.overwrittenFunction(mod2.courseplay.start, ContractorMod.ReplaceStartCoursePlay)
      mod2.courseplay.stop = Utils.overwrittenFunction(mod2.courseplay.stop, ContractorMod.ReplaceStopCoursePlay)
		end
	end
	--***********************************************************************************
end

addModEventListener(ContractorMod);
