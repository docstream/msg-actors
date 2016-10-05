_ = require "lodash"
path = require 'path'
hare = require 'hare'
gitlab = require 'node-gitlab'

workerName = path.basename __filename, '.coffee'

AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1'
GITLAB_URL = process.env.GITLAB_URL or 'http://localhost:10080/api/v3'
GITLAB_TOKEN = process.env.GITLAB_TOKEN

unless GITLAB_TOKEN
  console.error "no env GITLAB_TOKEN set. aborting"
  process.exit 1

console.info "[#{workerName}] starting, pid:#{process.pid}, rabbit:#{AMQP_URL}, gitlab:#{GITLAB_URL}"

# input
broker = hare AMQP_URL
# output
gClient = gitlab.create
  api: GITLAB_URL,
  privateToken: GITLAB_URL

rabbitLog = broker.pubSub "gitlab-events"
rabbitLog.publish
  worker:workerName
  pid:process.pid
  msg:"init ok"

# queue [updates] consumer/worker
(broker.workerQueue "#{workerName}s").subscribe (msg, headers, deliveryInfo, cb) ->
  console.log "msg", msg
  cb()


