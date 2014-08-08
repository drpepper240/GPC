--computercraft
--peripheral controller client by drPepper

-- "THE BEER-WARE LICENSE"
-- drPepper@KOPROKUBACH wrote this file. As long as you retain this notice you
-- can do whatever you want with this stuff. If we meet some day, in-game or IRL,
-- and you think this stuff is worth it, you can give me a beer in return

--How this should be used:
--one controller - one function, computers are cheap. Do not use single computer to control air generators, lighting and doors/airlocks simultaneously
--one zone - one controller. Wire all air generators in a room to a single controller, then call it AGBRIDGE or something
--ID shoud be 3 chars or longer
--ID should not be equal to controller type

VERSION_STRING = "0.79"

--				SUPPORTED TYPES:
T_perTypes = {[1] = "AIRLOCK", [2] = "P_LEM", [3] = "CONTROLLER", [4] = "P_LEC"}
--1	two rs outputs, two monitor sides, no input
--2 
--3 default type
--4 laser emitter and camera - listens on a separate channel and updates data when receives a packet

T_sides = {[1] = "left", [2] = "right", [3] = "front", [4] = "back", [5] = "top", [6] = "bottom"}


--settings
T_data = {}
T_data.settings = {}

--default values, can be changed during installation or by editing "data" file

T_data.modemSide = nil
T_data.channelSend = 210
T_data.channelReceive = 211
T_data.updateUrl = "https://raw.githubusercontent.com/drpepper240/GPC/testing/client.lua"				--url for self-update
T_data.state = colors.green					--default state (states are depicted by colors)
T_data.overridden = false					--override mode
T_data.debugLvl = 1							--debug level
T_data.perSide = nil						--peripheral side
T_data.controllerType = nil					--controller type
T_data.rsis = nil							--RS input side
T_data.rsos = nil							--RS output side
T_data.rsoss = nil							--RS output secondary side
T_data.rssc = colors.red					--redstone signal color code
T_data.displayText = " "					--text to display on display

--default laser frequency
LASER_FREQ=34567
--attempts to wrap peripheral
WRAP_ATTEMPTS = 5
--savedata filename
TDATA_FILENAME = "data"

modem = nil
label = nil

--P_LEM and everything which can obtain its own coordinates
--assuming coordinates can't change without client restart
gx, gy, gz = nil, nil, nil

--P_LEC last result of getFirstHit()
hitX, hitY, hitZ, hitId, hitMeta, hitRes = nil, nil, nil, nil, nil



--debug messages
function PrintDbg(message, level)
	if level == nil then
		level = 2
	end
	if (level <= T_data.debugLvl) then
		print("D:"..message)
	end
end


--serializes given table to a file using given or default name (if no given)
function WriteResume()
	PrintDbg("entering WriteResume()", 2)
	local file = fs.open(TDATA_FILENAME,"w")
	local sT = textutils.serialize(T_data)
	file.write(sT)
	file.close()
	return
end


function ReadResume()
	PrintDbg("entering ReadResume()", 2)
	if not fs.exists(TDATA_FILENAME) then
		PrintDbg("Trying to resume without resume file", 1)
		sleep(1)
		SettingsDialogue()
		os.reboot()
	end
	local file = fs.open(TDATA_FILENAME,"r")
	local sT = file.readAll()
	T_data = textutils.unserialize(sT)
	file.close()
    return
end


function Download(url)
    write( "Connecting... " )
    local response = http.get( url )
        
    if response then
        print( "Success." )
        
        local sResponse = response.readAll()
        response.close()
        return sResponse
    else
        printError( "Failed." )
    end
end


function Get(url, fileName)
    -- Determine file to download
    local sPath = shell.resolve( fileName )
    if fs.exists( sPath ) then
        print( "File already exists" )
        return
    end
    
    -- GET the contents from github
    local res = Download(url)
    if res then        
        local file = fs.open( sPath, "w" )
        file.write( res )
        file.close()
        
        print( "Downloaded as "..fileName )
    end
