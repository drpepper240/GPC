--computercraft
--general-purpose controller server by drPepper

-- "THE BEER-WARE LICENSE"
-- drPepper@KOPROKUBACH wrote this file. As long as you retain this notice you
-- can do whatever you want with this stuff. If we meet some day, in-game or IRL,
-- and you think this stuff is worth it, you can give me a beer in return

--don't forget to update this string
VERSION_STRING = "0.70e"

---------------------------------------------------------------------------------------------------
-------------------			README
---------------------------------------------------------------------------------------------------

-- Not actually a readme, just some hints on what is it and how to use it.

-- This is a library (literally) of functions, which may help you to build a computercraft server with GUI and touch screen operation.

-- By "server" I mean CC console with a modem and a touchscreen, using which you can control remotely some other CC consoles connected to the same network. For example, some will switch redstone output, some will sense redstone input, some will use other CC peripheral APIs to control various peripherals. These remote consoles are mentioned as "clients" or "controllers/sensors"
-- Why don't I use CC Remote Peripherals for the latter? Because you'll never tell which laser is "laser_003" and which is "laser_123" after someone else connects them all as remote peripherals to your network with modems.

-- This is NOT a working code, so you shouldn't expect this to run on your CC, although you can find some code besides function bodies left unintentionally or with illustrative purpose.

