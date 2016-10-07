FROM node:4.4.4

# NB! Use LTS version ALWAYS
RUN npm --global i npm@2.15.5 --silent

WORKDIR /app

ADD package.json /app

RUN npm i --silent

ADD . /app
# FIXME RUN npm run test