end


function GetSideFromUser(peripheralName)
	PrintDbg("entering GetSideFromUser()", 2)
	--listing all available sides
	for i=1, #T_sides do
		write(tostring(i).." "..tostring(T_sides[i]).."\n")
	end
	print("a - autodetect")
	input = read()
	if tostring(input) == "a" and peripheralName ~= nil then
		--autodetect
		input = DetectPeripheral(peripheralName)
	end
	if tonumber(input) == nil then
		return nil
	else
		return tostring(T_sides[tonumber(input)])
	end
end


function DetectPeripheral(name)  
	for i = 1, 6 do
		if peripheral.isPresent(T_sides[i]) and peripheral.getType(T_sides[i]) == name then
			print("found "..tostring(name)..": "..tostring(T_sides[i]))
			return i
		else
			PrintDbg("not found "..tostring(name)..": "..tostring(T_sides[i]),2)
		end
	end
	return nil
end


--console dialogue to set all settings
function SettingsDialogue()
	term.clear()
	term.setCursorPos(1,1)

	print("Controller type(enter to abort):")
	--listing all available types
	for i=1, #T_perTypes do
		write(tostring(i).." - "..tostring(T_perTypes[i])..", ")
	end
	
	print("")
	local typeString = tostring(T_perTypes[tonumber(read())])
	
	if string.len(typeString) < 1 then
		print("Aborting...")
		sleep(2)
		os.reboot()
	else
		T_data.controllerType = typeString
	end

	--generic settings
	print("Modem side (enter to skip):")
	T_data.modemSide = GetSideFromUser("modem")
	PrintDbg("modemSide: "..tostring(T_data.modemSide),2)
	
	--type-dependent settings TODO	
	if string.sub(typeString, 1, 2) == "P_" then
		--PERIPHERAL
		print("Peripheral side (enter to skip):")
		T_data.perSide = GetSideFromUser()
		
		if string.sub(typeString, 1, 4) == "P_LE" then
			--Lasers
			T_data.laserFreq = LASER_FREQ
			if string.sub(typeString, 1, 5) == "P_LEC" then
				--with camera
				print("Camera frequency:")
				T_data.camFreq = tonumber(read())
				if T_data.camFreq < 1 or T_data.camFreq > 65000 then
					T_data.camFreq = nil
					print("Invalid frequency, changing to P_LEM")
					T_data.controllerType = "P_LEM"
				end
				
				T_data.laserFreq = 1420

				print("Network timer channel:")
				T_data.networkTimerChannel = tonumber(read())
				if T_data.networkTimerChannel < 1 or T_data.networkTimerChannel >= 65535 or T_data.networkTimerChannel == T_data.channelReceive then
					print("Invalid channel")
					T_data.networkTimerChannel = nil
				end
			end
		end
	else
		--NOT PERIPHERAL
		print("Monitor side (enter to skip):")
		T_data.monitorSide = GetSideFromUser("monitor")
		
		print("Redstone input side (enter to skip):")
		T_data.rsis = GetSideFromUser()
		
		print("Redstone output side (enter to skip):")
		T_data.rsos = GetSideFromUser()
		
		print("Display text (enter to skip):")
		T_data.displayText = tostring(read())
		if string.len(T_data.displayText) < 1 then T_data.displayText = "" end
		
		if string.sub(typeString, 1, 7) == "AIRLOCK" then
			--AIRLOCK
			print("Secondary monitor side (enter to skip):")
			T_data.monitorSideSecondary = GetSideFromUser()
			
			print("Secondary redstone output side (enter to skip):")
			T_data.rsoss = GetSideFromUser()
		else
			--NOT AIRLOCK
		end
		
		--sets rsoutput to true after going to state depicted by this color
		print("Redstone signal color: green instead of red? (y/n):")
		local answer = tostring(read())
		if answer == "y" then 
			T_data.rssc = colors.green
		elseif answer == "n" then
			T_data.rssc = colors.red
		else 
			T_data.rssc = colors.red
		end
	end

	print("Controller ID (enter to abort):")
	local idString = tostring(read())
	if string.len(idString) < 3 then
		print("Aborting...")
		sleep(2)
		os.reboot()
	else
		os.setComputerLabel(idString)
		WriteResume()
		return
	end