-- I'm trying to maintain this code bug-free and working, but I'm unable to check it and retest regularly (== at least every month). If you absolutely sure you must contact me, feel free to use (but don't abuse) my skуре drpepper<underscore>mc

-- Why don't I make an "API" out of this? Because:
--		you can't define a variable or a constant in the CC "API" and access it both from the API functions and program functions: actually there will be a copy of such variable inaccessible to API functions.
--		you can still pass these vars as function arguments, but sometimes there are too many. Way too many. Fuck it.
--		also there are some program- and application-specific types of temporary data. For example, you want to store something in the CC server messing with your lasers, and you don't want to create such variables/tables on your other CC servers, and this data is temporary.
--		and, if none of the above is applicable, the function is marked as "API compatible". I plan to move such functions to the loadable API someday.

-- How does it work? Firstly, there are threads. No, not exactly, but CC Parallel API works and is easy to use and hard to misuse, and true treads don't and aren't. 
-- Note: various sleep and timer functions either do not work or aren't robust. My advise is to use "network timers": simple non-parallel program which sends messages on a specific channel.

-- Threads. There are at least three of them: first one receives network messages, second one is draws or redraws all GUI or single widgets, and the last processes user input (and, therefore, sending messages). Just like in the IPhone, but better and free of charge.

-- "sdata" file: there are three tables there: "guiData", "ctrlData" and "settings". First is used in GUI look and operating, second - in message receiving/processing. Each server must use its own sdata file with its own settings and GUI elements. You should't modify its contents during the execution and should edit it on the pastebin and just update it from CC. Store settings in a different file and use ReadResume/WriteResume for your convenience.

-- Touch-screen operation:
--		T_guiXy - There is a big table equal to the monitor resolution (for now only one touch-screen is supported), each [x][y] cell either is empty (or do not exist) or contains an ID named guiDataId. This ID is taken from sdata.guiData[i] and is written to the T_guiXy only after a widget is drawn. This table and ID are used to process touchscreen clicks. This table is temporary.
--		After guiDataId is obtained, it is passed to appropriate "clicking" function which does something: sends, writes to console or draws something on the screen.

-- Receiving thread operation:
--		T_ctrlTempData - This is the table where the last received data from a specific controller is stored. Receiving thread may post an event to redraw all screen or just specific controllers affected by the message. Populated during "drawing" from guiData[i].controllerIds[], temporary. ControllerIDs are from sdata.ctrlData[i], widgetIDs to redraw - from sdata.ctrlData[i].guiIds[]

-- Redrawing thread operation:
--		waits for a redraw event and calls appropriate "drawing" function

-- Modes:
--		some widgets can be drawed differently according to the current mode stored in a variable "guiMode". Default is "MODE_DEFAULT"

-- Widget types:
--		are used to determine which widget drawing function to call

-- Controller states:
-- 		are named by color, and corresponding color is used in the widget associated with a controller. DO NOT USE ORANGE (or any other color) representing missing (unresponsive) controllers. E.g. "green" is "on" and "red" is "off". You can set the controller to act vice-versa, the server does not need to know about it.

-- Q: "This is so complicated, why don't you use _G or other LUA 1337 features?" 
-- A: Because I don't know what will CC developers limit in the next release and what will not work as described. Things I use are supported and maintained by CC devs, therefore simple and robust.

-- Q: How to use it goddammit?
-- A: Create "startup" and "sdata" files using functions from this file and sample sdata files, and download them from pastebin to your CC console. It's better to declare all used functions first and paste their bodies below: you can keep them in a preferred order without conflicts.

-- "Standards":
--		CamelCase
--		first letter in variables/constants is lowerCase, in functions - UpperCase
--		all tables not from sdata must begin with "T_". Or at least global ones. This is handy, trust me.
-- 		Wanna hardcode something? Put it into sdata.settings.

-- Happy debugging!



---------------------------------------------------------------------------------------------------
-------------------			LISTS
---------------------------------------------------------------------------------------------------

-------------------			WIDGET TYPES

--AIRGEN_ALL			--turn on all airgens
--SWITCH				--switch redstone output for a single controller
--LABEL 				--just a sign { guiType = "LABEL", guiName = "Label Text", draw = { xPos = 1, yPos = 2, len = 10, textCol = colors.black, bgCol = colors.white } }
--ENER_BARS				--bars: each is a sensor-controller { guiType = "ENER_BARS", guiName = "", controllerIds = { [1]="ENER_STOR_1", [2]="ENER_STOR_2", ...}, draw = { xPos = 1, yPos = 2, lenMultiplier = 2 } }
--SENSOR				--shows its state, clicking on it sends state request { guiType = "SENSOR", guiNameRed = "fuel low", guiNameGreen = "fuel normal", controllerIds = {"SENSOR_FUEL"}, draw = { xPos = 1, yPos = 2, len = 10 } }
--GUI_MODE_SWITCH		--switches gui mode between "MODE" and "default" { guiType = "GUI_MODE_SWITCH", guiName = "ver", guiMode = "MODE_VERSION", draw = { xPos = nil, yPos = 1, len = 10 } }
--LASER_EM				--emitter info { guiType = "LASER_EM", guiName = "Lazor", controllerIds = {"LASER_P_1"}, draw = { xPos = 1, yPos = 2 }, laserData = { relX = 5, relY = 0, relZ = -3 } } --TODO update
--TARGET_TABLE			--target table: length is fixed (17), uses global gui temporary table { draw = { xPos = 1, yPos = 2 }  } --TODO update description
						--T_guiTempData uses: targetList[numeric index] = {x,y,z,comment}
--REFERENCE_POINT		--stores global coordinates of ship's origin, uses a Laser Emitter to get global coordinates. All widgets must have its ID in order to access them --TODO sdata description
						--T_guiTempData uses: origin = {x,y,z} 
--ENGAGE_BUTTON			--stores all packets for laser engagement and sends them when pushed
						--T_guiTempData uses: [laserControllerId] = {packet to send} 


-------------------			CONTROLLER TYPES (client-side)
--P_ 					--all peripheral-operating controllers MUST begin with this
--P_LEM					--laser emitter
--CONTROLLER			--default type

--AIRLOCK				--two monitors, two redstone outputs


-------------------			MODES

--MODE_DEFAULT			--default
--MODE_VERSION			--shows controller software version (where possible)
--MODE_UPDATE			--click on a widget sends an "update" message to all associated controllers instead of passing the click to processing function
--MODE_OVERRIDE			--click on a widget sends an "override" message to all associated controllers instead of passing the click to processing function
--MODE_GFOR				--show coordinates in global frame of reference where possible
--MODE_LFOR				--show coordinates in local (ship-bound) frame of reference where possible


-------------------			DEBUG LEVELS
-- messageLevel <= sdata.settings.debugLvl - message goes to console TODO write all messages to logfile
--0						--important TODO make a widget to display
--1						--less important (unlisted controllers, unknown packets, ...)
--2						--trivial




--TODO remove old description:----
--TABLES IN MEMORY
--T_T_guiXy: x,y -> id_gui
--T_ctrlTempData: id_controller -> temporary data (current state, last update, etc) { state = color.green... }

--TABLES ON DISK -- deprecated -- all settings including GUI markup must be supplied in "sdata" file and loaded as an API
--sdata.guiData: id_gui -> wat do on click, how to draw it, etc
--sdata.ctrlData: id_controller -> type, data, id_gui
--sdata.settings: server settings like monitor/modem side


--PROPOSED BEHAVIOR:
-- click event -> processClick(x,y) -> T_guiXy[x][y] -> id_gui -> sdata.guiData[id_gui].guiType -> ClickControllerType[id_gui] -> id_controller(s) -> messages

-- modem message event -> processMessage(message) -> id_controller -> sdata.ctrlData[id_controller] 							-> id_gui -> os.queueEvent("redraw", id_gui) -> drawGuiElement(id_gui)
--																   -> T_ctrlTempData[id_controller].state = message.state
--																   -> T_ctrlTempData[id_controller].lastResp = curTime

----end of the old description----


---------------------------------------------------------------------------------------------------
-------------------			GLOBALS
---------------------------------------------------------------------------------------------------


--load data tables
os.loadAPI("sdata")

--controller temporary data (must be populated according to messages received or sent)
T_ctrlTempData = {}

--gui temporary data 
--TODO UNUSED?
T_guiTempData = {}

--GUI click mapping table (must be populated in GUI render functions)
T_guiXy = {}

--gui mode
guiMode = "MODE_DEFAULT"

--modem
modem = nil
--touchscreen-capable monitor
monitor = nil
--monitor size
mSizeX = nil
mSizeY = nil


---------------------------------------------------------------------------------------------------
-------------------			MAIN UTILS
---------------------------------------------------------------------------------------------------

--monitor&modem init
function Init()
	modem = peripheral.wrap(sdata.settings.modemSide)
	while modem==nil do
		PrintDbg("Wrapping modem...\n", 1)
		sleep(1)
		modem = peripheral.wrap(sdata.settings.modemSide)
	end
	
	openChannel(modem, sdata.settings.channelReceive)
	
	monitor = peripheral.wrap(sdata.settings.monitorSide)
	while monitor==nil do
		PrintDbg("Wrapping monitor...\n", 1)
		sleep(1)
		monitor = peripheral.wrap(sdata.settings.monitorSide)
	end
	monitor.setTextScale(sdata.settings.textSize)
	mSizeX, mSizeY = monitor.getSize()
	PrintDbg("GPC server by drPepper", 0)
	PrintDbg("Version "..VERSION_STRING, 0)
	PrintDbg("Monitor size:"..tostring(mSizeX)..", "..tostring(mSizeY), 1)
	monitor.write("GPC server by drPepper")
	monitor.write("version "..VERSION_STRING)
	
end

--GUI input thread
function GuiLoop()
	--initial render
	DrawAll()
	while true do
		local event, p1, p2, p3, p4, p5 = os.pullEvent()
		if event == "monitor_touch" then
			ProcessClick(p2,p3)
		elseif event == "key" then
			if p1 == 22 then
				print("press 1 to update only sdata, 2 to update everything")
				sleep(0.3)
				local event, p1, p2, p3, p4, p5  = os.pullEvent("key")
				if p1 == 2 then
					shell.run("rm", "sdata")
					shell.run("pastebin", "get "..sdata.settings.pastebinSData.." sdata")
					os.reboot()
				elseif p1 == 3 then
					shell.run("rm", "sdata")
					shell.run("pastebin", "get "..sdata.settings.pastebinSData.." sdata")
					shell.run("rm", "startup")
					shell.run("pastebin", "get "..sdata.settings.pastebin.." startup")
					os.reboot()
				end
			end
		end
		
	end
end

--GUI redraw thread
function RedrawLoop()
	while true do
		local event, p1 = os.pullEvent("redraw")
		if p1~=nil then
			for k,v in pairs (p1) do
				PrintDbg("redrawing "..tostring(v), 2)
				DrawWidget(v)
			end
		else
			DrawAll()
		end
	end
end

--message receiving/processing thread
function ReceiveLoop()
	while true do
		local event, p1, p2, p3, p4, p5  = os.pullEvent("modem_message")
		ProcessMessage(p4)
	end
end

---------------------------------------------------------------------------------------------------
-------------------			GENERAL UTILS
---------------------------------------------------------------------------------------------------

--serializes given table to a file using given or default name (if no given)
--API compatible
function WriteResume(tableName, fileName)
	if tableName == nil then
		PrintDbg("No table provided!", 0)
		return
	end
	fileName = tostring(fileName)
	if fileName == nil then
		fileName = "resume"
	end
	local file = fs.open(fileName,"w")
	local sT = textutils.serialize(tableName)
	file.write(sT)
	file.close()
	return
end


--reads setting to a given table from a given or default file, writes default first if no file exists
--API compatible
function ReadResume(tableName, fileName)
	if tableName == nil then
		PrintDbg("No table provided!", 0)
		return
	end
	fileName = tostring(fileName)
	if fileName == nil then
		fileName = "resume"
	end
	if not fs.exists(fileName) then
		PrintDbg("Trying to resume without resume file, creating default: "..fileName, 1)
		WriteResume(tableName, fileName)
	end
	local file = fs.open(fileName,"r")
	local sT = file.readAll()
	tableName = textutils.unserialize(sT)
	file.close()
    return tableName
end

--opens a channel
--API compatible
function openChannel(modem, n)
	if modem == nil then
		PrintDbg("no modem present", 0)
		return
	end
	modem.open(n)
	while modem.isOpen(n)== false do
		PrintDbg("opening channel "..n.."...\n", 1)
		sleep(1)
		modem.open(n)
	end
end


--kiloticks in 24hr format as args
--API compatible
function KiloTicksPassed(from, to)
	if (from > to) then
		--midnight
		to = to+24.0   
	end
	return (to-from)
end


--debug messages
function PrintDbg(message, level)
	if level == nil then
		level = 1
	end
	if (level <= sdata.settings.debugLvl) then
		print("D:"..message)
	end
end

--converts from Minecraft Cartesian to Polar (zenith angle from y axis to r, azimuth from z axis to r projection)
--returns radial distance, zenith angle and azimuth angle in radians
--zenith angle varies from 0 to pi, azimuth angle varies from -pi to pi, thanks to math.atan2()
function CartesianToPolar(x, y, z)
	if x== nil or y==nil or z==nil then
		return nil, nil, nil
	end

	x = tonumber(x)
	y = tonumber(y)
	z = tonumber(z)
	local r = math.sqrt(x*x + y*y +z*z)
	if r == 0 then
		return 0, 0, 0
	end

	local theta = math.acos( y/r )
	local phi = math.atan2(x, z)
	return r, theta, phi
end

---------------------------------------------------------------------------------------------------
-------------------			NETWORK HI-LEVEL
---------------------------------------------------------------------------------------------------

--sends status request to the client
function SendStatusRequest(target)
	local packetT = 
	{
		target = target,
		command = "REPORT",
	}

	PrintDbg("sending REPORT to "..target, 2)
	local packet = textutils.serialize(packetT)
	modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, packet)
