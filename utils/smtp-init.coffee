# SMTP libs
nodemailer = require 'nodemailer'
smtpTransport = require 'nodemailer-smtp-transport'

SMTP_HOST = process.env.SMTP_HOST or 'smtp.mailgun.org'
SMTP_USER = process.env.SMTP_USER 
SMTP_PWD = process.env.SMTP_PWD

console.log "SMTP_HOST: #{SMTP_HOST}"

unless SMTP_USER and SMTP_PWD
  console.error " Set SMTP_USER/SMTP_PWD !"
  process.exit 1


# new Nodemailer instance
module.exports = sender = ->
  conf =
    host: SMTP_HOST
    secure: true
    direct: false
    auth:
      user: SMTP_USER
      pass: SMTP_PWD
  #console.dir conf
  nodemailer.createTransport (smtpTransport conf)
