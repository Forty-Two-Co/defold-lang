--- Lang localization helper module
--- Call lang.init() to init module to load last used or default language
--- With saver module use saver.bind_save_state("lang", lang.state) to load lang state to save
--- To load in other way - replace state table before lang.init()
--- Use lang.set_lang("en") to change language
--- Use lang.set_next_lang() to change language to next in list
--- Use lang.txt("key") to get translation
--- Use lang.txr("key") to get random translation, split by \n symbol
--- Use lang.txp("key", "param1", "param2") to get translation with params (Use %s in translation)
--- Use lang.is_exist("key") to check is translation exist
--- Use lang.get_langs() to get list of available languages

local lang_internal = require("lang.lang_internal")
local lang_debug_page = require("lang.lang_debug_page")

---@class lang
local M = {}


---@class lang.data
---@field path string|table Lua table, json or csv path, ex: "/resources/lang/en.json", "/resources/lang/en.csv"
---@field id string Language code, ex: "en". If csv file, it's a header name

---Current language translations
---@type table<string, string> Contains all current language translations. Key - lang id, Value - translation
local LANG_DICT = nil

-- Persistent storage
---@type lang.state
M.state = nil

---List of available languages
---@type lang.data[] In order
M.available_langs = nil

---Map of available languages for fast lookup
---@type table<string, lang.data> Key is language id, value is lang.data
local AVAILABLE_LANGS_MAP = nil

---Reset module lang state
function M.reset_state()
	M.state = {
		lang = lang_internal.DEFAULT_LANG,
	}
	M.available_langs = {}
	AVAILABLE_LANGS_MAP = {}
	LANG_DICT = {}
end
M.reset_state()


---Check if language exists in available languages
---@param lang_id string Language code to check
---@return boolean True if language exists
local function is_lang_available(lang_id)
	return AVAILABLE_LANGS_MAP[lang_id] ~= nil
end


---Get language data by id
---@param lang_id string Language code
---@return lang.data|nil Language data or nil if not found
local function get_lang_data(lang_id)
	return AVAILABLE_LANGS_MAP[lang_id]
end


---Initialize lang module
---@param available_langs lang.data[] List of available languages
---@param lang_on_start string? Language code to set on start, override saved language
function M.init(available_langs, lang_on_start)
	if not available_langs or #available_langs == 0 then
		lang_internal.logger:error("No available languages provided to init")
		return
	end

	local default_lang = available_langs[1].id

	-- Build available languages list and map
	for index, lang_data in ipairs(available_langs) do
		table.insert(M.available_langs, lang_data)
		AVAILABLE_LANGS_MAP[lang_data.id] = lang_data
		default_lang = default_lang or lang_data.id
	end

	-- Get system language if no specific language is requested
	local system_lang = nil
	if not lang_on_start and not M.state.lang then
		local sys_info = sys.get_sys_info()
		lang_internal.logger:info("System language", sys_info.language)

		if sys_info and sys_info.language then
			-- Check if system language exists in available languages using fast lookup
			if is_lang_available(sys_info.language) then
				system_lang = sys_info.language
			end
		end
	end

	-- Determine target language with validation
	local target_lang = lang_on_start or M.state.lang or system_lang or default_lang

	-- Validate the target language exists, fallback to default if not
	if not is_lang_available(target_lang) then
		lang_internal.logger:warn("Target language not available, falling back to default", {
			target_lang = target_lang,
			default_lang = default_lang
		})
		target_lang = default_lang
	end

	M.set_lang(target_lang)
end


---Set logger for lang module. Pass nil to use empty logger
---@param logger_instance lang.logger|table|nil
function M.set_logger(logger_instance)
	lang_internal.logger = logger_instance or lang_internal.empty_logger
end


---Set current language
---@param lang_id string current language code (en, jp, ru, etc.)
---@return boolean is language changed
function M.set_lang(lang_id)
	if not lang_id then
		lang_internal.logger:error("Language id cannot be nil")
		return false
	end

	local previous_lang = M.state.lang
	local previous_loaded_lang = previous_lang or nil

	-- Check if language is available using fast lookup
	if not is_lang_available(lang_id) then
		lang_internal.logger:error("Lang not found", lang_id)
		return false
	end

	-- Get language data using fast lookup
	local lang_data = get_lang_data(lang_id)
	if not lang_data then
		lang_internal.logger:error("Lang data not found", lang_id)
		return false
	end

	local is_lua = type(lang_data.path) == "table"
	---@type string|nil
	local path_str = type(lang_data.path) == "string" and lang_data.path --[[@as string]] or nil
	local is_csv = not is_lua and path_str and string.find(path_str, ".csv")
	local is_json = not is_lua and path_str and string.find(path_str, ".json")

	if is_lua then
		M.set_lang_table(lang_data.path)
		M.state.lang = lang_id
	elseif is_csv and path_str then
		M.load_from_csv(path_str, lang_id)
	elseif is_json and path_str then
		M.load_from_json(path_str, lang_id)
	else
		lang_internal.logger:error("Lang format not supported", lang_data.path or "unknown")
		return false
	end

	lang_internal.logger:info("Lang changed", { previous_lang = previous_loaded_lang, lang = lang_id })
	return true
