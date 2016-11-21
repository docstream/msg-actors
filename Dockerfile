FROM node:4.4.4

ENV DOCKERFILE_REFRESHED 2016-17-3T10:50

# deprecated, should use user/pwd
ENV GITLAB_TOKEN aBBa+1/234+etcetcetc

# connect to /session and grab TOKEN
ENV GITLAB_USER root
ENV GITLAB_PWD passord16

ENV GITLAB_URL http://gitlab/api/v3

# NB! Use LTS version ALWAYS
RUN npm --global i npm@2.15.5 --silent

WORKDIR /app

ADD package.json /app

RUN npm i --silent

ADD . /app
# FIXME RUN npm run test

CMD ./node_modules/.bin/coffee worker/updates.coffee
