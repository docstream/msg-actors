_ = require 'lodash'
qs = require 'querystring'

tokens = {}

parse = (data,suffix) ->
  try
    if data.trim().match /^\{/
      console.log "  \\_ JSON.parsing #{suffix} .."
      _.assignIn tokens,(JSON.parse data)
    else
      console.log "  \\_ QS.parsing #{suffix} .."
      _.assignIn tokens,(qs.parse data.trim())
  catch err
    console.error "PARSE-ERR:\n",err

console.log "Will now loop each G_TOKEN_* env .."
_.forEach process.env, (val,key) ->
  if key.match /^G_TOKEN_/
    console.log "-+--> Found env [#{key}] :"
    suffix = (key.replace /^G_TOKEN_/,'').toLowerCase()
    parse val,suffix


if (_.keys tokens).length == 0
  console.error "NO GITLAB TOKENS FOUND! Aborting"
  process.exit 1
      
console.log "GITLAB tokens:"
console.dir tokens

GITLAB_URL = process.env.GITLAB_URL or 'http://localhost:10080/api/v3'
console.log "Gitlab baseURL: #{GITLAB_URL}"

module.exports =
  headers: (key) ->
    "PRIVATE-TOKEN" : tokens[key]
    "Content-Type" : "application/json"
  urls:
    base: GITLAB_URL
    commits : (pNo) ->
      "/projects/#{pNo}/repository/commits"
    ownedProjects : "/projects/owned"

