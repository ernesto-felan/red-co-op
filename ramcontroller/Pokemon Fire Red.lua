local prevDomain = ""
local partySizeOffset = 0x024029
local domain_list = memory.getmemorydomainlist()
local partyIndexs = {
	[1] = 0x024284,
	[2] = 0x0242E8,
	[3] = 0x02434C,
	[4] = 0x0243B0,
	[5] = 0x024414,
	[6] = 0x024478
}
local pcBoxAddress = 0x029394

-- console.log(domain_list)
-- Reads a value from RAM using little endian

local pfr_ram = {}

function readRAM(domain, address, size)
	-- update domain
	if (prevDomain ~= domain) then
		prevDomain = domain
		if not memory.usememorydomain(domain) then
			return
		end
	end

	-- default size short
	if (size == nil) then
		size = 2
	end

	if size == 1 then
		return memory.readbyte(address)
	elseif size == 2 then
		return memory.read_u16_le(address)
	elseif size == 4 then
		return memory.read_u32_le(address)
	end
end

function writeRAM(domain, address, size, value)
	-- update domain
	if (prevDomain ~= domain) then
		prevDomain = domain
		if not memory.usememorydomain(domain) then
			return
		end
	end

	-- default size short
	if (size == nil) then
		size = 2
	end

	if (value == nil) then
		return
	end

	if size == 1 then
		memory.writebyte(address, value)
	elseif size == 2 then
		memory.write_u16_le(address, value)
	elseif size == 4 then
		memory.write_u32_le(address, value)
	end
end

function addToSet(set, key)
    set[key] = true
end

function removeFromSet(set, key)
    set[key] = nil
end

function setContains(set, key)
    return set[key] ~= nil
end

function getPokemon(partyIndex)
	return memory.readbyterange(partyIndexs[partyIndex], 100, "Combined WRAM")
end

function writePokemon(partyOffset, pokemonData)
	for k,v in pairs(pokemonData) do
		memory.writebyte(partyOffset + k, v)
	end
end

function addToBox(pokemonData)
	local openBoxAddress = memory.readbyte(pcBoxAddress)
	local i = 0x0
	while openBoxAddress ~= 0 do
		i = i + 0x50
		openBoxAddress = memory.readbyte(pcBoxAddress + i)
	end
	for k,v in pairs(pokemonData) do
		if(k<80) then
			memory.writebyte(pcBoxAddress + i + k, v)
		end
	end
end

function replacePokemon(prevRAM, pokemonData)
	slotToReplace = math.random(prevRAM.partySize)
	console.log("taking pokemon in slot:")
	console.log(slotToReplace)
	local oldPokemon = getPokemon(slotToReplace)
	writePokemon(partyIndexs[slotToReplace], pokemonData)
	return oldPokemon
end

function addPokemon(prevRAM, pokemonData)
	prevRAM.partySize = prevRAM.partySize
	writePokemon(partyIndexs[prevRAM.partySize], pokemonData)
	return prevRAM.partySize
end

function getPartySize()
	return readRAM("Combined WRAM", partySizeOffset, 2)
end

-- RAM state from previous frame
local prevRAM = {
	partySize = getPartySize(),
	pokemonToAdd = {},
	nextMessage = {}
}

local send_player_name = false
local player_names = {}

-- Event to check when a new pokemon is added
function eventPokemonCollected(prevRam, newRam)
	if (prevRam.partySize < newRam.partySize) then
		local taken_pokemon = getPokemon(newRam.partySize)
		console.log(taken_pokemon)
		return taken_pokemon
	else
		return false
	end
end

-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function pfr_ram.getMessage()
	-- Gets the current RAM state
	local newRAM = {
		partySize = getPartySize(),
		pokemonToAdd = prevRAM.pokemonToAdd,
		nextMessage = prevRAM.nextMessage
	}
	local message = {}
	local changed = false
	-- Gets the message for a new collected pokemon
	local newPokemon = eventPokemonCollected(prevRAM, newRAM)
	if newPokemon then
		next_player,_ = next(player_names, config.user)
		if next_player == nil then
			next_player,_ = next(player_names)
		end
		console.log("Sending new pokemon to:")
		console.log(next_player)
		console.log("\nCurrent list of players")
		console.log(player_names)
		-- Add new changes
		message["p"] = {
			original_player = config.user,
			player = next_player,
			pokemon = newPokemon
		}
		changed = true

		gui.addmessage(config.user .. ": sending new pokemon")
	end

	if next(prevRAM.pokemonToAdd) ~= nil then
		next_player,_ = next(player_names, config.user)
		if next_player == nil then
			console.log("we are last player setting next player to first player")
			next_player,_ = next(player_names)
		end
		-- Add new changes
		message["a"] = {
			player = next_player,
			pokemon = prevRAM.pokemonToAdd
		}
		prevRAM.pokemonToAdd = {}
		newRAM.pokemonToAdd = {}
		changed = true
		gui.addmessage(config.user .. ": sending pokemon")
	end

	if next(prevRAM.nextMessage) ~= nil then
		message["p"] = prevRAM.nextMessage
		prevRAM.nextMessage = {}
		newRAM.nextMessage = {}
		changed = true
		gui.addmessage(config.user .. ": sending pokemon")
	end

	-- send my player name if event is queued
	if send_player_name then
		changed = true
		send_player_name = false
		message["n"] = config.user
	end

	-- Update the frame pointer
	prevRAM = newRAM

	if changed then
		-- Send message
		return message
	else 
		-- No updates, no message
		return false
	end
end

-- Process a message from another player and update RAM
function pfr_ram.processMessage(their_user, message)
	-- "i" type is for handling item split events, which
	-- is not something this ram controller does. However
	-- this event will happen any time a player joins,
	-- so we will send player names again and reload the
	-- script's save data for stability
	if message["i"] then
		addToSet(player_names, config.user)
		send_player_name = true
	end

	-- player name message from another player
	if message["n"] then
		if (setContains(player_names, their_user) == false) then
			addToSet(player_names, their_user)
		end
		console.log(player_names)
	end

	-- Process new pokemon that was given
	if message["p"] then
		console.log("GOT P MESSAGE for:")
		console.log(message["p"]["player"])
		if message["p"]["player"] == config.user then
			next_player,_ = next(player_names, config.user)
			if next_player == nil then
				console.log("we are last player setting next player to first player")
				next_player,_ = next(player_names)
			end
			console.log("next_player")
			console.log(next_player)
			local oldPokemon
			if getPartySize() == 0 then
				oldPokemon = message["p"]["pokemon"]
			else
				oldPokemon = replacePokemon(prevRAM, message["p"]["pokemon"])
			end

			if next_player == message["p"]["original_player"] then
				prevRAM.pokemonToAdd = oldPokemon
			end
			if next_player ~= message["p"]["original_player"] then
				prevRAM.nextMessage = message["p"]
				prevRAM.nextMessage["pokemon"] = oldPokemon
				prevRAM.nextMessage["player"] = next_player
			end
		end
	end

	if message["a"] then
		if message["a"]["player"] == config.user then
			console.log("GOT A MESSAGE for:")
			console.log(message["a"]["player"])
			if getPartySize() == 5 then
				console.log("party is 5 sending to box")
				addToBox(message["a"]["pokemon"])
			else
				prevRAM.partySize = addPokemon(prevRAM, message["a"]["pokemon"])
			end
		end
	end
end
pfr_ram.itemcount = 100
return pfr_ram