end


function SendPosRequest(target)
	local packetT = 
	{
		target = target,
		command = "PEXECUTE",
		pCommand = "pos"
	}
	PrintDbg("sending PEXECUTE pos to "..target, 2)
	local packet = textutils.serialize(packetT)
	modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, packet)
end


--stores received data and posts redraw event
function ProcessMessage(packet)
	local curTime = os.time()
	local packetT = textutils.unserialize(packet)
	if packetT.sender ~= nil and packetT.state ~= nil then
		PrintDbg("Received "..tostring(packetT.state).." from "..tostring(packetT.sender), 2)
		if T_ctrlTempData[tostring(packetT.sender)] ~= nil then
			T_ctrlTempData[tostring(packetT.sender)].state = packetT.state
			T_ctrlTempData[tostring(packetT.sender)].lastResp = curTime
			T_ctrlTempData[tostring(packetT.sender)].version = packetT.version
			T_ctrlTempData[tostring(packetT.sender)].override = packetT.override
			--Peripheral processing
			if string.sub(packetT.controllerType, 1, 2) == "P_" then
				ProcessPeripheralReturnMessage(packetT)
			end
		end
		if sdata.ctrlData[packetT.sender] ~= nil then
			PrintDbg("posting redraw event for "..tostring(packetT.sender), 2)
			
			os.queueEvent("redraw", sdata.ctrlData[packetT.sender].guiIds)
		else
			PrintDbg("ProcessMessage(): no ctrlData for "..tostring(packetT.sender), 2)
		end
	end
	
end


--processes data returned by a peripheral.call() method executed on a remote controller
--max of 6 returned params are supported, for the support of different peripheral types see the code
function ProcessPeripheralReturnMessage(packetT)
	if packetT.pExdCommand == nil then
		PrintDbg("no pExdCommand in the incoming packet", 2)
		return
	end
	
	if T_ctrlTempData[tostring(packetT.sender)] == nil then
		T_ctrlTempData[tostring(packetT.sender)] = {}
	end
		
	T_ctrlTempData[tostring(packetT.sender)][tostring(packetT.pExdCommand)] = { [1] = packetT.p1,
																				[2] = packetT.p2, 
																				[3] = packetT.p3, 
																				[4] = packetT.p4, 
																				[5] = packetT.p5, 
																				[6] = packetT.p6 } 
	PrintDbg("ec: "..tostring(packetT.pExdCommand), 2)
	PrintDbg("p1: "..tostring(packetT.p1), 2)
	PrintDbg("p2: "..tostring(packetT.p2), 2)
	PrintDbg("p3: "..tostring(packetT.p3), 2)
	PrintDbg("p4: "..tostring(packetT.p4), 2)
	PrintDbg("p5: "..tostring(packetT.p5), 2)
	PrintDbg("p6: "..tostring(packetT.p6), 2)
end


---------------------------------------------------------------------------------------------------
-------------------			WIDGET DRAWING
---------------------------------------------------------------------------------------------------

--draw all widgets from sdata
function DrawAll()
	monitor.setBackgroundColor(sdata.settings.guiBgColor)
	monitor.clear()
	monitor.setCursorPos(1,1)
	for k,v in pairs (sdata.guiData) do
		PrintDbg("drawing "..tostring(k), 2)
		DrawWidget(k)
	end
end

--chooses proper drawing function by id
function DrawWidget(guiDataId)
	if sdata.guiData[guiDataId] == nil or sdata.guiData[guiDataId].guiType == nil then
		PrintDbg("DrawWidget() error: "..tostring(guiDataId), 2)
		return
	end
	
	local controllerType = sdata.guiData[guiDataId].guiType
	
	if controllerType == "SWITCH" then
		DrawWidgetSwitch(guiDataId)
	elseif controllerType == "AIRGEN_ALL" then
		DrawWidgetAGAll(guiDataId)
	elseif controllerType == "LABEL" then
		DrawWidgetLabel(guiDataId)
	elseif controllerType == "SENSOR" then
		DrawWidgetSensor(guiDataId)
	elseif controllerType == "ENER_BARS" then
		DrawWidgetSensorBar(guiDataId)
	elseif controllerType == "LASER_EM" then
		DrawWidgetLaserEm(guiDataId)
	elseif controllerType == "GUI_MODE_SWITCH" then
		DrawWidgetGuiModeSwitch(guiDataId)
	elseif controllerType == "TARGET_TABLE" then
		DrawWidgetTargetTable(guiDataId)
	elseif controllerType == "REFERENCE_POINT" then
		DrawWidgetReferencePoint(guiDataId)
	elseif controllerType == "ENGAGE_BUTTON" then
		DrawWidgetEngageButton(guiDataId)
	else
		PrintDbg("DrawWidget(): unknown type: "..tostring(sdata.guiData[guiDataId].guiType), 2)
	end
	
end

