
# når en allerede EKSISTERENDE blit lagt inn i en ORG ...

#  model =
#   fqdn:fqdn #DEPRECATED Q2-2016
#   hostname:req.host #new Q2-2016
#   callbackUrl: "#{req.protocol}://#{req.host}#{_links.org.edit.expand orgId:org.id}"
#   ownerEmail:req.user.name
#   org:org

# render "mails/account/new-org-member.yml", model, (err, html) ->
#   if err
#     publishMsg 'mail', ( errMsgBody "#{__filename}::render()",err )
#   else
#     job =
#       from: "<noreply@readin.no>"
#       to: "#{user.fullName} <#{user.name}>"
#       subject: "Du ble lagt til i en organisasjon hos #{req.host}"
#       html: base64 html

#     publishMsg 'mail', job