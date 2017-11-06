AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

_ = require 'lodash'
H = require 'highland'
rp = require 'request-promise' # mailgun
rabbitJs = require 'rabbit.js'
path = require 'path'
mailgunURL = require '../utils/mailgun-init'
rp = require 'request-promise'
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

  assert body.id, 'id undef'
  assert body.wrkspc, 'wrkspc undef'
  # --------------------------------------
  assert body.from, 'from undef'
  assert body.to, 'to undef'
  assert body.subject, 'subject undef'
  assert body.html or body.txt , 'text/html undef'
  console.log "Validated body ok"
  body

unwrapBase64 = (body) ->
  body.text = sajdhds if body.text
  body.html = sajdhds if body.html
  body

mailgunPost = (body) ->

  rp 
    json: yes # response JSONParsed
    url: mailgunURL
    method: 'post'
    qs: body

  .then (respBody) ->
    console.log "RESP => "
    console.log " \\_ id:",respBody.id
    console.log " \\_ id:",respBody.message
    body.mailgunQueue = respBody
    Promise.resolve body
  .catch (err) ->
    console.error "rest: outch!"
    err.body = body
    Promise.reject err


publishError = (err, push) ->
  ERR_R_KEY = "#{pubKeyPrefix}error"
  msg =
    body : err.body or {}
    msg : err.message
  console.log "ERR pub'd to [#{pubName} + #{ERR_R_KEY}] ;", err.message
  @publish ERR_R_KEY, serialize msg
  #wrk.ack()
  
  push err

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
          # no push = ende
        .map validate
        .doto (b) -> 
          console.log "Keys: ", (_.keys b).join ', '
          console.log " \\_ .id: #{b.id} "
          console.log " \\_ #{b.to} / #{b.subject} / #{b.wrkspc}"
        .map unwrapBase64
        .map mailgunPost
        .flatMap H
        .doto (b) ->
          wrk.ack()
          console.log "SUCCESS [#{workerID}] ACK'd:", b.id
        .errors (publishError.bind pub)
        .errors (err) ->
          wrk.ack() 
          # no push = ende
        .each (publishSuccess.bind pub)