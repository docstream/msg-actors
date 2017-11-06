
MAILGUN_KEY = process.env.MAILGUN_KEY

unless MAILGUN_KEY
  console.error " Set MAILGUN_KEY !"
  process.exit 1

auth = "api:#{MAILGUN_KEY}"

defaultURL = "https://#{auth}@api.mailgun.net/v3/readin.no/messages"

MAILGUN_URL = process.env.MAILGUN_URL or defaultURL

console.log "MAILGUN_URL: #{MAILGUN_URL}\n"

module.exports = MAILGUN_URL