var winston = require('winston');
winston.emitErrs = true;
winston.setLevels(winston.config.syslog.levels);

var winstonLog = new winston.Logger({
    transports: [
        new winston.transports.File({
            level: 'info',
            filename: 'beta-log.log',
            handleExceptions: true,
            json: true,
            maxsize: 5242880, //5MB
            maxFiles: 5,
            colorize: false
        }),
        new winston.transports.Console({
            level: 'debug',
            handleExceptions: true,
            json: false,
            colorize: true
        })
    ],
    exitOnError: false
});



var log = function(robot, level, msg, data){
  //console.log("logging data...")
  winstonLog.log(level, msg, data);
  //socket = robot.adapter.sockets[Object.keys(robot.adapter.sockets)[0]]
  var sockets = robot.adapter.sockets
  if(sockets){
    for(socket_name in sockets) {
      if(sockets.hasOwnProperty(socket_name)) {
          var socket = sockets[socket_name];
          socket.emit('log', { message: msg, data: data, level: level})
      }
    }
  }
}

module.exports = log;
module.exports.winston = winstonLog;
