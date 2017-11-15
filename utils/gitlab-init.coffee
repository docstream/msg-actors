parse = require './parse'
_ = require 'lodash'

GITLAB_URL = process.env.GITLAB_URL or 'http://localhost:10080/api/v4'
console.log "Gitlab endpoint: #{GITLAB_URL}"

tokens = {}

console.log "Will now loop each G_TOKEN_* env(s) .."
_.forEach process.env, (val,key) ->
  if key.match /^G_TOKEN_/
    console.log "-+--> Found env [#{key}] :"
    suffix = (key.replace /^G_TOKEN_/,'').toLowerCase()
    tokens = parse val,tokens,suffix


if (_.keys tokens).length == 0
  console.error "NO GITLAB TOKENS FOUND! Aborting"
  process.exit 1
      
# console.log "GITLAB tokens:"
# console.dir tokens


module.exports =
  token: (key) -> tokens[key]
  headers: (key) ->
    "PRIVATE-TOKEN" : tokens[key]
    "Content-Type" : "application/json"
  urls:
    base: GITLAB_URL
    commits : (pNo) ->
      "/projects/#{pNo}/repository/commits"
    projects : "/projects"

