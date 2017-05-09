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

app.listen 3000, =>
  console.log('HTTP server on port 3000')

var TelegramBot = require('node-telegram-bot-api');
#Telegram bot token (given when you create a new bot using the BotFather);
var telegramBot = new TelegramBot(process.env.TELEGRAM_TOKEN, {polling: false});

class MultiAdapter extends Adapter

  constructor: (@robot) ->
    @sockets = {}
    super @robot

  send: (user, strings...) ->
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
        @receive new TextMessage user, data.message

      socket.on 'disconnect', =>
        console.log("User disconected (" + socket.id + ")")
        @robot.brain.remove 'log_id_' + socket.id
        delete @sockets[socket.id]

    app.post '/telegram-api', (req, res) =>
      console.log(req.param('message'))

    @emit 'connected'

exports.use = (robot) ->
  new MultiAdapter robot