end


---Load lang from json file
---@private
---@param lang_path string path to lang file
---@param locale_id string? locale id
---@return table<string, string>? result lang data or false if error
function M.load_from_json(lang_path, locale_id)
	locale_id = locale_id or M.state.lang or lang_internal.DEFAULT_LANG

	local is_parsed, lang_data = pcall(lang_internal.load_json, lang_path)
	if not is_parsed then
		lang_internal.logger:error("Can't load or parse lang file. Check the JSON file is valid", lang_path)
		return nil
	end
	if not lang_data then
		lang_internal.logger:error("Lang file not found", lang_path)
		return nil
	end

	M.set_lang_table(lang_data)
	M.state.lang = locale_id

	return lang_data
end


---Load lang from csv file
---@private
---@param csv_path string path to csv file
---@param locale_id string? lang code, default is last used lang
---@return table<string, string>? result lang data or false if error
function M.load_from_csv(csv_path, locale_id)
	locale_id = locale_id or M.state.lang or lang_internal.DEFAULT_LANG

	local langs_data = lang_internal.load_csv(csv_path)
	if not langs_data then
		lang_internal.logger:error("Can't load or parse lang file. Check the CSV file is valid", csv_path)
		return nil
	end

	if not langs_data[locale_id] then
		lang_internal.logger:error("Lang code not found", locale_id)
		return nil
	end

	M.set_lang_table(langs_data[locale_id])
	M.state.lang = locale_id

	return langs_data[locale_id]
end


function M.set_lang_table(lang_table)
	LANG_DICT = lang_table
end


---Set next language from lang list and return it's code
---@return string lang_code The new language code after change
function M.set_next_lang()
	M.set_lang(M.get_next_lang())

	return M.get_lang()
end


---Get next language from lang list and return it's code
---@return string lang_code next language code
function M.get_next_lang()
	local current_lang = M.get_lang()
	local all_langs = M.get_langs()
	local current_index = lang_internal.index_of(all_langs, current_lang) or 1

	local next_index = current_index + 1
	if next_index > #all_langs then
		next_index = 1
	end

	return all_langs[next_index]
end


---Get current language
---@return string Current language code
function M.get_lang()
	return M.state.lang
end


---Get default language
---@return string Default language code
function M.get_default_lang()
	return lang_internal.DEFAULT_LANG
end


---Get translation for text id
---@param text_id string text id from your localization
---@return string Translated text
function M.txt(text_id)
	return LANG_DICT[text_id] or text_id or ""
end


---Get random translation for text id, split by \n symbol
---@param text_id string text id from your localization
---@return string translated text
function M.txr(text_id)
	local texts = lang_internal.split(LANG_DICT[text_id], "\n")
	return texts[math.random(1, #texts)]
end


---Get translation for text id with params
---@param text_id string Text id from your localization
---@vararg string|number Params for translation
---@return string Translated text
function M.txp(text_id, ...)
	return string.format(M.txt(text_id), ...)
end


---Check is translation with text_id exist
---@param text_id string text id from your localization
---@return boolean Is translation exist for text_id
function M.is_exist(text_id)
	return (not not LANG_DICT[text_id])
end


---Return list of available languages
---@return string[] List of available languages
function M.get_langs()
	local langs = {}
	for _, lang_data in ipairs(M.available_langs) do
		table.insert(langs, lang_data.id)
	end

	return langs
end


---Get lang table
---@return table<string, string>
function M.get_lang_table()
	return LANG_DICT
end


---Check if language is available
---@param lang_id string Language code to check
---@return boolean True if language is available
function M.is_lang_available(lang_id)
	return is_lang_available(lang_id)
end


---@param druid table druid instance
---@param properties_panel table druid properties panel instance
function M.render_properties_panel(druid, properties_panel)
	lang_debug_page.render_properties_panel(M, druid, properties_panel)
end


return M
