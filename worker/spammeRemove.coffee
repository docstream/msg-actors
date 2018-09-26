AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

_ = require 'lodash'
H = require 'highland'
rp = require 'request-promise' # mailgun
rabbitJs = require 'rabbit.js'
path = require 'path'
chimpKeys = require '../utils/mailchimp-init'
rp = require 'request-promise'
assert = require 'assert'
url = require 'url'
md5 = require 'md5'
Mailchimp = require 'mailchimp-api-v3'

qName = path.basename __filename, '.coffee'
machineName = (require "os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"

console.log "AMQP_URL .host ===>", (url.parse AMQP_URL).host
context = rabbitJs.createContext AMQP_URL

pubName = "amq.topic"
pubKeyPrefix = "#{qName}."

console.log "Worker [[#{workerID}]] starting, PUBing back into [[#{pubName}]]"



# Returning existing or created list
mailchimpList = (mailchimp, body, cb) ->
  # Gets all lists
  mailchimp.request {
    method: 'get'
    path: "/lists?count=1000000"
  }, (err, result) ->
    if err
      cb err
    else
      listExist = _.find result.lists, (list) -> list.name == body.ebook
      if listExist # List exist for ebook
        cb null, listExist
      else
        cb "NOT FOUND"



# Subscribes to list
removeUserFromList = (body, cb) ->
  mailchimp = new Mailchimp (chimpKeys body.wrkspc)
  hashedEmail = md5 body.email

  mailchimpList mailchimp, body, (err, res) ->
    console.log err
    console.log res
    if err
      cb err
    else
      mailchimp.request {
        method: 'delete'
        path: "/lists/#{res.id}/members/#{hashedEmail}"
      }, (err2, result2) ->
        if err2
          cb err2
        else
          cb null, result2


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
        .doto (b) ->
          console.log "Keys: ", (_.keys b).join ', '
          console.log " \\_ .id: #{b.id} "
          console.log " \\_ #{b.wrkspc}"
        .flatMap (H.wrapCallback removeUserFromList)
        .doto (b) ->
          wrk.ack()
          console.log "SUCCESS [#{workerID}] ACK'd:", b.id
        .errors (publishError.bind pub)
        .errors (err) ->
          console.error err.stack
          wrk.ack()
          # no push = ende
        .each (publishSuccess.bind pub)