--for simple on/off controllers, which state is depicted by color string, only first controllerId is used
function DrawWidgetSwitch(guiDataId)
	local widget = sdata.guiData[guiDataId]
	if widget.draw.xPos == nil or widget.draw.yPos == nil then
		PrintDbg("DrawWidgetSwitch() data missing", 2)
		return
	end
	local yPosition = tonumber(widget.draw.yPos)
	local xPosition = tonumber(widget.draw.xPos)
	local widgetText = guiDataId

	if widget.guiName ~= nil and widget.guiName ~= "" then
		widgetText = widget.guiName
	end
	
	monitor.setCursorPos(xPosition, yPosition)
	monitor.setTextColor(sdata.settings.guiTextColor)
	
	local curTime = os.time()
	local controllerId = widget.controllerIds[1]
	if controllerId == nil then
		PrintDbg("DrawWidgetSwitch() controllerId missing", 2)
		return
	end
	local missing = false
	
	if T_ctrlTempData[controllerId] == nil then
		T_ctrlTempData[controllerId] = {}
		T_ctrlTempData[controllerId].state = colors.orange
		T_ctrlTempData[controllerId].lastResp = 0
	end
	
	local lastTime = T_ctrlTempData[controllerId].lastResp
	if lastTime == nil then
		lastTime = 0
	end
	
	--checking if missing
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusUpdate then
		--sending status request
		SendStatusRequest(controllerId)		
	end
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusTimeout then
		--marking as missing
		missing = true
	end
	
	if missing then 
		monitor.setBackgroundColor(colors.orange)
	else
		monitor.setBackgroundColor(T_ctrlTempData[controllerId].state)
	end
	
	local maxX = mSizeX
	if widget.draw.len ~= nil then
		maxX = xPosition + widget.draw.len
	end
	
	if guiMode == "MODE_VERSION" then
		widgetText = tostring(T_ctrlTempData[controllerId].version)
	elseif guiMode == "MODE_OVERRIDE" then
		widgetText = tostring(T_ctrlTempData[controllerId].override)
	end
	
	for i = xPosition, maxX do 
		local letterPos = i + 1 - xPosition
		if letterPos <= string.len(widgetText) then
			monitor.write(string.sub(widgetText, letterPos, letterPos))
		else
			monitor.write(" ")
		end
		
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end
		T_guiXy[i][yPosition] = guiDataId
	end
end

function DrawWidgetAGAll(guiDataId)
	if sdata.guiData[guiDataId].draw.yPos == nil then 
		PrintDbg("DrawWidgetAGAll error", 2)
		return
	end
	local yPosition = tonumber(sdata.guiData[guiDataId].draw.yPos)
	local xPosition = tonumber(mSizeX - sdata.settings.guiRightColWidth)
	monitor.setCursorPos(xPosition, yPosition)
	monitor.setTextColor(sdata.settings.guiTextColor)
	monitor.setBackgroundColor(colors.gray)
	monitor.write("ALL AG")
	if T_guiXy[xPosition] == nil then
		T_guiXy[xPosition] = {}
	end
	for i = xPosition, mSizeX do
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end	
		T_guiXy[i][yPosition] = guiDataId
	end
end


function DrawWidgetLabel(guiDataId)
	local label = sdata.guiData[guiDataId]
	if label.draw.yPos == nil or label.draw.xPos == nil then 
		PrintDbg("DrawWidgetLabel() error", 2)
		return
	end
	local yPosition = tonumber(label.draw.yPos)
	local xPosition = tonumber(label.draw.xPos)
	monitor.setCursorPos(xPosition, yPosition)
	if label.draw.textCol ~= nil then 
		monitor.setTextColor(label.draw.textCol)
	end
	if label.draw.bgCol ~= nil then 
		monitor.setBackgroundColor(label.draw.bgCol)
	end
	
	local maxX = mSizeX
	if label.draw.len ~= nil then
		maxX = xPosition + label.draw.len
	end
	
	for i = xPosition, maxX do
		local letterPos = i + 1 - xPosition
		if letterPos <= string.len(label.guiName) then
			monitor.write(string.sub(label.guiName, letterPos, letterPos))
		else
			monitor.write(" ")
		end
		
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end
		T_guiXy[i][label.draw.yPos] = guiDataId
	end
end


function DrawWidgetSensor(guiDataId)
	local sensor = sdata.guiData[guiDataId]
	if sensor.draw.xPos == nil or sensor.draw.yPos == nil then
		PrintDbg("DrawWidgetSensor() data missing", 2)
		return
	end
	local yPosition = tonumber(sensor.draw.yPos)
	local xPosition = tonumber(sensor.draw.xPos)
	monitor.setCursorPos(xPosition, yPosition)
	monitor.setTextColor(sdata.settings.guiTextColor)
	local curTime = os.time()
	
	local sensorId = sensor.controllerIds[1]
	if sensorId == nil then
		PrintDbg("DrawWidgetSensor() sensorId missing", 2)
		return
	end
	local missing = false
	
	if T_ctrlTempData[sensorId] == nil then
		T_ctrlTempData[sensorId] = { state = colors.orange, lastResp = 0 }
	end
	
	local lastTime = T_ctrlTempData[sensorId].lastResp
	if lastTime == nil then
		lastTime = 0
	end
	
	--checking if missing
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusUpdate then
		--sending status request
		SendStatusRequest(sensorId)
	end
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusTimeout then
		--marking as missing
		missing = true
	end
	
	if missing then 
		monitor.setBackgroundColor(colors.orange)
	else
		monitor.setBackgroundColor(T_ctrlTempData[sensorId].state)
	end
	
	local maxX = mSizeX
	if sensor.draw.len ~= nil then
		maxX = xPosition + sensor.draw.len
	end
	
	local sensorText = sensorId
	
	if T_ctrlTempData[sensorId].state == colors.green then
		sensorText = sensor.guiNameGreen
	elseif T_ctrlTempData[sensorId].state == colors.red then
		sensorText = sensor.guiNameRed
	end
	
	if guiMode == "MODE_VERSION" then 
		sensorText = T_ctrlTempData[sensorId].version
	elseif guiMode == "MODE_OVERRIDE" then
		sensorText = tostring(T_ctrlTempData[sensorId].override)
	end
	
	sensorText = tostring(sensorText)
	
	for i = xPosition, maxX do
		local letterPos = i + 1 - xPosition
		if letterPos <= string.len(sensorText) then
			monitor.write(string.sub(sensorText, letterPos, letterPos))
		else
			monitor.write(" ")
		end
		
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end
		T_guiXy[i][yPosition] = guiDataId
	end

end


function DrawWidgetSensorBar(guiDataId)
	local bar = sdata.guiData[guiDataId]
	if bar.draw.xPos == nil or bar.draw.yPos == nil then
		PrintDbg("DrawWidgetSensorBar() data missing", 2)
		return
	end
	monitor.setCursorPos(bar.draw.xPos, bar.draw.yPos)
	monitor.setTextColor(sdata.settings.guiTextColor)
	local curTime = os.time()
	
	for index=1, #bar.controllerIds do
		local sensorId = bar.controllerIds[index]
		if sensorId == nil then
			PrintDbg("DrawWidgetSensorBar() sensorId missing", 2)
			return
		end
		local missing = false
	
		if T_ctrlTempData[sensorId] == nil then
			T_ctrlTempData[sensorId] = { state = colors.orange, lastResp = 0 }
		end
	
		local lastTime = T_ctrlTempData[sensorId].lastResp
		if lastTime == nil then
			lastTime = 0
		end
	
		--checking if missing
		if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusUpdate then
			--sending status request
			SendStatusRequest(sensorId)
		end
		if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusTimeout then
			--marking as missing
			missing = true
		end
	
		if missing then 
			monitor.setBackgroundColor(colors.orange)
		else
			monitor.setBackgroundColor(T_ctrlTempData[sensorId].state)
		end
	
		local len = 1
		if bar.draw.lenMultiplier ~= nil then
			len = bar.draw.lenMultiplier
		end
	
		monitor.setTextColor(sdata.settings.guiTextColor)
		for i = bar.draw.xPos + (index - 1)*len, bar.draw.xPos + index*len - 1 do
			monitor.write(" ")
		
			if T_guiXy[i] == nil then
				T_guiXy[i] = {}
			end
			T_guiXy[i][bar.draw.yPos] = guiDataId
		end
	end
