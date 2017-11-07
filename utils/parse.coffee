qs = require 'querystring'
_ = require 'lodash'


module.exports = parse = (rawdata,tokens,suffix) ->

  try
    if rawdata.trim().match /^\{/
      console.log "  \\_ JSON.parsing #{suffix} .."
      _.assignIn tokens,(JSON.parse rawdata)
    else
      console.log "  \\_ QS.parsing #{suffix} .."
      _.assignIn tokens,(qs.parse rawdata.trim())
  catch err
    console.error "PARSE-ERR:\n",err

  tokens