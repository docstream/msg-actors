#!/usr/bin/env bash

export G_TOKEN_1=svada.com=blargh
export G_TOKEN_2=daddy.com=blargh
./node_modules/.bin/coffee worker/commits.coffee &
COMMITS_PID=$!

export MAILGUN_KEY=blargh
./node_modules/.bin/coffee worker/emails.coffee &
EMAILS_PID=$!

./node_modules/.bin/coffee worker/feedback.coffee &
FEEDBACK_PID=$!

export MAILCHIMP_KEY_1=svada.com=blargh
export MAILCHIMP_KEY_2='{"daddy.com":"blargh","xxx.com":"ok-also"}'
./node_modules/.bin/coffee worker/spamme.coffee &
SPAMME_PID=$!

# export AUTH0_1='{"daddy.com":"blargh","xxx.com":"ok-also"}'
# export AUTH0_2='{"daddy.com":"blargh","xxx.com":"ok-also"}'
# ./node_modules/.bin/coffee worker/denormalizer.coffee &
# DENORM_PID=$!

echo FEEDBACK_PID=$COMMITS_PID
echo SPAMME_PID=$EMAILS_PID
echo FEEDBACK_PID=$FEEDBACK_PID
echo SPAMME_PID=$SPAMME_PID
echo DENORM_PID=$DENORM_PID

sleep 8
echo killing is my bizniz..
kill $COMMITS_PID
kill $EMAILS_PID
kill $FEEDBACK_PID
kill $SPAMME_PID
# kill $DENORM_PID
