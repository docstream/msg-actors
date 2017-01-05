#!/usr/bin/env sh

$APP=${APP:-gitlab-workers}

[ -z "$AWS_ECR" ] && echo "env AWS_ECR missing! ABORT" && exit 1
[ -z "$CIRCLE_BRANCH" ] && echo "env CIRCLE_BRANCH missing! ABORT" && exit 1

echo "----> branch: $CIRCLE_BRANCH"

aws --version
aws configure set default.region eu-central-1
aws configure set default.output json

# logins here only last 12h
eval $(aws ecr get-login --region eu-central-1)

docker push $AWS_ECR/$APP:$CIRCLE_BRANCH
