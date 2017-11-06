
MAILGUN_KEY = process.env.MAILGUN_KEY

unless MAILGUN_KEY
  console.error " Set MAILGUN_KEY !"
  process.exit 1

auth = "api:#{MAILGUN_KEY}"

MAILGUN_URL = process.env.MAILGUN_URL or "https://#{auth}@api.mailgun.net/v3/readin.no/messages"

console.log "MAILGUN_URL: #{MAILGUN_URL}\n"

# new Mail instance
module.exports = MAILGUN_URL