end


function openChannel(modem, n)
	PrintDbg("entering openChannel()", 2)
	if modem == nil then
		PrintDbg("Can't open: no modem present", 0)
		return
	end
	modem.open(n)
	while modem.isOpen(n)== false do
		PrintDbg("opening channel "..tostring(n).."...\n", 1)
		sleep(1)
		modem.open(n)
	end
end


function UpdateState()
	local reportNeeded = false
	
	--Redstone input
	if T_data.rsis == nil then
		PrintDbg("No RS input side", 2)
	else
		local signal = rs.getInput(T_data.rsis)
		if signal ~= ( T_data.rssc == T_data.state ) then
			if T_data.state == colors.green then
				T_data.state = colors.red
			elseif T_data.state == colors.red then
				T_data.state = colors.green
			end
			WriteResume()
			reportNeeded = true
		end
	end
	
	--Redstone output
	if T_data.rsos == nil then
		PrintDbg("No RS output side", 2)
	else 
		rs.setOutput(T_data.rsos, T_data.rssc == T_data.state)
		if T_data.rsoss ~= nil then
			rs.setOutput(T_data.rsoss, T_data.rssc == T_data.state)
		end
		reportNeeded = true
		WriteResume()
	end
	
	--Monitor output
	if monitor ~= nil then
		monitor.setBackgroundColor(T_data.state)
		monitor.clear()
		monitor.setTextColor(colors.black)
		monitor.setCursorPos(1,3)
		monitor.write(T_data.displayText)
	end
	
	--Secondary onitor output
	if monitorSecondary ~= nil then
		monitorSecondary.setBackgroundColor(T_data.state)
		monitorSecondary.clear()
		monitorSecondary.setTextColor(colors.black)
		monitorSecondary.setCursorPos(1,3)
		monitorSecondary.write(T_data.displayText)
	end
	SendReportPacket()
end


function UpdateStateTimer()
	--local reportNeeded = false
	PrintDbg("entering UpdateStateTimer()", 2)
	if string.sub(T_data.controllerType, 1, 5) == "P_LEC" then
		if T_data.perSide == nil then
			PrintDbg("UpdateState(): peripheral not found", 1)
			return
		end
		PrintDbg("UpdateStateTimer() ok1", 2)
		--hitX, hitY, hitZ, hitId, hitMeta, hitRes
		local hx, hy, hz, hid, hmeta, hres = peripheral.call(T_data.perSide, "getFirstHit")
		PrintDbg("entering UpdateStateTimer() ok2", 2)
		PrintDbg("Hit:"..tostring(hx).." "..tostring(hy).." "..tostring(hz).." ", 2)
		if hx ~= 0 and hy ~=0 and hz~=0 and hid ~=0 then
			--we hit something
			PrintDbg("Got hit!", 2)
			if hx ~= hitX or hy ~= hitY or hz ~= hitZ or hid ~= hitId or hres ~= hitRes then
				--we hit something different
				PrintDbg("Got unique hit!", 1)
				hitX, hitY, hitZ, hitId, hitMeta, hitRes = hx, hy, hz, hid, hmeta, hres
				--sending report about it
				local packetT = 
				{
					sender = label,
					controllerType = T_data.controllerType,
					state = T_data.state,
					version = VERSION_STRING,
					override = T_data.overridden,
					hitX = hitX,
					hitY = hitY,
					hitZ = hitZ,
					hitId = hitId,
					hitMeta = hitMeta,
					hitRes = hitRes
				}
				SendPacket(packetT)
			end
		end
	end
	PrintDbg("exiting UpdateStateTimer()", 2)
end


