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

  msg = (f) -> " ;;;; #{f} undef"

  assert body.id, msg 'id'
  assert body.wrkspc, msg 'wrkspc'
  # --------------------------------------
  assert body.from, msg 'from'
  assert body.chunkId, msg 'chunkId'
  console.log "Validated body ok"
  body


mailchimpPost = (body) ->

  rp
    json: yes # response JSONParsed
    url: mailgunURL
    method: 'post'
    qs: body

  .then (respBody) ->
    console.log "POST-RESP => "
    console.log " \\_ id:",respBody.id
    console.log " \\_ message:",respBody.message
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
    stack : err.stack.toString()

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
    payload: body

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
        .map mailchimpPost
        .flatMap H
        .doto (b) ->
          wrk.ack()
          console.log "SUCCESS [#{workerID}] ACK'd:", b.id
        .errors (publishError.bind pub)
        .errors (err) ->
          console.error err.stack
          wrk.ack()
          # no push = ende
        .each (publishSuccess.bind pub)
