
require 'socket'

# Each IRCClient represents one connection to a server.
class IRCClient
	class << self
		attr_accessor :listener_types
	end

	@listener_types = [
		:raw,
		:privmsg,
	]

	# Lets create our IRC commands
	{
		:login => "USER %s %s %s :%s",
		:umode => "MODE %s",
		:nickname => "NICK %s",

		:pong => "PONG :%s",

		:privmsg => "PRIVMSG %s :%s",
		:action => "PRIVMSG %s :\001ACTION %s\001",
		:notice => "NOTICE %s :%s",

		:quit => "QUIT",
	}.each do |command, message|
		define_method command do |*args|
			msg message % args
		end
	end

	attr_reader :socket
	attr_reader :id, :server, :nick, :channels, :plugins
	attr_accessor :log_input, :log_output
	attr_accessor :listeners

	def initialize(id, server, port, nick, username, realname)
		@id = id
		@server = server
		@port = port
		@nick = nick
		@username = username
		@realname = realname
		@channels = Array.new

		@log_input = @log_output = true

		@listeners = Hash.new
		self.class.listener_types.each do |type|
			@listeners[type] = Array.new
		end

		@plugins = Hash.new
		@disconnected = false
	end

	def connect
		# Connect to the IRC server
		@socket = TCPSocket.open @server, @port
		nickname @nick
		login @username, "localhost", @server, @realname
		umode @nick, "+B"
	end

	def disconnect
		# Disconnects from the server. The IRCClient is left running.
		return if @disconnected
		@disconnected = true
		quit
		@socket.close
	end

	def destroy
		# Destroys this IRCClient and frees the resources it was using.
		disconnect
		Clients.delete self
	end

	def msg(m)
		# Send a single message to the IRC server.
		log "--> #{m}" if @log_output
		@socket.write "#{m}\r\n"
	end

	def say(recipient, message, action = :privmsg)
		raise "No recipient" if recipient.nil?
		return if message == ""

		case message
		when Array
			message.each do |item|
				say recipient, item, action
			end
		when Hash
			message.each do |key, value|
				say recipient, "#{key} => #{value}", action
			end
		when String
			message.each_line do |line|
				send action, recipient, message
			end
		else
			say recipient, message.to_s, action
		end

		return nil
	end

	def join(channel)
		msg "JOIN #{channel}"
		@channels << channel if not @channels.include? channel
	end

	def part(channel)
		msg "PART #{channel}"
		@channels.delete channel
	end

	def add_plugin(id)
		if @plugins.include? id
			raise "Plugin #{id} already loaded in client #{id}"
		end
		Sources.require "plugins/" + id.to_s + ".rb"
		plugin = Kernel.const_get(id).new
		plugin.attach self
		@plugins[id] = plugin
	end

	def remove_plugin(id)
		unless @plugins.include? id
			raise "Plugin #{id} not loaded in client #{id}"
		end
		plugin = @plugins[id]
		plugin.detach
		@plugins.delete id
	end

	def dead?
		dead = false
		dead = true if @channels.empty?
		dead = true if listeners.all? { |key, value| value.length == 0 }
		return dead
	end

	def emit(signal, *params)
		@listeners[signal].each do |listener|
			return if listener.call *params
		end
	end

	@@inputs = {
		/^PING :(.+)/i => :ping_input,
		/^PRIVMSG (\S+) :(.+)/i => :privmsg_input,
	}

	def server_input(line)
		log "<-- #{line}" if @log_input
		nick, username, host = line.scrape! /^:(\S+?)!(\S+?)@(\S+?)\s/
		user = UserId.new nick, username, host
		args = nick ? [user] : []

		al = ActionList.new @@inputs, self
		handled = al.parse line, args
		emit :raw, user, line if !handled
	end

	def ping_input(noise)
		pong noise
	end

	def privmsg_input(user, target, message)
		private_message = (target == @nick)
		if private_message
			reply_to = user.nick
		else
			reply_to = target
		end
		emit :privmsg, user, reply_to, message
	end
end

