{Adapter,TextMessage} = require 'hubot'

port = parseInt process.env.HUBOT_SOCKETIO_PORT or 9090
console.log("socket.io server on port " + port);

io = require('socket.io').listen port

express = require('express')
app = express()

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

    @emit 'connected'

exports.use = (robot) ->
  new MultiAdapter robot