end


function DrawWidgetGuiModeSwitch(guiDataId)
	local widget = sdata.guiData[guiDataId]
	if widget.draw.len == nil or widget.draw.yPos == nil or widget.guiName == nil then
		PrintDbg("DrawWidgetGuiModeSwitch() data missing", 2)
		return
	end
	xPosition = 1
	if widget.draw.xPos == nil then
		xPosition = mSizeX - widget.draw.len
	else
		xPosition = widget.draw.xPos
	end
	monitor.setCursorPos(xPosition, widget.draw.yPos)
	monitor.setTextColor(sdata.settings.guiBgColor)
--	PrintDbg("DrawWidgetGuiModeSwitch(): "..tostring(guiDataId)..", cur mode:"..tostring(guiMode).."wid mode:"..tostring(sdata.guiData[guiDataId].guiMode), 0)
	if guiMode == sdata.guiData[guiDataId].guiMode then
		monitor.setBackgroundColor(colors.cyan)
	else
		monitor.setBackgroundColor(colors.lightBlue)
	end
	for i = xPosition, xPosition + widget.draw.len do
		local letterPos = i + 1 - xPosition
		if letterPos <= string.len(widget.guiName) then
			monitor.write(string.sub(widget.guiName, letterPos, letterPos))
		else
			monitor.write(" ")
		end
		
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end
		T_guiXy[i][widget.draw.yPos] = guiDataId
	end
end


--draws data for primary emitters. Displays r, theta, phi if there is a selected target or its widget text if none is selected.
--first symbol background displays state of the controller(red/green/orange), other symbols - the ability to emit beam in the direction of the target selected (red/green)
function DrawWidgetLaserEm(guiDataId)
	PrintDbg("Entering DrawWidgetLaserEm()", 1)
	local widget = sdata.guiData[guiDataId]
	if widget.draw.xPos == nil or widget.draw.yPos == nil or widget.rPGuiId == nil then
		PrintDbg("DrawWidgetLaserEm() data missing", 1)
		return
	end
	local yPosition = tonumber(widget.draw.yPos)
	local xPosition = tonumber(widget.draw.xPos)
	monitor.setCursorPos(xPosition, yPosition)
	monitor.setTextColor(sdata.settings.guiTextColor)
	
	local widgetText = guiDataId
	if widget.guiName ~= nil and widget.guiName ~= "" then
		widgetText = widget.guiName
	end
	
	local curTime = os.time()
	
	local controllerId = widget.controllerIds[1]
	if controllerId == nil then
		PrintDbg("DrawWidgetLaserEm() sensorId missing", 1)
		return
	end
	
	if T_ctrlTempData[controllerId] == nil then
		PrintDbg("DrawWidgetLaserEm() T_ctrlTempData missing", 1)
		T_ctrlTempData[controllerId] = {}
		T_ctrlTempData[controllerId].state = colors.orange
		T_ctrlTempData[controllerId].lastResp = 0 
		return
	end
	
	if T_ctrlTempData[controllerId].pos == nil then
		PrintDbg("DrawWidgetReferencePoint() 'pos' result missing", 1)
		T_ctrlTempData[controllerId].pos = {}
		SendPosRequest(controllerId)
		return
	end
	local missing = false
	
	local lastTime = T_ctrlTempData[controllerId].lastResp
	if lastTime == nil then
		lastTime = 0
	end
		
	--checking if missing
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusUpdate then
		--sending status request
		PrintDbg("DrawWidgetLaserEm(): status req", 1)
		SendPosRequest(controllerId)
	end
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusTimeout then
		--marking as missing
		missing = true
	end
	
	if missing then 
		monitor.setBackgroundColor(colors.orange)
	else
		monitor.setBackgroundColor(T_ctrlTempData[controllerId].state)
	end
	
	--emitter coordinates
	if T_ctrlTempData[controllerId].pos[1] == nil or T_ctrlTempData[controllerId].pos[2] == nil or T_ctrlTempData[controllerId].pos[3] == nil then
		PrintDbg("DrawWidgetLaserEm() 'pos' result is nil", 1)
		SendPosRequest(controllerId)
		return
	end
	
	gx = tonumber(T_ctrlTempData[controllerId].pos[1])
	gy = tonumber(T_ctrlTempData[controllerId].pos[2])
	gz = tonumber(T_ctrlTempData[controllerId].pos[3])

	if guiMode == "MODE_VERSION" then
		widgetText = tostring(T_ctrlTempData[controllerId].version)
	elseif guiMode == "MODE_GFOR" then
		widgetText = tostring(gx)..";"..tostring(gy)..";"..tostring(gz)..";"
	end
	
	--target vector
	local tx, ty, tz = nil, nil, nil
	local selected = T_guiTempData[widget.tTGuiId].selected
	if selected ~= nil and T_guiTempData[widget.tTGuiId].targetList~= nil and T_guiTempData[widget.tTGuiId].targetList[selected]~= nil then
		tx = tonumber(T_guiTempData[widget.tTGuiId].targetList[selected].x) - gx
		ty = tonumber(T_guiTempData[widget.tTGuiId].targetList[selected].y) - gy
		tz = tonumber(T_guiTempData[widget.tTGuiId].targetList[selected].z) - gz
	end
	
	local r, t, p = CartesianToPolar(tx, ty, tz)

	local canFire = false

	if T_guiTempData[widget.eBGuId] == nil then 
		T_guiTempData[widget.eBGuId] = {}
	end
	
	if r ~= nil or t~=nil or p ~= nil then
		t = math.deg(t)
		p = math.deg(p)
		PrintDbg(tostring(r)..";"..tostring(t)..";"..tostring(p), 1)
		
		local allowed = sdata.ctrlData[controllerId].allowed
		--allowed = { { { t, t }, {p, p} }, { { t, t }, {p, p} } }
		
		for i=1, table.getn(allowed) do
			if t >= allowed[i][1][1] and t<= allowed[i][1][2] then
				PrintDbg(tostring(t).." between "..tostring(allowed[i][1][1])..";"..tostring(allowed[i][1][2]), 2)
				if t == 0 or t == 180 then	--gimbal lock workaround
					canFire = true
				else
					if p >= allowed[i][2][1] and p<= allowed[i][2][2] then
						PrintDbg(tostring(t).." between "..tostring(allowed[i][2][1])..";"..tostring(allowed[i][2][2]), 2)
						canFire = true
					end
				end
			end
		end
		
		widgetText = string.format("%.1f;%.1f;%.1f", r, t, p)		

		if canFire and T_ctrlTempData[controllerId].state == colors.green then
			--create a packet to send when FIRE button is pressed
			local packetT = 
			{
				target = controllerId,
				command = "PEXECUTE",
				pCommand = "emitBeam",
				p1 = tx,
				p2 = ty,
				p3 = - tz, --AZAZA CROS CANNOT INTO TRANSFORMATIONS WORKAROUND
				delay = sdata.settings.laserDelay
			}
			
			--packets for secondary lasers
			local secondary = sdata.ctrlData[controllerId].secondary
			for i=1, table.getn(secondary) do
				--emitter coordinates
				skipEmitter = false

				if T_ctrlTempData[secondary[i]] == nil then
					T_ctrlTempData[secondary[i]] = {}
					SendPosRequest(controllerId)
					skipEmitter = true
				end

				if T_ctrlTempData[secondary[i]].pos == nil then
					PrintDbg("DrawWidgetLaserEm() 'pos' result missing for "..tostring(secondary[i]), 1)
					T_ctrlTempData[secondary[i]].pos = {}
					SendPosRequest(secondary[i])
					skipEmitter = true
				end
				if T_ctrlTempData[secondary[i]].pos[1] == nil or T_ctrlTempData[secondary[i]].pos[2] == nil or T_ctrlTempData[secondary[i]].pos[3] == nil then
					PrintDbg("DrawWidgetLaserEm() 'pos' result is nil for "..tostring(secondary[i]), 1)
					SendPosRequest(secondary[i])
					skipEmitter = true
				end
				if skipEmitter == false then
					sgx = tonumber(T_ctrlTempData[secondary[i]].pos[1])
					sgy = tonumber(T_ctrlTempData[secondary[i]].pos[2])
					sgz = tonumber(T_ctrlTempData[secondary[i]].pos[3])

					local sPacketT = 
					{
						target = secondary[i],
						command = "PEXECUTE",
						pCommand = "emitBeam",
						p1 = gx - sgx,
						p2 = gy - sgy,
						p3 = - gz + sgz, --AZAZA CROS CANNOT INTO TRANSFORMATIONS WORKAROUND
					}
					T_guiTempData[widget.eBGuId][secondary[i]] = textutils.serialize(sPacketT)
				end
			end
			
			T_guiTempData[widget.eBGuId][controllerId] = textutils.serialize(packetT)
		else
			T_guiTempData[widget.eBGuId][controllerId] = nil
		end
	else
		T_guiTempData[widget.eBGuId][controllerId] = nil
	end
		
	
	for i = xPosition, xPosition + widget.draw.len do
		local letterPos = i + 1 - xPosition
		if letterPos > 3 then
			if canFire then
				monitor.setBackgroundColor(colors.green)
			else
				monitor.setBackgroundColor(colors.red)
			end
		end
		if letterPos <= string.len(widgetText) then
			monitor.write(string.sub(widgetText, letterPos, letterPos))
		else
			monitor.write(" ")
		end
		
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end
		T_guiXy[i][yPosition] = guiDataId
	end
