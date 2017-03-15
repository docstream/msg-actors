AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'
fs = require 'fs'
assert = require 'assert'
path = require 'path'
gitlab = (require '../gitlab-init2')
rp = require 'request-promise'
rabbitJs = require 'rabbit.js'
_ = require 'lodash'
H = require 'highland'

assert gitlab.urls.base, "gitlab.urls.base empty!"

qName = path.basename __filename, '.coffee'
machineName = require("os").hostname()
workerID = "#{qName}:#{machineName}:#{process.pid}"
pubName = "amq.topic"
pubKeyPrefix = "gitlab.#{qName.replace /s$/,''}."

context = rabbitJs.createContext AMQP_URL
console.log "Worker [[#{workerID}]] starting, PUBing back into [[#{pubName}]]"

# NOTE Schema ref in schemas DIR
# ----------------------------------------
#      g l u e
# ----------------------------------------

# util
request = (key,opts) ->
  assert opts.url, "need url in opts!"
  mixin =
    json: yes # parse resp
    headers:  (gitlab.headers key)
    url: gitlab.urls.base + opts.url
    # FIXME loop and/or filter
    qs:
      per_page:100

  delete opts.url
  
  rp _.assignIn mixin,opts

# util
serialize = (obj) ->
  new Buffer (JSON.stringify obj)

# Fully Qualified Book Id
unwrapFQBI = (body) ->
  body.EpubId = body.EpubId.replace /^\// , ''
  body.FQBI = body.Workspace + "__epub." + body.EpubId
  console.log "appending FQBI: #{body.FQBI} to msg-body"
  body

# gives us better logs
isTokenPresent = (body) ->
  if gitlab.token body.Workspace
    body
  else
    throw new Error "!!! NO TOKEN ; This Worker cannot handle wrkspc [#{body.Workspace}]"


# PROMISE !
lookupProject = (body) ->
  
  console.log "Checking OWNED projects for [#{body.Workspace}] ..."

  request body.Workspace,
    url: gitlab.urls.ownedProjects
  .then (respBody) ->
    ps = respBody
    console.log "Gitlab projects found: #{ps.length} x"
    project = _.find ps, (p)-> p.name==body.FQBI
    assert project, "Project not FOUND !"
    body.gitlab = { project: project }
    console.log "Project ID to commit into is no.#{body.gitlab.project.id}"
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

  data =
    branch_name: 'master'
    commit_message: (JSON.stringify commitMsg)
    actions: actions_

  # debug;
  # data_ = JSON.stringify data,null,' '
  # fs.writeFileSync '.lastbody.json', data_, 'utf-8'

  request body.Workspace,
    url: url
    method: 'post'
    body: data
      # https://docs.gitlab.com/ce/api/commits.html
      #         #create-a-commit-with-multiple-files-and-actions 
  .then (respBody) ->
    console.log "GITLAB Stats => ",respBody.stats
    Promise.resolve body
  .catch (err) ->
    console.error "rest2: outch!"
    err.body = body
    Promise.reject err
  
# all well
# [this] must be worker socket (ctx)
ack = (body) ->
  @ack()
  console.log "SUCCESS [#{workerID}] ACK'd:",body.JobId
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

  OK_R_KEY = "#{pubKeyPrefix}success"
  @publish OK_R_KEY, serialize msg
  console.log "SUCCESS pub'd to [#{pubName} + #{OK_R_KEY}] ;", msg.id
  body

# [this] MUST be a connected PUB socket !
publishError = (err,push) ->
  msg =
    id : err.body.JobId
    domain: err.body.Workspace
    bookId: err.body.EpubId
    files: _.map err.body.Actions,(a) -> { action:a.action, path:a.file_path }
    FQBI: err.body.FQBI
    workerID: workerID
    status: "ERROR"
    errMsg: err.message

  ERR_R_KEY = "#{pubKeyPrefix}error"
  @publish ERR_R_KEY, serialize msg
  console.log "ERR pub'd to [#{pubName} + #{ERR_R_KEY}] ;", err.message
  push err

# not all well
# [this] must be worker socket (ctx)
ackAfterErr = (err) ->
  @ack()
  console.error "!FAILED [#{workerID}] ACK'd:", err.body.JobId


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
    console.log " > PUB [#{pubName}] ready..."

    wrk.connect qName, ->
      wrk.setEncoding 'utf8'
      console.log " > WORKER [#{qName}] listening..."
          
      # --------------- main chain -----------------
      H wrk
        .doto  -> console.log "new MSG.."
        .map JSON.parse
        .doto (bodyParsed) -> console.log "Keys: ", (_.keys bodyParsed).join '/'
        .map isTokenPresent
        .map unwrapFQBI
        .map lookupProject
        .flatMap H # cast Promise-back-to-stream
        .map postCommit
        .flatMap H # cast Promise-back-to-stream
        .map (ack.bind wrk)
        .errors (publishError.bind pub)
        .errors (ackAfterErr.bind wrk)
        .each (publishSuccess.bind pub)