function SendReportPacket()
	PrintDbg("entering SendReportPacket()", 2)
	local packetT = 
	{
		sender = label,
		controllerType = T_data.controllerType,
		state = T_data.state,
		version = VERSION_STRING,
		override = T_data.overridden
	}
	if string.sub(T_data.controllerType, 1, 4) == "P_LE" then
		pExdCommand = "pos"
		packetT.p1, packetT.p2, packetT.p3 = gx, gy, gz
	end
	SendPacket(packetT)
end


function SendPacket(packetT)
	PrintDbg("entering SendPacket()", 2)
	if modem == nil then
		PrintDbg("Can't send: no modem present", 0)
		return
	end
	local packet = textutils.serialize(packetT)
	modem.transmit(T_data.channelSend, T_data.channelReceive, packet)
end


---------------------------------------------------------------------
--MAIN OPERATION
---------------------------------------------------------------------
print("GPC client by drPepper")
print("Version "..VERSION_STRING)
label = os.getComputerLabel()

if (label == 0) then
	PrintDbg("Assign this controller a unique label", 0)
	return
else
	print("ID: "..tostring(label))
end

ReadResume()
UpdateState()

--modem
local i = 1
modem = peripheral.wrap(T_data.modemSide)
while modem==nil and i < WRAP_ATTEMPTS do
	PrintDbg("wrapping modem...\n", 1)
	sleep(1)
	modem = peripheral.wrap(T_data.modemSide)
	i = i + 1
end

--laser init
if string.sub(T_data.controllerType, 1, 4) == "P_LE" then
	peripheral.call(T_data.perSide, "freq", T_data.laserFreq)
	if string.sub(T_data.controllerType, 1, 5) == "P_LEC" then
		peripheral.call(T_data.perSide, "camFreq", T_data.camFreq)
	end
	gx, gy, gz = peripheral.call(T_data.perSide, "pos")
end

--monitor init
i = 1
if T_data.monitorSide ~= nil then
	monitor = peripheral.wrap(T_data.monitorSide)
	while monitor==nil and i < WRAP_ATTEMPTS do
		PrintDbg("wrapping monitor...\n", 1)
		sleep(1)
		monitor = peripheral.wrap(T_data.monitorSide)
		i = i + 1
	end
end
i = 1
if T_data.monitorSideSecondary ~= nil then
	monitorSecondary = peripheral.wrap(T_data.monitorSideSecondary)
	while monitorSecondary==nil and i < WRAP_ATTEMPTS do
		PrintDbg("wrapping secondary monitor...\n", 1)
		sleep(1)
		monitorSecondary = peripheral.wrap(T_data.monitorSideSecondary)
		i = i + 1
	end
end

UpdateState()

openChannel(modem, T_data.channelReceive)

if T_data.networkTimerChannel ~= nil then
	openChannel(modem, T_data.networkTimerChannel)
end

