# gitlab-workerS

nodejs queue workers/actors

always set AMQP_URL env (default = amqp://127.0.0.1:5672)

 - commits.coffee; updating gitlab w content from ED
 	
    # need G_TOKEN_* env(s) + GITLAB_URL (endpoint)

    $ G_TOKEN_1=demo.readin.no=myPersonalToken&yyy.example.com=anotherTOKEN

    # or

    $ G_TOKEN_2={\"jjf.readin.no\":\"anotherToken\", ... }


 - emails.coffee; passing-on email jobs to mailgun

    # need MAILGUN_TOKEN_* env(s)

## PREPHASE

Se pack-ed

## start rabbitmq OG en spesifik worker

    # start en RABBITMQ på port 5672 

    $ docker-compose -f d-c.rabbit.yml up
    
    $ export AMQP_URL=amqp://127.0.0.1:5672

    $ coffee worker/stuff.coffee

    $ docker run -ti msg-actors worker/stuff.coffee

## TODO

tester
