#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll build the code available at [$CODEBASE_LOCATION]"
sleep $SLEEP_DURATION

cd "${CODEBASE_LOCATION}"

#######################################
# Select JDK Version
#######################################
if [ "$JAVA_VERSION" == "8" ]; then
  JDK_PATH="/opt/jdk/jdk8u312-b07"
elif [ "$JAVA_VERSION" == "11" ]; then
  JDK_PATH="/opt/jdk/jdk-11.0.12+7"
elif [ "$JAVA_VERSION" == "17" ]; then
  JDK_PATH="/opt/jdk/jdk-17.0.2+8"
elif [ "$JAVA_VERSION" == "21" ]; then
  JDK_PATH="/opt/jdk/jdk-21+35"
else
  logErrorMessage "Unsupported JAVA_VERSION: $JAVA_VERSION. Please set JAVA_VERSION to 8, 11, 17, or 21."
  saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
  exit 1
fi

#######################################
# Select Maven Version
#######################################
if [ "$MAVEN_VERSION" == "3.5.4" ]; then
  MVN_PATH="/opt/maven/apache-maven-3.5.4"
elif [ "$MAVEN_VERSION" == "3.6.3" ]; then
  MVN_PATH="/opt/maven/apache-maven-3.6.3"
elif [ "$MAVEN_VERSION" == "3.8.1" ]; then
  MVN_PATH="/opt/maven/apache-maven-3.8.1"
else
  logErrorMessage "Unsupported MAVEN_VERSION: $MAVEN_VERSION. Please set MAVEN_VERSION to 3.5.4, 3.6.3, or 3.8.1."
  saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
  exit 1
fi

#######################################
# Import cert using selected JDK
#######################################
"${JDK_PATH}/bin/keytool" -import -alias jetty -keystore "${JDK_PATH}/lib/security/cacerts" \
  -file ./nexus.cer -storepass changeit -noprompt

if [ $? -ne 0 ]; then
  logErrorMessage "Keytool command failed for JAVA_VERSION: $JAVA_VERSION"
  saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
  exit 1
fi

#######################################
# Execute Maven build
#######################################
"${MVN_PATH}/bin/mvn" $INSTRUCTION
TASK_STATUS=$?

#######################################
# Save Task Status
#######################################
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}