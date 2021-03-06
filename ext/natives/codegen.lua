-- setup environment for the codegen'd file to execute in
local codeEnvironment = {
	
}

types = {}
natives = {}
local curType
local curNative

local cfx = require('cfx')

function codeEnvironment.type(typeName)
	-- create a new type entry
	types[typeName] = {
		name = typeName
	}

	-- set a local
	local typeEntry = types[typeName]

	-- set a closure named after the type in the code environment
	codeEnvironment[typeName] = function(argumentName)
		return {
			type = typeEntry,
			name = argumentName
		}
	end

	codeEnvironment[typeName .. 'Ptr'] = function(argumentName)
		local t = codeEnvironment[typeName](argumentName)

		t.pointer = true

		return t
	end

	-- set the current type
	curType = typeEntry
end

function codeEnvironment.extends(base)
	curType.nativeType = types[base].nativeType
end

function codeEnvironment.nativeType(typeName)
	curType.nativeType = typeName
end

function codeEnvironment.subType(typeName)
	curType.subType = typeName
end

function codeEnvironment.property(propertyName)
	return function(data)

	end
end

function codeEnvironment.method(methodName)
	return function(data)

	end
end

function codeEnvironment.native(nativeName)
	-- create a new entry
	local native = {
		name = nativeName,
		apiset = {},
		hash = ("0x%x"):format(cfx.hash(nativeName:lower())),
		arguments = {},
		aliases = {}
	}

	table.insert(natives, native)

	-- set the current native to said native
	curNative = native
end

function codeEnvironment.doc(docString)
	if not curNative then
		return
	end

	curNative.doc = docString
end

function codeEnvironment.ns(nsString)
	curNative.ns = nsString
end

function codeEnvironment.hash(hashString)
	curNative.hash = hashString
end

function codeEnvironment.alias(name)
	table.insert(curNative.aliases, name)
end

function codeEnvironment.jhash(hash)
	curNative.jhash = hash
end

function codeEnvironment.arguments(list)
	curNative.arguments = list
end

function codeEnvironment.returns(typeName)
	curNative.returns = types[typeName]
end

function codeEnvironment.apiset(setName)
	table.insert(curNative.apiset, setName)
end

-- load the definition file
function loadDefinition(filename)
	local chunk = loadfile(filename, 't', codeEnvironment)

	chunk()
end

function trim(s)
	return s:gsub("^%s*(.-)%s*$", "%1")
end

function parseDocString(native)
	local docString = native.doc

	if not docString then
		return nil
	end

	local summary = trim(docString:match("<summary>(.+)</summary>"))
	local params = docString:gmatch("<param name=\"([^\"]+)\">([^<]+)</param>")
	local returns = docString:match("<returns>(.+)</returns>")

	if not summary then
		return nil
	end

	local paramsData = {}
	local hasParams = false

	for k, v in params do
		paramsData[k] = v
		hasParams = true
	end

	return {
		summary = summary,
		params = paramsData,
		hasParams = hasParams,
		returns = returns
	}
end

local gApiSet = 'server'

function matchApiSet(native)
	local apisets = native.apiset

	if #apisets == 0 then
		apisets = { 'client' }
	end

	for _, v in ipairs(apisets) do
		if v == gApiSet or v == 'shared' then
			return true
		end
	end

	return false
end

loadDefinition 'codegen_types.lua'

local outputType = 'lua'

if #arg > 0 then
	loadDefinition(arg[1])

	gApiSet = 'client'
end

if #arg > 1 then
	outputType = arg[2]
end

if #arg > 2 then
	gApiSet = arg[3]
end

loadDefinition 'codegen_cfx_natives.lua'

_natives = {}

for _, v in ipairs(natives) do
	table.insert(_natives, v)
end

table.sort(_natives, function(a, b)
	return a.name < b.name
end)

dofile('codegen_out_' .. outputType .. '.lua')
