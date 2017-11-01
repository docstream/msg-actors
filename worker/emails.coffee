AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

_ = require 'lodash'
H = require 'highland'
rp = require 'request-promise' # mailgun
rabbitJs = require 'rabbit.js'
path = require 'path'


qName = path.basename __filename, '.coffee'
machineName = (require "os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"


context = rabbitJs.createContext AMQP_URL

pubName = "amq.topic"
pubKeyPrefix = "#{qName}."

console.log "Worker [[#{workerID}]] starting, PUBing back into [[#{pubName}]]"


# [this] MUST be a connected PUB socket !
publishSuccess = (body) ->

  # NB Here we pick each prop explicitly to state CLEARLY
  # the schema for SUBscribers

  msg =
    id : body.JobId # ?
    domain: body.Workspace # ?
    workerID : workerID
    status: "SUCCESS"

  OK_R_KEY = "#{pubKeyPrefix}success"
  @publish OK_R_KEY, serialize msg
  console.log "SUCCESS pub'd to [#{pubName} + #{OK_R_KEY}] ;", msg.id
  body

context.on 'ready', ->

  console.log "AMQP: #{AMQP_URL} ok, creating sockets:"

  wrk = context.socket 'WORKER'
  pub = context.socket 'PUB', noCreate:yes

  pub.connect pubName, ->
    console.log " > PUB [#{pubName}] ready..."
    
    wrk.connect qName, ->
      wrk.setEncoding 'utf8'
      console.log " > WORKER [#{qName}] listening..."
          
      # --------------- main chain -----------------
      H wrk
        .doto  -> console.log "new MSG.."
        .map JSON.parse
        .errors (err) ->
          console.error "ACKing trashy JSON. "
          # TODO;  publish warning to [#{pubName}] 
          wrk.ack()
          # stop
        .doto (b) -> 
          console.log "Keys: ", (_.keys b).join '/'
          console.log " \\_ User: #{b.to} / subject: #{b.subject}"
        .each (publishSuccess.bind pub)
       