--main loop
while true do
	local event, p1, p2, p3, p4, p5 = os.pullEvent()
	--key pressed
	if event == "key" then
		PrintDbg("Key pressed: ", 2)
		if p1 == 22 then
			--Update
			shell.run("rm", "startup")
			Get(T_data.updateUrl, "startup")
			os.reboot()
		elseif p1 == 20 and T_data.overridden == false then
			--Toggle
			if T_data.state == colors.green then
				T_data.state = colors.red
			elseif T_data.state == colors.red then
				T_data.state = colors.green
			end
			UpdateState()
		elseif p1 == 41 and T_data.overridden == false then
			--re-set
			fs.delete("data")
			os.reboot()
		end
	elseif event == "modem_message" then
		if p2 == T_data.networkTimerChannel then
			PrintDbg("Network timer message received", 2)
			UpdateStateTimer()
		else
			local packet = textutils.unserialize(p4)
			PrintDbg("Modem message received: "..tostring(packet.target).." "..tostring(packet.command).." "..tostring(packet.pCommand), 2)
			if packet.target ~= nil or packet.command ~= nil then
				if (packet.target == label or packet.target == "BROADCAST" or packet.target == T_data.controllerType) then
					if packet.command == "SET STATE" then
						if packet.state == nil then
							PrintDbg("No state provided", 1)
						else 
							T_data.state = packet.state
							UpdateState()
							PrintDbg("State set: "..tostring(packet.state), 2)						
						end
					elseif packet.command == "OVERRIDE" then
						if T_data.overridden == false then
							T_data.overridden = true
						end
						WriteResume()
						SendReportPacket()
					elseif packet.command == "OVERRIDE OFF" then
						if T_data.overridden == true then
							T_data.overridden = false
						end
						WriteResume()
						SendReportPacket()
					elseif packet.command == "PEXECUTE" and string.sub(T_data.controllerType, 1, 2) == "P_" then
						--Peripheral command
						if T_data.perSide == nil or packet.pCommand == nil then
							PrintDbg("peripheral command error", 1)
							--TODO list of commands to be executed in "green" state only
						else
							--Preparing a packet to return
							rePacketT = {
								sender = label,
								controllerType = T_data.controllerType,
								state = T_data.state,
								version = VERSION_STRING,
								override = T_data.overridden,
								pExdCommand = packet.pCommand
							}
							--max 6 returnable params are allowed
							if packet.delay ~= nil then
								PrintDbg("Sleep delay:"..tonumber(packet.delay), 2)
								sleep(tonumber(packet.delay))
							end
							PrintDbg("Peripheral command:"..packet.pCommand..", params:"..tostring(packet.p1)..";"..tostring(packet.p2)..";"..tostring(packet.p3)..";"..tostring(packet.p4)..";"..tostring(packet.p5), 2)
							if packet.p5 ~= nil then
								rePacketT.p1, rePacketT.p2, rePacketT.p3, rePacketT.p4, rePacketT.p5, rePacketT.p6 = peripheral.call(T_data.perSide, packet.pCommand, packet.p1, packet.p2, packet.p3, packet.p4, packet.p5)
							elseif packet.p4 ~= nil then
								rePacketT.p1, rePacketT.p2, rePacketT.p3, rePacketT.p4, rePacketT.p5, rePacketT.p6 = peripheral.call(T_data.perSide, packet.pCommand, packet.p1, packet.p2, packet.p3, packet.p4)
							elseif packet.p3 ~= nil then
								rePacketT.p1, rePacketT.p2, rePacketT.p3, rePacketT.p4, rePacketT.p5, rePacketT.p6 = peripheral.call(T_data.perSide, packet.pCommand, packet.p1, packet.p2, packet.p3)
							elseif packet.p2 ~= nil then
								rePacketT.p1, rePacketT.p2, rePacketT.p3, rePacketT.p4, rePacketT.p5, rePacketT.p6 = peripheral.call(T_data.perSide, packet.pCommand, packet.p1, packet.p2)
							elseif packet.p1 ~= nil then
								rePacketT.p1, rePacketT.p2, rePacketT.p3, rePacketT.p4, rePacketT.p5, rePacketT.p6 = peripheral.call(T_data.perSide, packet.pCommand, packet.p1)
							else
								rePacketT.p1, rePacketT.p2, rePacketT.p3, rePacketT.p4, rePacketT.p5, rePacketT.p6 = peripheral.call(T_data.perSide, packet.pCommand)
							end
							SendPacket(rePacketT)
						end
					elseif packet.command == "REPORT" then
						SendReportPacket()
					elseif packet.command == "UPDATE" then
						shell.run("rm", "startup")
						Get(T_data.updateUrl, "startup")
						os.reboot()
					end
				end
			end
		end
	elseif event == "monitor_touch" and T_data.overridden == false then
		--Toggle
		if T_data.state == colors.green then
			T_data.state = colors.red
		elseif T_data.state == colors.red then
			T_data.state = colors.green
		end
		UpdateState()
	elseif event == "redstone" then
		UpdateState()
	end
end
