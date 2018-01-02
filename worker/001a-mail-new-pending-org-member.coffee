 # FIXME add as POSThook in above addEnduserToOrg()

      # model =
      #   ownerEmail:req.user.name or '[owner]'
      #   org:org
      #   pMemberEmail:pMemberEmail
      #   callbackUrl: "#{req.protocol}://#{req.host}#{_links.auth.login.expand {}}"
      #   hostname: req.host #new Q2-2016

      # render "mails/account/new-pending-member.yml", model, (err, html) ->
      #   if err
      #     publishMsg 'mail', ( errMsgBody "#{__filename}::render()",err )
      #   else
      #     job =
      #       from: "<noreply@readin.no>"
      #       to: "#{pMemberEmail} <#{pMemberEmail}>"
      #       subject: "Du ble lagt til i en organisasjon hos #{req.host}"
      #       html: base64 html

      #     publishMsg 'mail', job