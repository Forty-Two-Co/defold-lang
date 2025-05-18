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


---Is lang module inited
---@type boolean
local INITED = false

---Current language translations
---@type table<string, string> Contains all current language translations. Key - lang id, Value - translation
local LANG_DICT = nil

-- Persistent storage
---@type lang.state
M.state = nil

---Reset module lang state
function M.reset_state()
	M.state = {
		lang = lang_internal.DEFAULT_LANG
	}
	INITED = false
	LANG_DICT = {}
end
M.reset_state()


---List of available languages
---@type { path: string, id: string }[] In order
M.available_langs = {}

---Initialize lang module
---@param available_langs { path: string, id: string }[] List of available languages
---@param force_lang string? Force language code
function M.init(available_langs, force_lang)
	for index, lang_data in ipairs(available_langs) do
		table.insert(M.available_langs, lang_data)
	end

	M.set_lang(force_lang or M.state.lang)
end


---Set logger for lang module. Pass nil to use empty logger
---@param logger_instance lang.logger|table|nil
function M.set_logger(logger_instance)
	lang_internal.logger = logger_instance or lang_internal.empty_logger
end


---Set current language
---@param lang_id string? current language code (en, jp, ru, etc.)
---@return boolean is language changed
function M.set_lang(lang_id)
	lang_internal.logger:info("Set lang", lang_id)

	local previous_lang = M.state.lang
	local previous_loaded_lang = INITED and previous_lang or nil

	-- check csv or json and load
	local lang_data = lang_internal.find(M.available_langs, "id", lang_id)
	if not lang_data then
		lang_internal.logger:error("Lang not found", lang_id)
		return false
	end

	local is_csv = string.find(lang_data.path, ".csv")
	local is_json = string.find(lang_data.path, ".json")
	if is_csv then
		M.load_from_csv(lang_data.path, lang_id)
	elseif is_json then
		M.load_from_json(lang_data.path, lang_id)
	else
		lang_internal.logger:error("Lang format not supported", lang_data.path)
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
	INITED = true
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


---@param druid druid.instance
---@param properties_panel druid.widget.properties_panel
function M.render_properties_panel(druid, properties_panel)
	lang_debug_page.render_properties_panel(M, druid, properties_panel)
end


return M
