
MAILCHIMP_API_KEY = process.env.MAILCHIMP_API_KEY

unless MAILCHIMP_API_KEY
  console.error " Set MAILCHIMP_API_KEY !"
  process.exit 1

module.exports = MAILCHIMP_API_KEY
