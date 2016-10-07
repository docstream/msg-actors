AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

path = require 'path'
gitlab = require '../gitlab'
rabbitJs = require 'rabbit.js'
H = require 'highland'

qName = path.basename __filename, '.coffee'
machineName = require("os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"
pubName = "feedback:v1"

context = rabbitJs.createContext AMQP_URL

console.log "Worker [[#{workerID}]] starting"


serialize = (obj) ->
  new Buffer (JSON.stringify obj)
  # new isnt FUNCTIONAL , otherwise we use H.compose

#---------------------------------------
#   events
#=======================================


context.on 'error', (err) ->
  console.error 'AMQP CTX err;',err

context.on 'ready', ->
  console.log "AMQP: #{AMQP_URL} ok"
  wrk = context.socket 'WORKER'
  pub = context.socket 'PUB'
  sub = context.socket 'SUB'

  # debug socket
  sub.connect pubName,'*', ->
    console.log "〉SUB [#{pubName}] listening..."
    sub.setEncoding 'utf8'
    H sub
      .each (x) ->
        console.info " {SUB msg} #{pubName} (debug) ::: ",x

  pub.connect pubName, ->
    console.log "〉PUB [#{pubName}] ready..."

    wrk.connect qName, ->
      wrk.setEncoding 'utf8'
      console.log "〉WORKER [#{qName}] listening..."
      gitlab workerID, (err,gClient) ->
        if err
          throw err
        else
          H wrk
            .map JSON.parse
            .map (x) ->
              x.contentDecoded = (new Buffer x.content, 'base64').toString()
              delete x.content # no need for that
              x
            .each (x) ->
              pub.publish workerID , serialize
                id : x.id
                workerID : workerID
                status: "OK"
              
              console.log x.id + " was handled from [#{workerID}]"
