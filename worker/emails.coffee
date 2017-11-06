AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

_ = require 'lodash'
H = require 'highland'
rp = require 'request-promise' # mailgun
rabbitJs = require 'rabbit.js'
path = require 'path'
smtpMailer = require '../utils/smtp-init'
assert = require 'assert'


qName = path.basename __filename, '.coffee'
machineName = (require "os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"


context = rabbitJs.createContext AMQP_URL

pubName = "amq.topic"
pubKeyPrefix = "#{qName}."

console.log "Worker [[#{workerID}]] starting, PUBing back into [[#{pubName}]]"

# util
serialize = (obj) ->
  new Buffer (JSON.stringify obj)

validate = (body) ->
  assert body.id
  assert body.wrkspc
  assert body.from
  assert body.to
  assert body.subject
  assert body.html
  body

# main FUNC
smtp = H.wrapCallback smtpMailer.sendMail





# [this] MUST be a connected PUB socket !
publishSuccess = (body) ->

  # NB Here we pick each prop explicitly to state CLEARLY
  # the schema for SUBscribers

  msg =
    id : body.id # ?
    wrkspc: body.wrkspc # ?
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
        .map validate
        .doto (b) -> 
          console.log "Keys: ", (_.keys b).join '/'
          console.log " \\_ .id >> #{b.id} "
          console.log " \\_ .to: #{b.to} / .subject: #{b.subject} / .wrkspc: #{b.wrkspc}"
        .map smtp
        .doto (b) ->
          wrk.ack()
          console.log "SUCCESS [#{workerID}] ACK'd:", b.id
        .errors (err, push) ->
          ERR_R_KEY = "#{pubKeyPrefix}error"
          msg =
            body : err.body
            msg : err.message
          pub.publish ERR_R_KEY, serialize msg
          push err
          wrk.ack()
          console.log "ERR pub'd to [#{pubName} + #{ERR_R_KEY}] ;", err.message
        .each (publishSuccess.bind pub)
       
