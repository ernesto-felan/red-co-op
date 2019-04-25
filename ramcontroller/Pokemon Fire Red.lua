local prevDomain = ""
local partySizeOffset = 0x024029
local domain_list = memory.getmemorydomainlist()
local pokemon1 = 0x024284
local pokemon2 = 0x0242E8
local pokemon3 = 0x02434C
local pokemon4 = 0x0243B0
local pokemon5 = 0x024414
local pokemon6 = 0x024478
-- console.log(domain_list)
-- Reads a value from RAM using little endian
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

function writePokemon(domain, partyOffset, pokemonData)
	for k,v in pairs(pokemonData) do
		memory.writebyte(partyOffset + k, v)
	end
	-- body
end

local partySize = readRAM("Combined WRAM", partySizeOffset, 2)
console.log(partySize)
local pokemon3Data = memory.readbyterange(pokemon3, 100, "Combined WRAM")
-- console.log(pokemon2Data)
writePokemon("Combined WRAM", pokemon1, pokemon3Data)
-- memory.writebyterange(pokemon3Data, "Combined WRAM")
-- console.log("monkaS")