end


function DrawWidgetTargetTable(guiDataId) 
	local widget = sdata.guiData[guiDataId]
	if widget.draw.xPos == nil or widget.draw.yPos == nil then
		PrintDbg("DrawWidgetLaserTargetTable() data missing", 2)
		return
	end
	
	if T_guiTempData[guiDataId] == nil then
		T_guiTempData[guiDataId] = {}
	end
	
	if T_guiTempData[guiDataId].targetList == nil then
		PrintDbg("DrawWidgetLaserTargetTable(): Resuming from file...", 1)
		T_guiTempData[guiDataId].targetList = {}
		T_guiTempData[guiDataId].targetList = ReadResume(T_guiTempData[guiDataId].targetList, "ldata")
	end
	
	
	local yPosition = tonumber(widget.draw.yPos)
	local xPosition = tonumber(widget.draw.xPos)

	local maxX = xPosition + widget.draw.len
	if maxX > mSizeX then
		maxX = mSizeX
	end
	local maxY = mSizeY			--to the bottom of the screen
	
	--converting to LFOR
	local originX, originY, originZ = 0.0, 0.0, 0.0
	if guiMode == "MODE_LFOR" then
		if T_guiTempData[widget.rPGuiId]~= nil and T_guiTempData[widget.rPGuiId].origin ~= nil then
			originX, originY, originZ = T_guiTempData[widget.rPGuiId].origin.x, T_guiTempData[widget.rPGuiId].origin.y, T_guiTempData[widget.rPGuiId].origin.z
		end
	end
		
	--lines from last to first
	for iy = yPosition, maxY - 1 do
		local index = table.getn(T_guiTempData[guiDataId].targetList) + yPosition - iy

		monitor.setBackgroundColor(colors.lightGray)
		monitor.setTextColor(sdata.settings.guiTextColor)

		if T_guiTempData[guiDataId].selected ~= nil then
			if index == T_guiTempData[guiDataId].selected then
				monitor.setBackgroundColor(colors.gray)
			end
		end
		
		local textLine = ""
		if index > 0 then
			local tx = tonumber(T_guiTempData[guiDataId].targetList[index].x) - originX
			local ty = tonumber(T_guiTempData[guiDataId].targetList[index].y) - originY
			local tz = tonumber(T_guiTempData[guiDataId].targetList[index].z) - originZ
			
			textLine = tostring(tx)..";"..tostring(ty)..";"..tostring(tz)..";"..tostring(T_guiTempData[guiDataId].targetList[index].comment)
		else
			textLine = "-"
		end
		
		for ix = xPosition, maxX do 
			local letterPos = ix + 1 - xPosition
			monitor.setCursorPos(ix, iy)
			if letterPos <= string.len(textLine) then
				monitor.write(string.sub(textLine, letterPos, letterPos))
			else
				monitor.write(" ")
			end
		
			if T_guiXy[ix] == nil then
				T_guiXy[ix] = {}
			end
			T_guiXy[ix][iy] = guiDataId
		end
	end
	
	--buttons
	monitor.setCursorPos(xPosition, maxY)
	monitor.setBackgroundColor(colors.green)
	monitor.setTextColor(sdata.settings.guiBgColor)
	monitor.write(" ADD ") --x 1 to 5
	monitor.setBackgroundColor(sdata.settings.guiBgColor)
	monitor.write(" ") --x 6
	monitor.setBackgroundColor(colors.red)
	monitor.write("-") --x 7
	monitor.setBackgroundColor(sdata.settings.guiBgColor)
	monitor.write(" ") --x 8
	monitor.setBackgroundColor(colors.green)
	monitor.setTextColor(sdata.settings.guiBgColor)
	monitor.write(" SAVE ") --x 9 to 14
	for ix = xPosition, maxX do 
		T_guiXy[ix][maxY] = guiDataId
	end
end


