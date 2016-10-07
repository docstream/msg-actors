AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

path = require 'path'
gitlab = require '../init-gitlab'
rabbitJs = require 'rabbit.js'
_ = require 'lodash'
H = require 'highland'

qName = path.basename __filename, '.coffee'
machineName = require("os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"
pubName = "feedback:v1"

context = rabbitJs.createContext AMQP_URL

console.log "Worker [[#{workerID}]] starting"


# ----------------------------------------
#
#      g l u e
#
# ----------------------------------------

serialize = (obj) ->
  new Buffer (JSON.stringify obj)

unwrapBase64Content = (body) ->
  body.contentDecoded = (new Buffer body.content, 'base64').toString()
  delete body.content # no need for that
  body

unwrapBookId = (body) ->
  body.bookId = _.take (body.title.split '/')
  body.filepath = _.tail (body.title.split '/')
  body

# Fully Qualified Book Id
unwrapFQBI = (body) ->
  body.FQBI = body.domain + "__" + body.bookId
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
    encoding: "UTF-8"
    content: body.contentDecoded
    commit_message: "user #{body.userName}. file #{body.filepath}. worker [[#{workerID}]]"
  , (err,resp) ->
    if err
      console.error "!GITLAB update err;",er
      cb err
    else
      console.log "resp is",resp
      cb null,body
  
# all well
# [this] must be worker socket (ctx)
ack = (body) ->
  console.log "[#{workerID} now ACKing ",body.id
  @ack()
  body

# [this] MUST be a connected PUB socket !
publishSuccess = (body) ->
  @publish workerID , serialize
    id : body.id
    workerID : workerID
    status: "HAPPY"
  body

# [this] MUST be a connected PUB socket !
publishError = (err,push) ->
  @publish workerID, serialize
    id : err.msgId
    workerID: workerID
    status: "ERROR"
    errMsg: err.message




#---------------------------------------
#   events
#=======================================


context.on 'error', (err) ->
  console.error 'AMQP CTX err;',err

context.on 'ready', ->

  console.log "AMQP: #{AMQP_URL} ok, creating sockets:"

  wrk = context.socket 'WORKER'
  pub = context.socket 'PUB'
  sub = context.socket 'SUB'

  # debug socket
  sub.connect pubName,'*', ->
    console.log "〉SUB [#{pubName}] listening..."
    sub.setEncoding 'utf8'
    H sub
      .each (message) ->
        console.info " {SUB msg} #{pubName} (debug) ::: ",message

  pub.connect pubName, ->
    console.log "〉PUB [#{pubName}] ready..."

    wrk.connect qName, ->
      wrk.setEncoding 'utf8'
      console.log "〉WORKER [#{qName}] listening..."

      gitlab workerID, (err,gClient) ->

        if err
          throw err
        else
          # --------------- main chain ----------------------
          H wrk
            .map JSON.parse
            .map unwrapBase64Content
            .map unwrapBookId
            .map unwrapFQBI
            .flatMap H.wrapCallback (lookupProject.bind gClient)
            .flatMap H.wrapCallback (update.bind gClient)
            .errors (publishError.bind pub)
            .map (ack.bind wrk)
            .each (publishSuccess.bind pub)
