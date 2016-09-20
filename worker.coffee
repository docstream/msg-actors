kue = require 'kue'
REDIS_URL = process.env.REDIS_URL or 'redis://127.0.0.1:6379'
queue = kue.createQueue redis:REDIS_URL
_ = require 'lodash'
handlers = require './handlers'

_.forEach handlers, (func,key) ->
  queue.process key, func
