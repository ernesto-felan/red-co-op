local prevDomain = ""
local saveA = 0x000000
local saveB = 0x00E000
local sectionOffeset = 0x0FF4
local gameCodeOffset = 0x00AC
local section13Size = 0x7D0
local saveBSection0GameCode = saveA + section13Size + sectionOffeset + 0xF2C
local saveATeam = saveA + 0x0038
local saveATeamSize = saveA + 0x0034
local saveBTeamSize = saveB + 0x0034
local domain_list = memory.getmemorydomainlist()
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

teamSize = readRAM("SRAM", saveBSection0GameCode, 2)
console.log("sectionID")
console.log(teamSize)