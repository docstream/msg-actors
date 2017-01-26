fs = require 'fs'
rp = require 'request-promise'

data = fs.readFileSync 'post-body.debug.json'
data_ = JSON.parse data

rp
  url: 'http://localhost:10080/api/v3/projects/4/repository/commits'
  method: 'post'
  body: data_
  json:yes
  headers:
    "PRIVATE-TOKEN" : "wx2w3DgAJQDTrzPKr3Dk"
.then (reqBody) ->
  console.dir reqBody
.catch (err) ->
  console.error "OO",err

