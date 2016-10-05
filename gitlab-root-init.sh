#!/usr/bin/env sh

# checking for utils on MACHINE
command -v docker-compose >/dev/null 2>&1 \
  || { echo >&2 "WE NEED docker-compose ! Pls install"; exit 1; }
command -v curl >/dev/null 2>&1 \
  || { echo >&2 "WE NEED curl ! Pls install"; exit 1; }
command -v jq >/dev/null 2>&1 \
  || { echo >&2 "WE NEED jq ! Pls install"; exit 1; }

PROJECT=$(echo $(basename $PWD) | tr -d '-')

docker-compose -f d-c.gitlab.yml up -d
sleep 2
docker exec --user git -it ${PROJECT}_gitlab_1 \
  bundle exec rake gitlab:setup force=yes RAILS_ENV=production GITLAB_ROOT_PASSWORD=passord1


# waaaait for it ...............
until $(curl --output /dev/null --silent --head --fail http://localhost:10080); do
    printf '.'
    sleep .3
done
echo

RESP=$(curl -s http://localhost:10080/api/v3/session \
  --data 'login=root&password=passord1')
TOKEN=$(echo $RESP | jq -r '.private_token')


if test -z "$TOKEN"
then
  echo "ALARM !! No TOKEN here !!"
  echo
  echo DEBUG start:
  echo   resp =   $RESP
  echo DEBUG end.
  docker-compose -f d-c.gitlab.yml down
  exit 1
fi

echo "Saving TOKEN [$TOKEN] into _GITLAB.env file ..."


echo "export GITLAB_TOKEN=$TOKEN" > _GITLAB.env

docker-compose -f d-c.gitlab.yml down
