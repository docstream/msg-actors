reqGlob = require 'require-glob'
_ = require 'lodash'

AMQP_URL = process.env.AMQP_URL or "amqp://127.0.0.1"

(reqGlob './workers/*')
  .then (workers) ->
    console.warn "ZERO workers !" if (_.keys workers).length == 0
    _.each workers, (w) ->
      console.log "starting [#{w.id}] worker."
      w AMQP_URL
  .catch (err) ->
    console.error "Err;",err
