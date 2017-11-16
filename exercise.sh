#!/usr/bin/env bash

export G_TOKEN_1=svada.com=blargh
./node_modules/.bin/coffee worker/commits.coffee &
COMMITS_PID=$!

export MAILGUN_KEY=blargh
./node_modules/.bin/coffee worker/emails.coffee &
EMAILS_PID=$!

sleep 5
echo killing is my bizniz..
kill $COMMITS_PID
kill $EMAILS_PID