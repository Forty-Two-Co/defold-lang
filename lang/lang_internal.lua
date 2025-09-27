local csv = require("lang.csv")

---@class lang.state
---@field lang string @current language name (en, jp, ru, etc.)

---@class lang.logger
---@field trace fun(logger: lang.logger, message: string, data: any|nil)
---@field debug fun(logger: lang.logger, message: string, data: any|nil)
---@field info fun(logger: lang.logger, message: string, data: any|nil)
---@field warn fun(logger: lang.logger, message: string, data: any|nil)
---@field error fun(logger: lang.logger, message: string, data: any|nil)


local M = {}


---Split string by separator
---@param s string
---@param sep string
---@return table
function M.split(s, sep)
	sep = sep or "%s"
	local t = {}
	local i = 1
	for str in string.gmatch(s, "([^" .. sep .. "]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end


--- Use empty function to save a bit of memory
local EMPTY_FUNCTION = function(_, message, context) end

---@type lang.logger
M.empty_logger = {
	trace = EMPTY_FUNCTION,
	debug = EMPTY_FUNCTION,
	info = EMPTY_FUNCTION,
	warn = EMPTY_FUNCTION,
	error = EMPTY_FUNCTION,
}

---@type lang.logger
M.logger = {
	trace = function(_, msg, data) print("TRACE:", msg, data) end,
	debug = function(_, msg, data) print("DEBUG:", msg, data) end,
	info = function(_, msg, data) print("INFO:", msg, data) end,
	warn = function(_, msg, data) print("WARN:", msg, data) end,
	error = function(_, msg, data) print("ERROR:", msg, data) end
}


---Load JSON file from game resources folder (by relative path to game.project)
---Return nil if file not found or error
---@param json_path string
---@return table|nil
function M.load_json(json_path)
	local resource, is_error = sys.load_resource(json_path)
	if is_error or not resource then
		return nil
	end

	return json.decode(resource)
end


---Load CSV file from game resources folder (by relative path to game.project)
---Return nil if file not found or error
---@param csv_path string
---@return table|nil
function M.load_csv(csv_path)
	local resource, is_error = sys.load_resource(csv_path)
	if is_error or not resource then
		return nil
	end

	local data = {}
	local f = csv.openstring(resource)
	local headers = nil

	-- Parse headers, first id is a lang_id to table <lang<locale_id, translate>>
	for fields in f:lines() do
		if not headers then
			-- First row contains language codes
			headers = fields
			-- Initialize language tables
			for i = 2, #headers do
				data[headers[i]] = {}
			end
		else
			-- Process data rows
			local key = fields[1] -- First column is the translation key
			if key then
				-- Add translations for each language
				for i = 2, #headers do
					if fields[i] then
						data[headers[i]][key] = fields[i]
					end
				end
			end
		end
	end

	return data
end


---Check if a table contains a value
---@param t table
---@param value any
---@return number|nil
function M.index_of(t, value)
	for i, v in ipairs(t) do
		if v == value then
			return i
		end
	end
	return nil
end


---Decode CSV data
---@param csv_data string
---@return table
function M.csv_decode(csv_data)
	local result = {}
	local lines = {}

	-- Split into lines
	for line in csv_data:gmatch("([^\r\n]+)") do
		table.insert(lines, line)
	end

	if #lines == 0 then
		return result
	end

	-- Parse headers (first row)
	local headers = {}
	for header in lines[1]:gmatch("([^,]+)") do
		header = header:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
		table.insert(headers, header)
		result[header] = {} -- Initialize language map
	end

	-- Process each data row
	for i = 2, #lines do
		local line = lines[i]
		local col_index = 1
		local key = nil

		-- Parse each field
		for field in line:gmatch("([^,]+)") do
			field = field:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace

			if col_index == 1 then
				-- First column is the translation key
				key = field
			elseif key and col_index <= #headers then
				-- Add translation to language map
				result[headers[col_index]][key] = field
			end

			col_index = col_index + 1
		end
	end

	return result
end

return M