--reference point: global or local coordinates of a ship's origin obtained from a dedicated (or not) laser emitter controller
function DrawWidgetReferencePoint(guiDataId)
	local widget = sdata.guiData[guiDataId]
	if widget.draw.xPos == nil or widget.draw.yPos == nil then
		PrintDbg("DrawWidgetReferencePoint() data missing", 1)
		return
	end
	local yPosition = tonumber(widget.draw.yPos)
	local xPosition = tonumber(widget.draw.xPos)
	
	monitor.setCursorPos(xPosition, yPosition)
	monitor.setTextColor(sdata.settings.guiTextColor)
	
	--controller check
	local curTime = os.time()
	local controllerId = widget.controllerIds[1]
	if controllerId == nil then
		PrintDbg("DrawWidgetReferencePoint() controllerId missing", 1)
		return
	end
	
	local lx, ly, lz = sdata.ctrlData[controllerId].lx, sdata.ctrlData[controllerId].ly, sdata.ctrlData[controllerId].lz
	if lx == nil or ly == nil or lz == nil then
		PrintDbg("DrawWidgetReferencePoint() local coordinate data missing", 1)
		return
	end

	
	local missing = false
	
	if T_ctrlTempData[controllerId] == nil then
		T_ctrlTempData[controllerId] = { state = colors.orange, lastResp = 0 }
	end
	
	local lastTime = T_ctrlTempData[controllerId].lastResp
	if lastTime == nil then
		lastTime = 0
	end
	
	--checking if missing
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusUpdate then
		--sending status request
		PrintDbg("DrawWidgetReferencePoint(): status req", 1)
		SendPosRequest(controllerId)
	end
	if KiloTicksPassed(lastTime, curTime) > sdata.settings.statusTimeout then
		--marking as missing
		missing = true
	end
	
	if missing then 
		monitor.setBackgroundColor(colors.orange)
	else
		monitor.setBackgroundColor(sdata.settings.guiBgColor)
	end
	
	if T_ctrlTempData[controllerId].pos == nil then
		PrintDbg("DrawWidgetReferencePoint() 'pos' result missing", 1)
		T_ctrlTempData[controllerId].pos = {}
		SendPosRequest(controllerId)
	end
	
	local widgetText = ""
	
	if T_ctrlTempData[controllerId].pos[1] == nil or T_ctrlTempData[controllerId].pos[2] == nil or T_ctrlTempData[controllerId].pos[3] == nil then
		PrintDbg("DrawWidgetReferencePoint() 'pos' result is nil", 1)
		SendPosRequest(controllerId)
		return
	end
	
	if T_guiTempData[guiDataId] == nil then
		T_guiTempData[guiDataId] = {}
	end
	
	if T_guiTempData[guiDataId].origin == nil then
		T_guiTempData[guiDataId].origin = {}
	end
	
	T_guiTempData[guiDataId].origin.x = tonumber(T_ctrlTempData[controllerId].pos[1]) - lx
	T_guiTempData[guiDataId].origin.y = tonumber(T_ctrlTempData[controllerId].pos[2]) - ly
	T_guiTempData[guiDataId].origin.z = tonumber(T_ctrlTempData[controllerId].pos[3]) - lz
	
	if guiMode == "MODE_VERSION" then
		widgetText = tostring(T_ctrlTempData[controllerId].version)
	elseif guiMode == "MODE_OVERRIDE" then
		widgetText = tostring(T_ctrlTempData[controllerId].override)
	elseif guiMode == "MODE_GFOR" then
		widgetText = tostring(T_guiTempData[guiDataId].origin.x)..";"..tostring(T_guiTempData[guiDataId].origin.y)..";"..tostring(T_guiTempData[guiDataId].origin.z)
	
		if widget.draw.len < string.len(widgetText) then
			widgetText = string.sub(tostring(T_guiTempData[guiDataId].origin.x),-3)..";"..string.sub(tostring(T_guiTempData[guiDataId].origin.y),-3)..";"..string.sub(tostring(T_guiTempData[guiDataId].origin.z),-3)
		end
	elseif guiMode == "MODE_LFOR" then
		
		widgetText = tostring(lx)..";"..tostring(ly)..";"..tostring(lz)
	
		if widget.draw.len < string.len(widgetText) then
			widgetText = string.sub(tostring(lx),-3)..";"..string.sub(tostring(ly),-3)..";"..string.sub(tostring(lz),-3)
		end
	end
	
	for i = xPosition, xPosition + widget.draw.len do 
		local letterPos = i + 1 - xPosition
		if letterPos <= string.len(widgetText) then
			monitor.write(string.sub(widgetText, letterPos, letterPos))
		else
			monitor.write(" ")
		end
		
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end
		T_guiXy[i][yPosition] = guiDataId
	end
end


function DrawWidgetEngageButton(guiDataId)
	local widget = sdata.guiData[guiDataId]
	if widget.draw.len == nil or widget.draw.yPos == nil or widget.guiName == nil then
		PrintDbg("DrawWidgetEngageButton() data missing", 2)
		return
	end
	xPosition = 1
	if widget.draw.xPos == nil then
		xPosition = mSizeX - widget.draw.len
	else
		xPosition = widget.draw.xPos
	end
	monitor.setCursorPos(xPosition, widget.draw.yPos)
	monitor.setTextColor(sdata.settings.guiBgColor)
	monitor.setBackgroundColor(colors.red)
	
	for i = xPosition, xPosition + widget.draw.len do
		local letterPos = i + 1 - xPosition
		monitor.setCursorPos(i, widget.draw.yPos)
		monitor.write(" ")
		monitor.setCursorPos(i, widget.draw.yPos+1)
		if letterPos <= string.len(widget.guiName) then
			monitor.write(string.sub(widget.guiName, letterPos, letterPos))
		else
			monitor.write(" ")
		end
		monitor.setCursorPos(i, widget.draw.yPos+2)
		monitor.write(" ")
		
		if T_guiXy[i] == nil then
			T_guiXy[i] = {}
		end
		T_guiXy[i][widget.draw.yPos] = guiDataId
		T_guiXy[i][widget.draw.yPos+1] = guiDataId
		T_guiXy[i][widget.draw.yPos+2] = guiDataId
	end
end


---------------------------------------------------------------------------------------------------
-------------------			WIDGET CLICKING
---------------------------------------------------------------------------------------------------

function ProcessClick(cx, cy)
	PrintDbg("Click at "..tostring(cx).." "..tostring(cy), 2)
	if T_guiXy[cx] == nil then
		PrintDbg("No controls an x = "..cx, 2)
		os.queueEvent("redraw")
		return
	else
		if T_guiXy[cx][cy] == nil then
			PrintDbg("No controls an x = "..cx.." y = "..cy, 2)
			os.queueEvent("redraw")
			return
		else
			--success
			local guiDataId = T_guiXy[cx][cy]
			if sdata.guiData[guiDataId] == nil then
				PrintDbg("GUI ID "..guiDataId.." not found", 2)
			else
				local guiType = sdata.guiData[guiDataId].guiType
				if guiType == "SWITCH" then
					ClickWidgetSwitch(guiDataId)
				elseif guiType == "LABEL" or guiType == "SENSOR" or guiType == "ENER_BARS" then
					DrawAll()
				elseif guiType == "LASER_EM" then
					ClickWidgetLaserEm(guiDataId)
				elseif guiType == "GUI_MODE_SWITCH" then
					ClickWidgetGuiModeSwitch(guiDataId)
				elseif guiType == "TARGET_TABLE" then
					ClickWidgetTargetTable(guiDataId, cx, cy)
				elseif guiType == "REFERENCE_POINT" then
					ClickWidgetReferencePoint(guiDataId)
				elseif guiType == "ENGAGE_BUTTON" then
					ClickWidgetEngageButton(guiDataId)
				else
					PrintDbg("GUI ID "..guiDataId..": unknown type", 2)
				end
			end
		end
	end
