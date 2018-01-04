# Legacy? only JJF

 # if type == 'trial'

 #    callbackPath = _links.payer['create-form'].expand
 #      authzHead: [
 #        orderData.payingAccountId
 #        orderData.prodNS
 #        orderData.prodId
 #      ].toString()
 #      tried: "/"
 #      type:type


 #    model =
 #      callbackUrl : "#{req.protocol}://#{req.host}#{callbackPath}"
 #      hostname: req.host
 #      order: orderData
 #      user: req.user

 #    render "mails/orders/created-trial.yml", model, (err,html) ->
 #      if err
 #        publishMsg 'mail', ( errMsgBody "#{__filename}::render()",err )
 #      else
 #        job =
 #          from: "<noreply@readin.no>"
 #          to: "#{req.user.fullName} <#{req.user.name}>"
 #          bcc: "<administration@readin.no>, <#{orderData.product.recepients.trial}>, <#{orderData.product.recepients.test}>"
 #          subject: "Prøvetilgang [#{req.host}], produkt #{orderData.product.title}"
 #          html: base64 html

 #        publishMsg 'mail', job