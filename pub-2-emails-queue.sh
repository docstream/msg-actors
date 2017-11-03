#!/usr/bin/env bash


amqp-publish -r emails -u amqp://127.0.0.1:5672 << _JSON
{
  "x": 1
}
_JSON