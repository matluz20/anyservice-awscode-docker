#!/usr/bin/env bash

set -e

start_build_id=gfxiq-dev-beegreen-rd-data-management:62f99626-7494-4b61-be22-bcf45d37c8ce
AWS_DEFAULT_REGION=eu-west-3

fetch_logs() {
  # get cloudwatch logs info
  build_logs=$(aws codebuild batch-get-builds --ids ${start_build_id} --query 'builds[0].logs')
  build_cwlogs_group=`echo ${build_logs} | jq -c -r '.groupName'`;
  build_cwlogs_stream=`echo ${build_logs} | jq -c -r '.streamName'`;

  if [ "${build_cwlogs_group}" = "null" ] || [ "${build_cwlogs_stream}" = "null" ]; then
    echo "Waiting for build phase to start"
    return
  fi

  # get log events
  if [ "${nextForwardToken}" = "" ]; then
    log_events=$(aws logs get-log-events --log-group-name ${build_cwlogs_group} --log-stream-name ${build_cwlogs_stream} --start-from-head)
  else
    log_events=$(aws logs get-log-events --log-group-name ${build_cwlogs_group} --log-stream-name ${build_cwlogs_stream} --start-from-head --next-token ${nextForwardToken})
  fi
  nextForwardToken=`echo ${log_events} | jq -c -r '.nextForwardToken'`;
  events=`echo ${log_events} | jq -c -r '.events'`;

  if [ "$(echo "${events}" | jq -r '.[]')" = "" ] && [ -z ${build_has_started} ]; then
    echo "Waiting for build phase to start"
    return
  elif [ -z ${build_has_started} ]; then
    echo
    echo "Cloudwatch logs are available at the following url \nhttps://${AWS_DEFAULT_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_DEFAULT_REGION}#logEventViewer:group=${build_cwlogs_group};stream=${build_cwlogs_stream}"
    echo
    echo "-> Build phase started, log events follow:"
    echo "------------------------------------------"
    echo
    build_has_started=true
  fi

  # iterate on log events to display log messages only
  for row in $(echo "${events}" | jq -r '.[] | @base64'); do
    echo ${row} | base64 --decode | jq -j '.message'
  done
}

fetch_logs
