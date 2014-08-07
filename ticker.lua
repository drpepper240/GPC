--computercraft
--network timer by drPepper

-- "THE BEER-WARE LICENSE"
-- drPepper@KOPROKUBACH wrote this file. As long as you retain this notice you
-- can do whatever you want with this stuff. If we meet some day, in-game or IRL,
-- and you think this stuff is worth it, you can give me a beer in return

--How this should be used:
--set proper timing
--set channelReceive
--one controller - one function, computers are cheap. Do not use single computer to control air generators, lighting and doors/airlocks simultaneously
--one zone - one controller. Wire all air generators in a room to a single controller, then call it AGBRIDGE or something
--ID shoud be 3 chars or longer
--ID should not be equal to controller type

VERSION_STRING = "0.1"
T_sides = {[1] = "left", [2] = "right", [3] = "front", [4] = "back", [5] = "top", [6] = "bottom"}

--settings
T_data = {}

--default values, can be changed during installation or by editing "data" file

T_data.modemSide = nil
T_data.channelSend = nil
T_data.channelReceive = 1488
T_data.pastebin = "3NS5ChbD"				--pastebin entry for self-update
T_data.debugLvl = 1					--debug level
T_data.period = nil					--broadcasting period

--attempts to wrap peripheral
WRAP_ATTEMPTS = 5
--savedata filename
TDATA_FILENAME = "data"

modem = nil
label = nil



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

function GetSideFromUser()
	--listing all available sides
	for i=1, #T_sides do
		write(tostring(i).." - "..tostring(T_sides[i]).."\n")
	end
	
	local sideString = tostring(T_sides[tonumber(read())])
	return sideString
end


--console dialogue to set all settings
function SettingsDialogue()
	term.clear()
	term.setCursorPos(1,1)

	--generic settings
	print("Modem side (enter to skip):")
	T_data.modemSide = GetSideFromUser()
	if string.len(T_data.modemSide) < 1 then T_data.modemSide = nil end
	
	print("Broadcast on channel:")
	T_data.channelSend = tonumber(read())
	if string.len(T_data.channelSend) < 1 then T_data.channelSend = nil end
	
	print("Broadcasting period:")
	T_data.period = tonumber(read())
	if string.len(T_data.period) < 1 then T_data.period = nil end
	
	print("ID (enter to abort):")
	local idString = tostring(read())
	if string.len(idString) < 3 or T_data.modemSide == nil or T_data.channelSend == nil or T_data.period == nil then
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
print("Network timer by drPepper")
print("Version "..VERSION_STRING.."\n")
ReadResume()
print("Broadcasting on channel: "..tostring(T_data.channelSend))
print("Period: "..tostring(T_data.period).." seconds")
label = os.getComputerLabel()

if (label == 0) then
	PrintDbg("Assign this controller a unique label", 0)
	return
end


--opening
local i = 1
modem = peripheral.wrap(T_data.modemSide)
while modem==nil and i < WRAP_ATTEMPTS do
	PrintDbg("wrapping modem...\n", 1)
	sleep(1)
	modem = peripheral.wrap(T_data.modemSide)
	i = i + 1
end

--openChannel(modem, T_data.channelReceive)

local tickCnt = 0
local packetT = {
		sender = label,
		version = VERSION_STRING,
}

--main loop
while true do
	packetT.time = os.time()
	packetT.uptime = tickCnt * T_data.period
	
	local packet = textutils.serialize(packetT)
	
	modem.transmit(	T_data.channelSend, T_data.channelReceive, packet )
	tickCnt = tickCnt + 1
	sleep(T_data.period)
end