#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll build the code available at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

cd  "${CODEBASE_LOCATION}"
mvn $INSTRUCTION

TASK_STATUS=$?

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}

