return function()
	local lang = {} --[[@as lang]]

	describe("Defold Lang", function()
		before(function()
			lang = require("lang.lang")
			lang.reset_state()
		end)

		it("Should not change language if not found", function()
			lang.init({
				{ id = "en", path = "/resources/lang/en.json" },
			}, "fr")

			local text = lang.txt("ui_hello")
			assert_equal(text, "Hello, World!")
			assert_equal(lang.state.lang, "en")
		end)
	end)
end
