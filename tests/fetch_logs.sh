#!/usr/bin/env bash

set -e

AWS_DEFAULT_REGION=eu-west-3

# basic test
# start_build_id=gfxiq-dev-beegreen-rd-data-management:62f99626-7494-4b61-be22-bcf45d37c8ce

# test #74609:
start_build_id=gfxiq-stg-beegreen-pp-data-management:e4edfcc6-5331-42fe-af1e-90421f645a9a

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

  # keep previous nextForwardToken value
  previousNextForwardToken=${nextForwardToken}

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
  # Note: base64 -d on Alpine | --decode on MacOS for `base64 decode`
  for row in $(echo "${events}" | jq -r '.[] | @base64'); do
    echo ${row} | base64 --decode | jq -j '.message'
  done

  # if we have reached the end of the stream, get-log-events will return the same token we passed in,
  # meaning that we need to fetch remaining logs at once if we have not reached the end of the stream
  if [ "${nextForwardToken}" != "" ] && [ "${nextForwardToken}" != "${previousNextForwardToken}" ]; then
    fetch_logs
  fi
}

## Wait until build is complete and fetch logs
until [ "$(aws codebuild batch-get-builds --ids ${start_build_id} --output text --query 'builds[0].buildComplete')" = "True" ];
do
  fetch_logs;
  # wait 10s before checking build status again
  sleep 10;
done

# fetch last logs
fetch_logs
