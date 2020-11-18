#!/usr/bin/env bash

set -e

export AWS_DEFAULT_REGION=eu-west-3

start_build_id=$1

fetch_logs() {

  if [ -z "${build_cwlogs_stream}" ] || [ "${build_cwlogs_stream}" = "null" ]; then
    build_logs=`aws codebuild batch-get-builds --ids ${start_build_id} --query 'builds[0].logs'`
    build_cwlogs_group=`echo ${build_logs} | jq -c -r '.groupName'`;
    build_cwlogs_stream=`echo ${build_logs} | jq -c -r '.streamName'`;

    if [ "${build_cwlogs_stream}" != "null" ]; then
      echo "Cloudwatch logs are available at the following url:"
      echo "https://${AWS_DEFAULT_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_DEFAULT_REGION}#logEventViewer:group=${build_cwlogs_group};stream=${build_cwlogs_stream}"
    else
      echo "Waiting for Cloudwatch Logs info"
      sleep 5
      fetch_logs
    fi
  fi

  # get log events
  if [ "${has_events}" != "true" ]; then
    # always start from the beginning when we didn't fetch any log events yet
    log_events=`aws logs get-log-events --log-group-name ${build_cwlogs_group} --log-stream-name ${build_cwlogs_stream} --start-from-head`
  else
    # otherwise, resume from where we left
    log_events=`aws logs get-log-events --log-group-name ${build_cwlogs_group} --log-stream-name ${build_cwlogs_stream} --start-from-head --next-token ${nextForwardToken}`
  fi

  # extract log events
  events=`echo ${log_events} | jq -c -r '.events[]'`
  
  if [ "${has_events}" = "true" ] || [ "${events}" != "" ]; then
    if [ "${has_events}" != "true" ]; then
        echo "-> Log events follow:"
        echo "------------------------------------------"
    fi
    has_events=true
  else
    echo "Waiting for logs"
    sleep 10
    fetch_logs
  fi

  # keep previous nextForwardToken value
  previousNextForwardToken=${nextForwardToken}
  # extract token for logs pagination
  nextForwardToken=`echo ${log_events} | jq -c -r '.nextForwardToken'`;

  # iterate on log events to display log messages only
  # Note: base64 -d on Alpine | --decode on MacOS for `base64 decode`
  for row in $(echo "${events}" | jq -r '@base64'); do
    timestamp=`echo ${row} | base64 --decode | jq -j '.timestamp'`
    ts_seconds=$((${timestamp}/1000))
    # Note: cross platform
    date=`date -d @${ts_seconds} +'%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r ${ts_seconds} +'%Y-%m-%d %H:%M:%S'`
    message=`echo ${row} | base64 --decode | jq -j '.message'`
    echo "${date}   ${message}"
  done

  # if we have reached the end of the stream, get-log-events will return the same token we passed in,
  # meaning that we need to fetch remaining logs at once if we have not reached the end of the stream
  # otherwise we'll jump out of the loop and wait next iteration
  if [ "${nextForwardToken}" != "" ] && [ "${nextForwardToken}" != "${previousNextForwardToken}" ]; then
    fetch_logs
  fi
}

# Wait until build is complete and fetch logs
until [ "$(aws codebuild batch-get-builds --ids ${start_build_id} --output text --query 'builds[0].buildComplete')" = "True" ];
do
  fetch_logs;
  # wait 10s before checking build status again
  sleep 10;
done

# fetch last logs
fetch_logs
