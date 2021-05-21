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

  # get-log-events may or may not return the same token when reaching the end of the stream, so we also check whether there are new events in the response and keep iterating from the same token until there are new log events
  if [ "$nextForwardToken" = "$previousNextForwardToken" ] || [ "$events" = "" ]; then
    nextForwardToken=$previousNextForwardToken
    return 
  fi

  # decode and print log events (we use python to iterate over log events as bash loops are too slow)
  echo ${log_events} | jq -c -r '.events' > events
  python print_events.py events

  # we have reached the end of the stream but there might be remaining log events, so we self invoke right away
  fetch_logs
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
