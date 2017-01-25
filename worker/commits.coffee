AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'

assert = require 'assert'
path = require 'path'
gitlab = (require '../gitlab-init2')

assert gitlab.urls.base, "gitlab.urls.base empty!"

axios_ = require 'axios'
axios = axios_.create {
  baseURL: gitlab.urls.base
  timeout: 9000
}
rabbitJs = require 'rabbit.js'
_ = require 'lodash'
H = require 'highland'

qName = path.basename __filename, '.coffee'
machineName = require("os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"
pubName = "amq.topic"
pubKeyPrefix = "gitlab.#{qName.replace /s$/,''}."

context = rabbitJs.createContext AMQP_URL
console.log "Worker [[#{workerID}]] starting, PUBing back into [[#{pubName}]]"

# ----------------------------------------
#      g l u e
# ----------------------------------------

# NOTE Schema ref in schemas DIR

serialize = (obj) ->
  new Buffer (JSON.stringify obj)

# Fully Qualified Book Id
unwrapFQBI = (body) ->
  body.EpubId = body.EpubId.replace /^\// , ''
  body.FQBI = body.Workspace + "__epub." + body.EpubId
  body

# PROMISE !
lookupProject = (body) ->
  
  console.log "Checking OWNED projects for [#{body.Workspace}] ..."

  axios.get gitlab.urls.ownedProjects,
    headers: (gitlab.headers body.Workspace)
  .then (resp) ->
    ps = resp.data
    console.log "Gitlab projects found: #{ps.length} x"
    project = _.find ps, (p)-> p.name==body.FQBI
    body.gitlab = { project: project }
    Promise.resolve body
  .catch (err) ->
    console.error "rest1: outch!"
    err.body = body
    Promise.reject err

# PROMISE !
postCommit = (body) ->

  # schema !! for external μs's :
  commitMsg =
    appClass: "editor"
    user:
      displayName: body.UserName
      email: body.UserEmail
    files: _.map body.Actions,(a) -> { action:a.action, path:a.file_path }
    workerId: workerID
    msgId: body.JobId

  url = (gitlab.urls.commits body.gitlab.project.id)
  
  console.log "POSTing to [#{url}] ..."

  actions_ = _.map body.Actions,(a) ->
    if a.content
      a.encoding = 'base64'
    a

  axios.post url,
    headers: (gitlab.headers body.Workspace)
    data:
      # https://docs.gitlab.com/ce/api/commits.html#create-a-commit-with-multiple-files-and-actions 
      branch_name: 'master'
      commit_message: (JSON.stringify commitMsg)
      actions: actions_
  .then (resp) ->
    console.log "POST resp-status #{resp.status}"
    Promise.resolve body
  .catch (err) ->
    console.error "rest2: outch! "
    err.body = body
    Promise.reject err
  
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
    id : body.JobId
    domain: body.Workspace
    bookId: body.EpubId
    files: _.map body.Actions,(a) -> { action:a.action, path:a.file_path }
    FQBI: body.FQBI
    workerID : workerID
    status: "SUCCESS"

  @publish "#{pubKeyPrefix}success" , serialize msg
  body

# [this] MUST be a connected PUB socket !
publishError = (err,push) ->
  console.log "error msg to QUEUE:", err.message
  msg =
    id : err.body.JobId
    domain: err.body.Workspace
    bookId: err.body.EpubId
    files: _.map body.Actions,(a) -> { action:a.action, path:a.file_path }
    FQBI: err.body.FQBI
    workerID: workerID
    status: "ERROR"
    errMsg: err.message

  @publish "#{pubKeyPrefix}error" , serialize msg
  push err

# not all well
# [this] must be worker socket (ctx)
ackAfterErr = (err) ->
  console.error "!FAILED [#{workerID}] now ACKing ", err.body.id
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
  # sub.connect pubName,'#', ->
  #   console.log "〉SUB # debugger [#{pubName}] listening..."
  #   sub.setEncoding 'utf8'
  #   H sub
  #     .each (message) ->
  #       console.info " {SUB msg} #{pubName} (debug) ::: ",message

  pub.connect pubName, ->
    console.log "〉PUB [#{pubName}] ready..."

    wrk.connect qName, ->
      wrk.setEncoding 'utf8'
      console.log "〉WORKER [#{qName}] listening..."
          
      # --------------- main chain -----------------
      H wrk
        .doto  -> console.log "new MSG.."
        .map JSON.parse
        .doto (bodyParsed) -> console.log "Keys: ", (_.keys bodyParsed).join '/'
        .map unwrapFQBI
        .map lookupProject
        .flatMap H # cast Promise-back-to-stream
        .map postCommit
        .flatMap H # cast Promise-back-to-stream
        .map (ack.bind wrk)
        .errors (publishError.bind pub)
        .errors (ackAfterErr.bind wrk)
        .each (publishSuccess.bind pub)
