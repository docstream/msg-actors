AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

path = require 'path'
gitlab = require '../init-gitlab'
rabbitJs = require 'rabbit.js'
_ = require 'lodash'
H = require 'highland'

qName = path.basename __filename, '.coffee'
machineName = require("os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"
pubName = "amq.topic"

context = rabbitJs.createContext AMQP_URL

console.log "Worker [[#{workerID}]] starting, PUBing back into [[#{pubName}]]"


# ----------------------------------------
#
#      g l u e
#
# ----------------------------------------

# NOTE Schema ref in schemas DIR
#   ed/src/main/java/no/ds/common/io/QPersistor.java#putContent()


serialize = (obj) ->
  new Buffer (JSON.stringify obj)

unwrapBase64Content = (body) ->
  body.content = (new Buffer body.content, 'base64').toString()
  body

unwrapBookId = (body) ->
  body.bookId = _.take (body.title.split '/')
  body.filepath = _.tail (body.title.split '/')
  body

# Fully Qualified Book Id
unwrapFQBI = (body) ->
  body.FQBI = body.domain + "__epub." + body.bookId
  body

# async
# [this] must be bound to gitlab-client
lookupProject = (body,cb) ->
  @projects.list {}, (err,projects) ->
    if err
      console.err "! GITLAB err", err
      # FIXME Make a new Stream ?
      err.msgId = body.id
      cb err
    else
      project = _.find projects, (p)-> p.name==body.FQBI
      if project
        body.gitlab =
          project : project
        cb null, body
      else
        err = new Error "cannot find an GITLAB id for projectName #{body.FQBI}"
        err.msgId = body.id
        cb err

# async 
# [this] must be bound to gitlab-client
update = (body,cb) ->
  @repositoryFiles.update
    id: body.gitlab.project.id
    file_path: body.filepath
    branch_name: "master"
    # encoding: "base64" not working?
    content: body.content
    commit_message: "
      User: '#{body.userName}'. File: '#{body.filepath}'. Worker: [[#{workerID}]]\n\n
      Message uuid: '#{body.id}'
      "
  , (err,resp) ->
    if err
      console.error "!GITLAB update err;",err
      err.msgId = body.id
      err.domain = body.domain
      cb err
    else
      console.log "resp is",resp
      cb null,body
  
# all well
# [this] must be worker socket (ctx)
ack = (body) ->
  console.log "SUCCESS [#{workerID}] now ACKing ",body.id
  @ack()
  body
  

# [this] MUST be a connected PUB socket !
publishSuccess = (body) ->

  # NB Here we pick each prop explicitly to state CLEARLY
  # the schema for SUBscribers

  msg =
    id : body.id
    domain: body.domain
    bookid: body.bookid
    filepath: body.filepath
    workerID : workerID
    FQBI: body.FQBI
    status: "SUCCESS"

  @publish 'update.gitlab' , serialize msg
  body

# [this] MUST be a connected PUB socket !
publishError = (err,push) ->

  msg =
    id : err.msgId
    domain: err.domain
    workerID: workerID
    status: "ERROR"
    errMsg: err.message

  @publish 'update.gitlab' , serialize msg
  push err

# not all well
# [this] must be worker socket (ctx)
ackAfterErr = (err) ->
  console.error "!FAILED [#{workerID}] now ACKing ",err.msgId
  @ack()


#---------------------------------------
#   events
#=======================================

# FIXME close all context if SIGINT

context.on 'error', (err) =>
  console.error 'AMQP CTX err;',err

  if err.code == 'ECONNREFUSED'
    console.error "ABORTING"
    process.exit 1 # make sure we can restart AT ONCE
  else
    console.log "code :", err.code
    

context.on 'ready', ->

  console.log "AMQP: #{AMQP_URL} ok, creating sockets:"

  wrk = context.socket 'WORKER'
  pub = context.socket 'PUB',noCreate:yes
  sub = context.socket 'SUB',noCreate:yes

  # debug socket
  sub.connect pubName,'#', ->
    console.log "〉SUB # debugger [#{pubName}] listening..."
    sub.setEncoding 'utf8'
    H sub
      .each (message) ->
        console.info " {SUB msg} #{pubName} (debug) ::: ",message

  pub.connect pubName, ->
    console.log "〉PUB [#{pubName}] ready..."

    wrk.connect qName, ->
      wrk.setEncoding 'utf8'
      console.log "〉WORKER [#{qName}] listening..."

      gitlab workerID, (gClient) ->

          # --------------- main chain -----------------
          H wrk
            .map JSON.parse
            .map unwrapBase64Content
            .map unwrapBookId
            .map unwrapFQBI
            .flatMap H.wrapCallback (lookupProject.bind gClient)
            .flatMap H.wrapCallback (update.bind gClient)
            .map (ack.bind wrk)
            .errors (publishError.bind pub)
            .errors (ackAfterErr.bind wrk)
            .each (publishSuccess.bind pub)
