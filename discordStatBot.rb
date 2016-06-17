#{
#word object:
# => uses words as keys
# => => word frequency
#people array:
# => uses peoples' names as keys
# => => times talked
# => => xp     (controlled by giveXP)
# => => level  (controlled by giveXP)
# => => 
# => => 
#}

require "discordrb"
require "json"
require "open-uri"
require "nokogiri"
require_relative "coderunner.rb"
#defines $MY_TEXT_CHANNEL, $DISCORD_SECRET, and $DISCORD_APP_ID
require_relative "secrets.rb"

$congratulations = ["Hell yeah", "Good job", "Congratulations", "Keep up the good work", "XD", "Time to kill yourself", "You're special", "What are you, freakin gay", "Hey, that's pretty good"]
$bot = Discordrb::Bot.new token: $DISCORD_SECRET, application_id: $DISCORD_APP_ID
if !File.exist?("discordStatBot.json")
	File.open("discordStatBot.json", "w") { |file| file.write('{"words": {}, "people": {}}') }
end
$stats = JSON.parse(File.read("discordStatBot.json"))
puts $stats
$floodProtectionObject = {}
$floodConvictionCounts = {}

def help() 
	$bot.send_message($MY_TEXT_CHANNEL, File.read("helpMessage"))
end

def sortKeysByAttribute(array, attribute)
	unsortedArray = []
	array.keys.each do |key|
		unsortedArray.push({"key" => key, attribute => array[key][attribute]})
	end
	return unsortedArray.sort_by{ |keyWithAttribute| keyWithAttribute[attribute] }
end

def xpToLevel(xp)
	(Math.sqrt(xp+16) * 0.25).floor
end

def levelToXP(level)
	(((4 * level) ** 2) - 16).floor
end

def giveXP(person, amount)
	$stats["people"][person]["xp"] = $stats["people"][person]["xp"] + amount
	if xpToLevel($stats["people"][person]["xp"]) > $stats["people"][person]["level"]
		$stats["people"][person]["level"] = xpToLevel($stats["people"][person]["xp"])
		$bot.send_message($MY_TEXT_CHANNEL, "#{$congratulations.sample}! **#{$stats["people"][person]["nick"]}** just reached level #{$stats["people"][person]["level"]}.")
	end
end

def removeXP(person, amount)
	$stats["people"][person]["xp"] = $stats["people"][person]["xp"] - amount
	if $stats["people"][person]["xp"] < 0
		$stats["people"][person]["xp"] = 0
	end
	$stats["people"][person]["level"] = xpToLevel($stats["people"][person]["xp"])
	$bot.send_message($MY_TEXT_CHANNEL, "#{$congratulations.sample}! **#{$stats["people"][person]["nick"]}** just lost #{amount} XP.")
end

#track message stats
$bot.message do |event|
	#STATS FOR !WORDS
	normalWordArray = event.content.downcase.gsub(/[^a-z0-9\s]/i, "").split(" ")
	normalWordArray.each do |word|
		if !$stats["words"].key?(word)
			$stats["words"][word] = {"amount" => 1}
		else
			$stats["words"][word]["amount"] = $stats["words"][word]["amount"] + 1
		end
	end

	#STATS FOR !PEOPLE
	if !$stats["people"].key?("#{event.author.id}")
		$stats["people"]["#{event.author.id}"] = {"timesSpoken" => 1, "nick" => event.author.display_name, "xp" => 0, "level" => 1}
		#event.respond "Welcome to the channel #{event.author.display_name}! You just reached **Level 1**. Type !xp to learn more."
	else
		#update the nickname just in case they changed it
		$stats["people"]["#{event.author.id}"]["nick"] = event.author.display_name
		$stats["people"]["#{event.author.id}"]["timesSpoken"] = $stats["people"]["#{event.author.id}"]["timesSpoken"] + 1
		giveXP("#{event.author.id}", 10)
	end

	#FLOOD PROTECTION
	#stores the timestamps for the last 3 messages, if they're too close
	#then it takes 150 XP
	
	if !$floodProtectionObject.key?("#{event.author.id}")
		$floodProtectionObject["#{event.author.id}"] = []
	end
	if !$floodConvictionCounts.key?("#{event.author.id}")
		$floodConvictionCounts["#{event.author.id}"] = 0
	end
	if event.author.display_name == "Aearnus"
		$floodConvictionCounts["#{event.author.id}"] = -1000
	end
	$floodProtectionObject["#{event.author.id}"].push event.timestamp
	if $floodProtectionObject["#{event.author.id}"].length > 4
		$floodProtectionObject["#{event.author.id}"].shift 
		if ($floodProtectionObject["#{event.author.id}"][-1] - $floodProtectionObject["#{event.author.id}"][0]) < 5
			event.respond("#{event.author.display_name}, stop flooding the chat.")
			removeXP("#{event.author.id}", 150)
			$floodConvictionCounts["#{event.author.id}"] = $floodConvictionCounts["#{event.author.id}"] + 1
		end
	end
	#if a player is convicted 3 times, they are kicked and have to be reinvited
	if $floodConvictionCounts["#{event.author.id}"] >= 3
		event.server.kick(event.author)
		$floodConvictionCounts["#{event.author.id}"] = 0
	end

	#SAVE STATS
	File.open("discordStatBot.json", "w") { |file| file.write(JSON.generate($stats)) }
end

$bot.message(start_with: "!help") do |event|
	help
end

