parse = require './parse'
_ = require 'lodash'


api_keys = {}

console.log "Will now loop each MAILCHIMP_KEY_* env(s) .."

_.forEach process.env, (val,key) ->
  if key.match /^MAILCHIMP_KEY_/
    console.log "-+--> Found env [#{key}] :"
    suffix = (key.replace /^MAILCHIMP_KEY_/,'').toLowerCase()
    console.log "SUFFIX:: ", suffix
    console.log "val:: ", val
    console.log "api_keys:: ", api_keys
    api_keys = parse val, api_keys, suffix


console.log "-----------------------------"
console.log api_keys

if (_.keys api_keys).length == 0
  console.error "NO MAILCHIMP API KEYS FOUND! Aborting"
  process.exit 1


module.exports = (key) -> 
  api_keys[key]