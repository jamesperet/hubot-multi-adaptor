try
  {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User} = prequire 'hubot'

port = parseInt process.env.HUBOT_SOCKETIO_PORT or 9090
io = require('socket.io').listen port
console.log("socket.io server on port " + port);

express = require('express')
app = express()
bodyParser = require("body-parser")
app.use(bodyParser.urlencoded({ extended: false }))
app.use(bodyParser.json());

app.listen 80, =>
  console.log('HTTP server on port 80')

TelegramBot = require('node-telegram-bot-api')
#Telegram bot token (given when you create a new bot using the BotFather);
telegramBot = new TelegramBot(process.env.TELEGRAM_TOKEN, {polling: false});

class MultiAdapter extends Adapter

  constructor: (@robot) ->
    @sockets = {}
    super @robot

  send: (user, strings...) ->
    if user.service == "telegram"
      chatId = user.room;
      for str in strings
        telegramBot.sendMessage(chatId, str);
    else
      socket = @sockets[user.room]
      console.log("Sending response to user " + user.name + ":")
      console.log(str for str in strings)
      for str in strings
        socket.emit 'message', str

  reply: (user, strings...) ->
    socket = @sockets[user.room]
    for str in strings
      socket.emit 'message', str

  run: ->
    io.sockets.on 'connection', (socket) =>
      @sockets[socket.id] = socket
      console.log("New user connect (" + socket.id + ")")
      @robot.brain.set 'log_id_' + socket.id, new Date().getUTCMilliseconds();

      socket.on 'message', (data) =>
        user = @userForId socket.id, name: data.username, room: socket.id
        console.log("Message Received from user " + data.username + ":" )
        console.log(data.message)
        user.name = data.username
        user.service = "socket"
        @receive new TextMessage user, data.message

      socket.on 'disconnect', =>
        console.log("User disconected (" + socket.id + ")")
        @robot.brain.remove 'log_id_' + socket.id
        delete @sockets[socket.id]

    app.post '/telegram-api', (req, res) =>
      console.log(req.body)
      console.log(req.body.message)
      console.log(req.body.message.chat)
      @robot.brain.set 'log_id_' + req.body.message.chat.id, new Date().getUTCMilliseconds();
      user = @userForId req.body.message.chat.id, name: req.body.message.chat.username, room: req.body.message.chat.id
      console.log("Message Received from user " + req.body.message.chat.username + ":" )
      console.log(req.body.message.text)
      user.name = req.body.message.chat.username
      user.service = "telegram"
      @receive new TextMessage user, req.body.message.text
      res.end()

    @emit 'connected'

exports.use = (robot) ->
  new MultiAdapter robot
