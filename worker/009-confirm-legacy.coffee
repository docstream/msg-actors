              # flyttet fra account.coffee

              # brukes i gml login ?? VERRY DEPRECATED since AUTH0 has all this !!!

              # see SMUTTHULLET

              # FIXME move into webshop aka OR+A
              # callbackPath = _links.auth['verify-nonverified'].expand
              #     euId: user.id
              #     vId: user.verifications[user.verifications.length-1].id
              #     tried: triedHref

              # model =
              #   hostname: req.host
              #   callbackUrl: "#{req.protocol}://#{req.host}#{callbackPath}"

              # render "mails/account/verification.yml", model, (err,html) ->
              #   if err
              #     publishMsg 'mail', ( errMsgBody "#{__filename}::render()",err )
              #   else
              #     body =
              #       from: "<noreply@readin.no>"
              #       to: "#{user.fullName} <#{user.email}>"
              #       subject: "Bekreft login for #{req.host} konto"
              #       html: base64(html)