$bot.message(start_with: "!words") do |event|
	sortedWordArray = sortKeysByAttribute($stats["words"], "amount").reverse
	outMessage = "**Top words used:**\n"
	amountOfWords = 10
	sortedWordArray.each do |wordWithAmount|
		outMessage += "#{wordWithAmount["key"]}: #{wordWithAmount["amount"]} times\n"
		amountOfWords -= 1
		if amountOfWords <= 0
			break
		end
	end
	event.respond outMessage
end

$bot.message(start_with: "!people") do |event|
	sortedPeopleArray = sortKeysByAttribute($stats["people"], "timesSpoken").reverse
	outMessage = "**Most active people:**\n"
	amountOfPeople = 10
	sortedPeopleArray.each do |wordWithAmount|
		personName = $stats["people"]["#{wordWithAmount['key']}"]["nick"]
		personLevel = $stats["people"]["#{wordWithAmount['key']}"]["level"]
		personXP = $stats["people"]["#{wordWithAmount['key']}"]["xp"]
		outMessage += "#{personName}: Spoken #{wordWithAmount["timesSpoken"]} times, level #{personLevel} with #{personXP} XP.\n"
		amountOfPeople -= 1
		if amountOfPeople <= 0
			break
		end
	end
	event.respond outMessage
end

$bot.message(start_with: "!xp") do |event|
	authorName = event.author.display_name
	authorXP = $stats["people"]["#{event.author.id}"]["xp"]
	authorLevel = $stats["people"]["#{event.author.id}"]["level"]
	neededXP = levelToXP(authorLevel + 1)
	event.respond "#{authorName}, you have #{authorXP} XP out of #{neededXP} XP and are level #{authorLevel}.\nXP can be gained by chatting, talking in voice channels, and other things."
end

$bot.message(start_with: "!ruby ") do |event|
	event.respond CodeRunner::runRuby(event.content[6..-1])
end

$bot.message(start_with: "!haskell ") do |event|
	event.respond CodeRunner::runHaskell(event.content[9..-1])
end

$bot.message(start_with: "!coin") do |event|
	event.respond "#{%w(Heads. Tails.).sample}"
end

$bot.message(start_with: "!roll ") do |event|
	diceNumbers = event.content.split(" ")[1..-1].map(&:to_i)
	outDice = []
	diceNumbers.each do |currentDie|
		outDice.push rand(1..currentDie)
	end
	event.respond outDice.join(" ")
end

$bot.message(start_with: "!rpic ") do |event|
	BANNED_USERS = [168919551562481665]
	#http://stackoverflow.com/questions/4581075/how-make-a-http-request-using-ruby-on-rails
	#http://stackoverflow.com/questions/6768238/download-an-image-from-a-url
	if !BANNED_USERS.include? event.author.id
		subreddit = event.content.split(" ")[-1]
		response = open("http://www.reddit.com/r/#{subreddit}/hot.json?count=100", {"User-Agent" => "a discord bot that sends pics (by /u/crazym4n)"}).read
		subredditListing = JSON.parse(response)
		imageUrls = []
		subredditListing["data"]["children"].each do |post|
			singleUrl = post["data"]["url"]
			if singleUrl =~ /\/imgur.com/ #if they link to imgur instead of i.imgur.com, fix it
				print "changing #{singleUrl} to "
				begin
					imgurPage = Nokogiri::HTML(open(singleUrl, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}))
					singleUrl = imgurPage.css(".post-image img").attr("src")
					puts "#{singleUrl}"
				rescue
					puts "imgur url couldn't be routed"
				end
			end
			if (singleUrl =~ /\.jpg|\.jpeg|\.bmp|\.png/) && post["data"]["over_18"] == false
				imageUrls.push(singleUrl)
			end
		end
		if imageUrls.length > 0
			begin
				cuteImageUrl = imageUrls.sample
				puts "downloading #{cuteImageUrl}"
				fileType = cuteImageUrl.split(".")[-1]
				fileName = "cute.#{fileType}"
				File.open(fileName, "wb") do |file|
					#have to disable ssl verification because awwni.me's
					#cert is fucking expired ofc
					file.write open(cuteImageUrl, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).read
				end
				File.open(fileName, "rb") do |file|
					event.channel.send_file(file)
				end
				File.delete(fileName)
			rescue
				puts "pic couldn't be downloaded"
			end
		else
			event.respond "Sorry! No images found."
		end
	end
end

$bot.message(start_with: "!xkcd ") do |event|
	begin
		xkcdNumber = event.content.split(" ")[-1].to_i
		#if we want the latest xkcd
		if xkcdNumber != 0
			xkcdPage = Nokogiri::HTML(open("http://xkcd.com/#{xkcdNumber}/", {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}))
		else
			xkcdPage = Nokogiri::HTML(open("http://xkcd.com/", {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}))
		end
		xkcdComic = xkcdPage.css("#comic img")
		xkcdImage = xkcdComic.attr("src").to_s
		if !xkcdImage.start_with?("http:")
			if xkcdImage.start_with?("//")
				xkcdImage = "http:#{xkcdImage}"
			end
		end
		File.open("xkcd.png", "wb") do |file|
			file.write open(xkcdImage, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).read
		end
		File.open("xkcd.png", "rb") do |file|
			event.channel.send_file(file)
		end
		File.delete("xkcd.png")
		event.respond "Alt-text: #{xkcdComic.attr('title')}"
	rescue
		event.respond "XKCD not found."
	end
end

$bot.run