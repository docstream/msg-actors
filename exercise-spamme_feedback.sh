#!/usr/bin/env bash

export MAILGUN_KEY=blargh
export MAILCHIMP_API_KEY=blargh

./node_modules/.bin/coffee worker/feedback.coffee &
FEEDBACK_PID=$!

./node_modules/.bin/coffee worker/spamme.coffee &
SPAMME_PID=$!

echo FEEDBACK_PID=$FEEDBACK_PID
echo SPAMME_PID=$SPAMME_PID


sleep 25
echo killing is my bizniz..
kill $FEEDBACK_PID
kill $SPAMME_PID
