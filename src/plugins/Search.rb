# requires Ruby 1.9, won't work on 1.8
if RUBY_VERSION < "1.9"
	abort "The Search plugin requires Ruby 1.9"
end

require 'json'
require 'open-uri'
require 'uri'

require 'rubygems'
require 'andand'

class Search < RubotPlugin
	@@actions = {
		/:search\s*(.+)/i => :search,
		/^(w+(h+)?[ao]+t+|w+(h+)?o+|w+[dt]+[fh]+)(\s+(t+h+e+|i+n+|o+n+)\s+(.+?))?((\'+?)?s+|\s+i+s+)\s+(a+(n+)?\s+)?(.+?)(\/|\\|\.|\?|!|$)/i => :search11,
		/^(t+e+l+l+)\s+(m+e+|u+s+|e+v+e+r+y+o+n+e+)\s+(w+(h+)?a+t+|w+h+o+|(a+)?b+o+u+t+)\s+(i+s+|a+(n+)?|)+(.+?)(\s+i+s+|\/|\\|\.|\?|!|$)/i => :search8,
		/^jamer(\S+)?(:|,)?\s+(hi|hello|sup|yo)/i => :say_hi,
		/^(hi|hello|sup|yo)(.+?)?\s+jamer/i => :say_hi,
	}

	def privmsg(user, source, line)
		if line.match(/#{@client.nick}/i) or line.match(/jamerbot/)
			mkay(source)
		end
		line.gsub!(/#{@client.nick}:?\s+/, '')
		return RegexJump::jump(@@actions, self, line, [user.nick, source])
	end

	def fetch_info(terms)
		formatted = URI::escape(terms.gsub(' ','+'))
		data = open("http://api.duckduckgo.com/?q=#{formatted}&o=json")
		json = JSON::parse(data.readlines.join('\n'))
		return json
	end

	def search(nick, source, message)
		json = fetch_info(message)
		output = [
				json['AbstractText'],
				json['RelatedTopics'].at(0).andand['Text']
		].delete_if {|x| !x || x.length == 0 }.first
		if output
			say(source, output.gsub(/<.*?>/, ''))
		else
			say(source, "I don't know.")
		end
	end

	def search8(nick, source, *unused, message, x)
		search(nick, source, message)
	end

	def search11(nick, source, *unused, message, x)
		search(nick, source, message)
	end

	def say_hi(nick, source, *unused)
		say(source, "Hey #{nick}.")
	end

	def mkay(source)
		if rand % 10 == 0
			say(source, "Mkay.")
		end
	end
end

