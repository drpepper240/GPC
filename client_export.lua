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

VERSION_STRING = "0.70e"

--				SUPPORTED TYPES:
T_perTypes = {[1] = "AIRLOCK", [2] = "P_LEM", [3] = "CONTROLLER"}


--settings
T_data = {}
T_data.settings = {}

--default values, can be changed during installation or by editing "data" file

T_data.modemSide = nil
T_data.channelSend = 210
T_data.channelReceive = 211
T_data.pastebin = "s84FS5Js"				--pastebin entry for self-update
T_data.state = colors.green					--default state
T_data.overridden = false					--override mode
T_data.debugLvl = 0							--debug level
T_data.perSide = nil						--peripheral side
T_data.controllerType = "DEFAULT_TYPE"		--controller type
T_data.rsis = nil							--RS input side
T_data.rsos = nil							--RS output side
T_data.rsoss = nil							--RS output secondary side
T_data.rssc = colors.red					--redstone signal color code
T_data.displayText = " "					--text to display on display
T_data.laserFreq = 1488						--default laser frequency

--attempts to wrap peripheral
WRAP_ATTEMPTS = 5
--savedata filename
TDATA_FILENAME = "data"

modem = nil
label = nil
per = nil

--L_EM and everything which can obtain its own coordinates
--assuming coordinates can't change without client restart
gx, gy, gz = nil, nil, nil



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


--console dialogue to set all settings
function SettingsDialogue()
	term.clear()
	term.setCursorPos(1,1)

	print("Controller type(enter to abort):")
	--listing all available types
	for i=1, #T_perTypes do
		write(tostring(i).." - "..tostring(T_perTypes[i])..", ")
	end
	
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
	T_data.modemSide = tostring(read())
	if string.len(T_data.modemSide) < 1 then T_data.modemSide = nil end
	
	--type-dependent settings TODO	
	if string.sub(typeString, 1, 2) == "P_" then
		--PERIPHERAL
		print("Peripheral side (enter to skip):")
		T_data.perSide = tostring(read())
		if string.len(T_data.perSide) < 1 then T_data.perSide = nil end
	else
		--NOT PERIPHERAL
		print("Monitor side (enter to skip):")
		T_data.monitorSide = tostring(read())
		if string.len(T_data.monitorSide) < 1 then T_data.monitorSide = nil end
		
		print("Redstone input side (enter to skip):")
		T_data.rsis = tostring(read())
		if string.len(T_data.rsis) < 1 then T_data.rsis = nil end
		
		print("Redstone output side (enter to skip):")
		T_data.rsos = tostring(read())
		if string.len(T_data.rsos) < 1 then T_data.rsos = nil end
		
		print("Display text (enter to skip):")
		T_data.displayText = tostring(read())
		if string.len(T_data.displayText) < 1 then T_data.displayText = "" end
		
		if string.sub(typeString, 1, 7) == "AIRLOCK" then
			--AIRLOCK
			print("Secondary monitor side (enter to skip):")
			T_data.monitorSideSecondary = tostring(read())
			if string.len(T_data.monitorSideSecondary) < 1 then
				T_data.monitorSideSecondary = nil
			end
			
			print("Secondary redstone output side (enter to skip):")
			T_data.rsoss = tostring(read())
			if string.len(T_data.rsoss) < 1 then T_data.rsoss = nil end
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


function GetRSInput()
	PrintDbg("entering GetRSInput()", 2)
	if T_data.rsis == nil then
		PrintDbg("No RS input side", 2)
		return
	end
	--checking input side for state changes
	local signal = rs.getInput(T_data.rsis)
	PrintDbg("got "..tostring(signal).." at "..T_data.rsis, 2)
	if signal ~= ( T_data.rssc == T_data.state ) then
		if T_data.state == colors.green then
			T_data.state = colors.red
		elseif T_data.state == colors.red then
			T_data.state = colors.green
		end

		WriteResume()
		SendReportPacket()
	end
end


function SetRSOutput()
	PrintDbg("entering SetRSOutput()", 2)
	if T_data.rsos == nil then
		PrintDbg("No RS output side", 2)
		SendReportPacket()
		return
	elseif T_data.rssc == nil then
		PrintDbg("Can't find RS output state color", 0)
		return
	else 
		rs.setOutput(T_data.rsos, T_data.rssc == T_data.state)
		PrintDbg("set "..tostring(T_data.rssc == T_data.state).." at "..T_data.rsos, 2)
		if T_data.rsoss ~= nil then
			rs.setOutput(T_data.rsoss, T_data.rssc == T_data.state)
			PrintDbg("set "..tostring(T_data.rssc == T_data.state).." at "..T_data.rsoss, 2)
		end
		
		if monitor ~= nil then
			monitor.setBackgroundColor(T_data.state)
			monitor.clear()
			monitor.setTextColor(colors.black)
			monitor.setCursorPos(1,3)
			monitor.write(T_data.displayText)
		end
		
		if monitorSecondary ~= nil then
			monitorSecondary.setBackgroundColor(T_data.state)
			monitorSecondary.clear()
			monitorSecondary.setTextColor(colors.black)
			monitorSecondary.setCursorPos(1,3)
			monitorSecondary.write(T_data.displayText)
		end
	end
	SendReportPacket()
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
	if string.sub(T_data.controllerType, 1, 5) == "P_LEM" then
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


--main operation
label = os.getComputerLabel()

if (label == 0) then
	PrintDbg("Assign this controller a unique label", 0)
	return
end

ReadResume()

GetRSInput()
SetRSOutput()

WriteResume()

--opening
local i = 1
modem = peripheral.wrap(T_data.modemSide)
while modem==nil and i < WRAP_ATTEMPTS do
	PrintDbg("wrapping modem...\n", 1)
	sleep(1)
	modem = peripheral.wrap(T_data.modemSide)
	i = i + 1
end



if string.sub(T_data.controllerType, 1, 5) == "P_LEM" then
	peripheral.call(T_data.perSide, "freq", T_data.laserFreq)
	gx, gy, gz = peripheral.call(T_data.perSide, "pos")
end


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

GetRSInput()
SetRSOutput()

openChannel(modem, T_data.channelReceive)


--main loop
while true do
	local event, p1, p2, p3, p4, p5 = os.pullEvent()
	--key pressed
	if event == "key" then
		if p1 == 22 then
			--Update
			shell.run("rm", "startup")
			shell.run("pastebin", "get "..T_data.pastebin.." startup")
			os.reboot()
		elseif p1 == 20 and T_data.overridden == false then
			--Toggle
			if T_data.state == colors.green then
				T_data.state = colors.red
			elseif T_data.state == colors.red then
				T_data.state = colors.green
			end
			WriteResume()
			SetRSOutput()
		elseif p1 == 41 and T_data.overridden == false then
			--re-set
			fs.delete("data")
			os.reboot()
		end
	elseif event == "modem_message" then
		PrintDbg("Modem message received", 2)
		local packet = textutils.unserialize(p4)
		if packet.target ~= nil or packet.command ~= nil then
			if (packet.target == label or packet.target == "BROADCAST" or packet.target == T_data.controllerType) then
				if packet.command == "SET STATE" then
					if packet.state == nil then
						PrintDbg("No state provided", 1)
					else 
						T_data.state = packet.state
						WriteResume()
						SetRSOutput()
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
					shell.run("pastebin", "get "..T_data.pastebin.." startup")
					os.reboot()
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
		WriteResume()
		SetRSOutput()
	elseif event == "redstone" then
		GetRSInput()
	end
end