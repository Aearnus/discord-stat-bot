module CodeRunner
	def self.runCode(code, interpreter)
		badKeywords = ["\`", "popen", "gets", "STDIN", "interact", "input", "system", "File", "file", "IO", "eval", "exec", "open", "write", "read", "Socket", "%x"]

		malicious = false
		badKeywords.each do |word|
			if code.include? word then
				malicious = true
			end
		end
		if malicious then
			output = "Hey, calm down there."
		else
			puts "running #{code} as #{interpreter}"
			output = ""
			File.open("tempCode", "w") { |file| file.write(code) }
			thread = Thread.new {output = `#{interpreter} tempCode`}
			thread.join 10
			if output.length == 0 then
				output = "Code either took longer than 10 seconds to run or produced no output."
			elsif output.split(?\n).length > 5
				output = output.split(?\n)[0..5].push("...").join(?\n)
			end
		end
		#File.delete("tempCode")
		return output[0..1999]
	end

	def self.runRuby(code)
		return runCode(code, "ruby")
	end

	def self.runHaskell(code) 
		return runCode(code, "runghc")
	end
end