end


--for simple on/off controllers, which state is depicted by color string, only first controllerId is used
function ClickWidgetSwitch(guiDataId)
	local controller_id = sdata.guiData[guiDataId].controllerIds[1]
	if T_ctrlTempData[controller_id] == nil then
		PrintDbg("No temp data for controller_id "..controller_id, 2)
		return
	end
	
	local packetT = 
	{
		target = controller_id
	}
	
	if guiMode == "MODE_UPDATE" then
		packetT.command = "UPDATE"
	elseif guiMode == "MODE_OVERRIDE" then
		if T_ctrlTempData[controller_id].override == false then
			packetT.command = "OVERRIDE"		
		else
			packetT.command = "OVERRIDE OFF"
		end
	else
		packetT.command = "SET STATE"
		if T_ctrlTempData[controller_id].state == colors.red then
			packetT.state = colors.green
		else 
			packetT.state = colors.red
		end
		PrintDbg("sending SET STATE to "..controller_id, 2)
	end
		
	local packet = textutils.serialize(packetT)
	modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, packet)
end


--for simple on/off controllers, which state is depicted by color string, only first controllerId is used
function ClickControllerAirgenAll(guiDataId)
	local controller_id = sdata.guiData[guiDataId].controllerIds[1]
	if T_ctrlTempData[controller_id] == nil then
		PrintDbg("No temp data for controller_id "..controller_id, 2)
		return
	end
	
	local packetT = 
	{
		target = "AIRGEN",
		command = "SET STATE",
		state = colors.green
	}
	
	PrintDbg("sending SET STATE GREEN to all AIRGENS", 2)
	local packet = textutils.serialize(packetT)
	modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, packet)
end


function ClickWidgetGuiModeSwitch(guiDataId)
	if guiMode ~= sdata.guiData[guiDataId].guiMode then
		guiMode = sdata.guiData[guiDataId].guiMode
		os.queueEvent("redraw")
	else
		guiMode = "MODE_DEFAULT"
		os.queueEvent("redraw")
	end
end


function ClickWidgetLaserEm(guiDataId)
	local controller_id = sdata.guiData[guiDataId].controllerIds[1]
	if T_ctrlTempData[controller_id] == nil then
		PrintDbg("No temp data for controller_id "..controller_id, 2)
		return
	end
	
	--TODO toggle state
	local packetT = 
	{
		target = controller_id
	}
	
	if guiMode == "MODE_UPDATE" then
		packetT.command = "UPDATE"
	elseif guiMode == "MODE_OVERRIDE" then
		if T_ctrlTempData[controller_id].override == false then
			packetT.command = "OVERRIDE"		
		else
			packetT.command = "OVERRIDE OFF"
		end
	else
		packetT.command = "SET STATE"
		if T_ctrlTempData[controller_id].state == colors.red then
			packetT.state = colors.green
		else 
			packetT.state = colors.red
		end
		PrintDbg("sending SET STATE to "..controller_id, 2)
	end
		
	local packet = textutils.serialize(packetT)
	modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, packet)
end


function ClickWidgetTargetTable(guiDataId, cX, cY)
	if T_guiTempData[guiDataId] == nil then
		PrintDbg("No temp data for controller_id "..controller_id, 2)
		return
	end
	local length = table.getn(T_guiTempData[guiDataId].targetList)
	local widget = sdata.guiData[guiDataId]
	local yPosition = tonumber(widget.draw.yPos)
	local xPosition = tonumber(widget.draw.xPos)
	if cY == mSizeY then
		--buttons
		if cX >= xPosition and cX < xPosition + 5 then
			--add
			print("Coordinates: x;y;z;comment")
			local inputString = tostring(read())
			local cmt = ""
			local smcln = string.find(inputString, ";", 1, true)
			if smcln == nil then
				print("failed!")
				return
			end
			local tX = tonumber(string.sub(inputString,1,smcln-1))
			inputString = string.sub(inputString,smcln+1)
			smcln = string.find(inputString.."", ";", 1, true)
			if smcln == nil then
				print("failed!")
				return
			end
			local tY = tonumber(string.sub(inputString,1,smcln-1))
			inputString = string.sub(inputString,smcln+1)
			smcln = string.find(inputString.."", ";", 1, true)
			local tZ = 0;
			if smcln == nil then
				tZ = tonumber(inputString)
			else
				tZ = tonumber(string.sub(inputString,1,smcln-1))
				cmt = string.sub(inputString,smcln+1)				
			end
			table.insert(T_guiTempData[guiDataId].targetList, {x = tX, y = tY, z = tZ, comment = cmt})
			
			os.queueEvent("redraw")
			return
			
		elseif cX == xPosition + 6 then
			--minus
			if T_guiTempData[guiDataId].selected ~= nil then
				table.remove(T_guiTempData[guiDataId].targetList, tonumber(T_guiTempData[guiDataId].selected))
			end
			
			os.queueEvent("redraw")
			return
			
		elseif cX >= xPosition + 8 and cX < xPosition + 14 then
			--TODO save to file
			WriteResume(T_guiTempData[guiDataId].targetList, "ldata")
			
			return
		end
	else 
		T_guiTempData[guiDataId].selected = tonumber(length - cY + yPosition)
		if T_guiTempData[guiDataId].selected < 1 then
			T_guiTempData[guiDataId].selected = nil
		end
		
		os.queueEvent("redraw")
	end
	
	
end


--tries to update its global coordinates
function ClickWidgetReferencePoint(guiDataId)
	local controller_id = sdata.guiData[guiDataId].controllerIds[1]
	if T_ctrlTempData[controller_id] == nil then
		PrintDbg("No temp data for controller_id "..controller_id, 2)
		return
	end
	
	local packetT = 
	{
		target = controller_id
	}
	
	if guiMode == "MODE_UPDATE" then
		packetT.command = "UPDATE"
		local packet = textutils.serialize(packetT)
		modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, packet)
	elseif guiMode == "MODE_OVERRIDE" then
		if T_ctrlTempData[controller_id].override == false then
			packetT.command = "OVERRIDE"		
		else
			packetT.command = "OVERRIDE OFF"
		end
		local packet = textutils.serialize(packetT)
		modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, packet)
	else 
		SendPosRequest(controller_id)
	end
end

function ClickWidgetEngageButton(guiDataId)
	if T_guiTempData[guiDataId] ~= nil and modem ~= nil then
		for key,value in pairs( T_guiTempData[guiDataId] ) do
			PrintDbg("ClickWidgetEngageButton(): sending to "..tostring(key), 2)
			modem.transmit(sdata.settings.channelSend, sdata.settings.channelReceive, value)
		end
		T_guiTempData[guiDataId] = nil
		os.queueEvent("redraw")
	elseif T_guiTempData[guiDataId] == nil then
		PrintDbg("ClickWidgetEngageButton(): guiDataId is null", 0)
	end
	PrintDbg("ClickWidgetEngageButton(): done", 0)
end



--MAIN BODY should look like this:

Init()

while true do 
	parallel.waitForAny(GuiLoop, ReceiveLoop, RedrawLoop)
end
--MAIN BODY END