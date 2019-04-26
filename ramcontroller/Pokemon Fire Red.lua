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

function readPokemon(partyIndex)
	return memory.readbyterange(partyIndexs[partyIndex], 100, "Combined WRAM")
end

function writePokemon(partyOffset, pokemonData)
	for k,v in pairs(pokemonData) do
		memory.writebyte(partyOffset + k, v)
	end
end

function addNewPokemon(pokemonData)
	prevRAM.partySize = prevRAM.partySize + 1
	writePokemon(partyIndexs[prevRAM.partySize], pokemonData)
	return prevRam
end

function getPartySize()
	return readRAM("Combined WRAM", partySizeOffset, 2)
end

-- RAM state from previous frame
local prevRAM = {
	partySize = 1 -- assume at least one pokemon to not send starter
}

-- Event to check when a new pokemon is added
function eventPokemonCollected(prevRam, newRam)
	
	if (prevRam.partySize < newRam.partySize) then
		return getPokemon(newRam.partySize)
	end

	return false
end

-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be send
function pfr_ram.getMessage()
	-- Gets the current RAM state
	local newRAM = {
		partySize = getPartySize()
	}
	local message = {}
	local changed = false

	-- Gets the message for a new collected pokemon
	local newPokemon = eventPokemonCollected(prevRAM, newRAM)
	if newPokemon then
		-- Add new changes
		message["p"] = newPokemon
		changed = true

		gui.addmessage(config.user .. ": sending new pokemon")
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
	-- Process new pokemon that was given
	if message["p"] then
		prevRAM = addNewPokemon(message["p"])
	end
end
pfr_ram.itemcount = 100
return pfr_ram