#!/usr/bin/env bash

URL=${1:-amqp://127.0.0.1:5672}
ROUTE=${2:-emails}
BODY=${3:-./schemas/${ROUTE}.json}


echo "[URL=$URL] [ROUTE=$ROUTE] [BODY=$BODY]"

amqp-publish -u "$URL" -r "$ROUTE" < $BODY
