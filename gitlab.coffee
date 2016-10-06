_ = require "lodash"
gitlab = require 'node-gitlab'

module.exports = (cb) ->

  GITLAB_URL = process.env.GITLAB_URL or 'http://localhost:10080/api/v3'
  GITLAB_TOKEN = process.env.GITLAB_TOKEN

  unless GITLAB_TOKEN
    console.error "no env GITLAB_TOKEN set. aborting"
    process.exit 1

  console.info "GITLAB: #{GITLAB_URL} | #{GITLAB_TOKEN}"


  # output
  gClient = gitlab.create
    api: GITLAB_URL
    privateToken: GITLAB_TOKEN
  
  # init
  console.log "- GITLAB Testing starting ..."
  
  gClient.projects.list {}, (err,ps) ->
    if err
      console.error "GITLAB connect test ERR"
      console.error err
      cb err
    else
      ps_ = _.map ps, (p) -> { id:p.id, name:p.name }
      console.log " \\__ ok pid:%d",process.pid ,ps_
      cb null,gClient




