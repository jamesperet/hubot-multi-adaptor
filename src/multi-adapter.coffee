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
    console.log("Sending response to user " + user.user.name + " thru " + user.user.service + ":")
    console.log(str for str in strings)
    console.log(user)
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
      chat_id = req.body['message[chat][id]']
      # Get username
      user_name = req.body['message[from][first_name]'] + " " + req.body['message[from][last_name]']
      text = req.body['message[text]']
      @robot.brain.set 'log_id_' + chat_id, new Date().getUTCMilliseconds();
      user = @userForId chat_id, name: user_name, room: chat_id
      console.log("Message Received from user " + user_name + ":" )
      console.log(text)
      user.service = "telegram"
      user.first_name = req.body['message[from][first_name]']
      user.last_name = req.body['message[from][last_name]']
      user.username = req.body['message[from][username]']
      user.room = chat_id
      @receive new TextMessage user, text
      res.end()

    app.post '/webhook', (req, res) =>
      console.log(req.body)
      chat_id = req.body.user.room
      # Get username
      user_name = req.body.user.first_name + " " + req.body.user.last_name]
      command = req.body.command
      @robot.brain.set 'log_id_' + chat_id, new Date().getUTCMilliseconds();
      user = @userForId chat_id, name: user_name, room: chat_id
      console.log("Webhook received from " + user_name + " with command:" )
      console.log(command)
      user.service = "webhook"
      user.first_name = req.body.user.first_name
      user.last_name = req.body.user.last_name
      user.username = req.body.user.username
      user.room = chat_id
      @receive new TextMessage user, text
      res.end()

    @emit 'connected'

exports.use = (robot) ->
  new MultiAdapter robot
