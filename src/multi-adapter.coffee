try
  {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User} = prequire 'hubot'

logger = require("./logger")
express = require('express')
app = express()
bodyParser = require("body-parser")
app.use(bodyParser.urlencoded({ extended: false }))
app.use(bodyParser.json());
app.use(require('morgan')("default", { "stream": logger.stream }));

http_port = parseInt process.env.HUBOT_HTTP_PORT or 80
app.listen http_port, =>
  #console.log('HTTP server on port ' + http_port)
  logger.winston.info("app listening on port " + http_port + ".")

socket_port = parseInt process.env.HUBOT_SOCKETIO_PORT or 9090
io = require('socket.io').listen socket_port
logger.winston.info("socket.io server on port " + socket_port);

TelegramBot = require('node-telegram-bot-api')
#Telegram bot token (given when you create a new bot using the BotFather);
telegramBot = new TelegramBot(process.env.TELEGRAM_TOKEN, {polling: false});

class MultiAdapter extends Adapter

  constructor: (@robot) ->
    @sockets = {}
    super @robot

  send: (user, strings...) ->
    for str in strings
      logger(@robot, "info", "Sending response to user " + user.user.name + " thru " + user.user.service + ": " + str, { message: str, user: user } )
    if user.user.service == "telegram"
      chatId = user.user.room;
      for str in strings
        telegramBot.sendMessage(chatId, str);
    else
      socket = @sockets[user.room]
      for str in strings
        socket.emit 'message', str

  reply: (user, strings...) ->
    socket = @sockets[user.room]
    for str in strings
      socket.emit 'message', str

  log: (log_msg) ->
    for socket in @sockets
      socket.emit 'message', log_msg

  run: ->
    io.sockets.on 'connection', (socket) =>

      # logger.on 'logging', (transport, level, msg, meta) =>
      #     #console.log("> [%s] and [%s] have now been logged at [%s] to [%s]", msg, JSON.stringify(meta), level, transport.name)
      #     socket.emit 'message', msg

      @sockets[socket.id] = socket
      #console.log("New user connect (" + socket.id + ")")
      logger(@robot, "info", "New user connect (" + socket.id + ")" )
      @robot.brain.set 'log_id_' + socket.id, new Date().getUTCMilliseconds();

      socket.on 'message', (data) =>
        user = @userForId socket.id, name: data.username, room: socket.id
        logger(@robot, "info", "Message Received from user " + data.username + " thru socket: " + data.message, { data: data } )
        #console.log("Message Received from user " + data.username + ":" )
        #console.log(data.message)
        user.name = data.username
        user.service = "socket"
        @receive new TextMessage user, data.message

      socket.on 'disconnect', =>
        #console.log("User disconected (" + socket.id + ")")
        logger(@robot, "info", "User disconected (" + socket.id + ")" )
        @robot.brain.remove 'log_id_' + socket.id
        delete @sockets[socket.id]

    # Telegram Webhook
    app.post '/telegram-api', (req, res) =>
      # Get username
      user_name = req.body.message.from.first_name + " " + req.body.message.from.last_name
      # Get text
      text = req.body.message.text
      # Get Chat ID
      chat_id = req.body.message.chat.id
      # Log Msg
      logger(@robot, "info", "Message Received from user #{user_name} (#{req.body.message.from.username}) thru Telegram: " + text, { data: req.body } )
      # Set other things
      @robot.brain.set 'log_id_' + chat_id, new Date().getUTCMilliseconds();
      user = @userForId chat_id, name: user_name, room: chat_id
      user.service = "telegram"
      user.first_name = req.body.message.from.first_name
      user.last_name = req.body.message.from.last_name
      user.username = req.body.message.from.username
      user.room = chat_id
      user.msg_type = "message"
      @receive new TextMessage user, text
      res.end()

    # General Webhook
    app.post '/webhook', (req, res) =>
      console.log(req.body)
      if req.body.user != undefined
        if req.body.text && req.body.user.room && req.body.user.service && req.body.user.first_name && req.body.user.last_name && req.body.user.username && req.body.user.msg_type
          chat_id = req.body.user.room
          # Get username
          user_name = req.body.user.first_name + " " + req.body.user.last_name
          text = req.body.text
          @robot.brain.set 'log_id_' + chat_id, new Date().getUTCMilliseconds()
          user = @userForId chat_id, name: user_name, room: chat_id
          logger(@robot, "info", "Webhook received from #{user_name} with command: " + text, { data: req.body } )
          user.service = req.body.user.service
          user.first_name = req.body.user.first_name
          user.last_name = req.body.user.last_name
          user.username = req.body.user.username
          user.room = chat_id
          user.msg_type = req.body.user.msg_type
          @receive new TextMessage user, text
          res.status(200).send({"message" : "received"})
        else
          res.status(400).send({"message" : "The user object has mising properties. Follow instruction on https://github.com/jamesperet/hubot-multi-adaptor"})
      else
        res.status(400).send({"message" : "Please check the body of your request. Follow instruction on https://github.com/jamesperet/hubot-multi-adaptor"})

    @emit 'connected'

exports.use = (robot) ->
  new MultiAdapter robot
