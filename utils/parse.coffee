qs = require 'querystring'
_ = require 'lodash'

# mutates [state] w parsed object (from rawdata)
module.exports = parse = (rawdata,state,suffix) ->

  if _.isArray state
    merge = _.concat
  else
    merge = _.assignIn

  try
    if rawdata.trim().match /^\{/
      console.log "  \\_ JSON.parsing #{suffix} .."
      state = merge state, (JSON.parse rawdata)
    else
      console.log "  \\_ QS.parsing #{suffix} .."
      state = merge state, (qs.parse rawdata.trim())
  catch err
    console.error "PARSE-ERR:\n",err

  state