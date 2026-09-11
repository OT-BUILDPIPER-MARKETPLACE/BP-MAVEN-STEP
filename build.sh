#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll build the code available at [$CODEBASE_LOCATION]"
sleep $SLEEP_DURATION

cd "${CODEBASE_LOCATION}"

# Determine the appropriate JDK path based on JAVA_VERSION
if [ "$JAVA_VERSION" == "17" ]; then
  JDK_PATH="/opt/jdk/jdk-17.0.2+8"
elif [ "$JAVA_VERSION" == "21" ]; then
  JDK_PATH="/opt/jdk/jdk-21+35"
else
  logErrorMessage "Unsupported JAVA_VERSION: $JAVA_VERSION. Please set JAVA_VERSION to 17, 21"
  saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
  exit 1
fi
# Switch Java version
if [ "$JAVA_VERSION" == "17" ]; then
  export JAVA_HOME=$JAVA_HOME_17
elif [ "$JAVA_VERSION" == "21" ]; then
  export JAVA_HOME=$JAVA_HOME_21
fi

# Switch Maven version
case "$MAVEN_VERSION" in
  "3.6.3")
    export MAVEN_HOME=$MAVEN_HOME_363
    ;;
  "3.8.1")
    export MAVEN_HOME=$MAVEN_HOME_381
    ;;
  *)
    echo "Maven version '${MAVEN_VERSION:-default}' not specified or unsupported. Using Maven 3.6.3."
    export MAVEN_HOME=$MAVEN_HOME_363
    ;;
esac

# Update PATH
export PATH=$JAVA_HOME/bin:$MAVEN_HOME/bin:$PATH

# Log the selected versions
echo "Using JDK version: $JAVA_VERSION ($JAVA_HOME)"
echo "Using Maven version: $MAVEN_VERSION ($MAVEN_HOME)"

# Configure proxy if provided
if [[ -n "$http_proxy" ]]; then
    export http_proxy="$http_proxy"
    export HTTP_PROXY="$http_proxy"
    logInfoMessage "HTTP proxy configured: $http_proxy"
fi

if [[ -n "$https_proxy" ]]; then
    export https_proxy="$https_proxy"
    export HTTPS_PROXY="$https_proxy"
    logInfoMessage "HTTPS proxy configured: $https_proxy"
fi

# Run keytool with the appropriate JDK
keytool -importcert -noprompt -trustcacerts -alias trendmicro-root -file trendmicro-root-ca.crt -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit
 

# Run Maven with the specified instruction
mvn $INSTRUCTION
TASK_STATUS=$?

# Save the task status
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
