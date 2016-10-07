# gitlab-worker

nodejs queue worker, updating gitlab w content

## PREPHASE

Se pack-ed

## start gitlab OG en spesifik worker

    docker-compose -f d-c.gitlab.yml up # en gang
    # start en RABBITMQ på port 5672 (ed sin docker-compose feks)
    . _GITLAB.env # Denne setter env GITLAB_TOKEN
    # andre envs er 
    #  GITLAB_URL=http://localhost:10080/api/v3
    #  AMQP_URL=amqp://127.0.0.1:5672 
    coffee worker/updates.coffee

## TODO

tester
