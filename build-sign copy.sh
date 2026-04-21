#!/bin/bash
set -e

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

#######################################
# Initial Setup
#######################################

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll build the code available at [$CODEBASE_LOCATION]"
sleep "$SLEEP_DURATION"

cd "$CODEBASE_LOCATION" || {
  logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"
  exit 1
}

#######################################
# Select JDK Version
#######################################
case "$JAVA_VERSION" in
  8)
    JDK_PATH="/opt/jdk/jdk8u312-b07"
    ;;
  11)
    JDK_PATH="/opt/jdk/jdk-11.0.12+7"
    ;;
  17)
    JDK_PATH="/opt/jdk/jdk-17.0.2+8"
    ;;
  21)
    JDK_PATH="/opt/jdk/jdk-21+35"
    ;;
  *)
    logErrorMessage "Unsupported JAVA_VERSION: $JAVA_VERSION (Allowed: 8, 11, 17, 21)"
    saveTaskStatus 1 "$ACTIVITY_SUB_TASK_CODE"
    exit 1
    ;;
esac

#######################################
# Set JAVA_HOME and PATH
#######################################
export JAVA_HOME="$JDK_PATH"
export PATH="$JAVA_HOME/bin:$PATH"

logInfoMessage "Using JAVA_HOME=$JAVA_HOME"
logInfoMessage "Using Java: $(java -version 2>&1 | head -n 1)"
logInfoMessage "Using jarsigner: $(which jarsigner)"

#######################################
# Select Maven Version
#######################################
case "$MAVEN_VERSION" in
  3.5.4)
    MVN_PATH="/opt/maven/apache-maven-3.5.4"
    ;;
  3.6.3)
    MVN_PATH="/opt/maven/apache-maven-3.6.3"
    ;;
  3.8.1)
    MVN_PATH="/opt/maven/apache-maven-3.8.1"
    ;;
  *)
    logErrorMessage "Unsupported MAVEN_VERSION: $MAVEN_VERSION (Allowed: 3.5.4, 3.6.3, 3.8.1)"
    saveTaskStatus 1 "$ACTIVITY_SUB_TASK_CODE"
    exit 1
    ;;
esac

# Log the selected versions
echo "Using JDK version: $JAVA_VERSION ($JAVA_HOME)"
echo "Using Maven version: $MAVEN_VERSION ($MAVEN_HOME)"

#######################################
# Import Nexus Certificate
#######################################
logInfoMessage "Importing Nexus certificate into JVM truststore"

keytool -import \
  -alias jetty \
  -keystore "$JAVA_HOME/lib/security/cacerts" \
  -file ./nexus.cer \
  -storepass changeit \
  -noprompt

#######################################
# Execute Maven Build
#######################################
logInfoMessage "Executing Maven command: mvn $INSTRUCTION"

mvn $INSTRUCTION
TASK_STATUS=$?
if [ $TASK_STATUS -ne 0 ]; then
  logErrorMessage "Failed to Build the jar"
  exit 1
fi
#######################################
# Resolve JAR Name
#######################################
JAR_NAME=$(
  mvn -q -DforceStdout help:evaluate -Dexpression=project.build.finalName
).jar

if [[ ! -f "target/$JAR_NAME" ]]; then
  logErrorMessage "JAR not found: $JAR_NAME"
  exit 1
fi

#######################################
# Sign the JAR
#######################################

logInfoMessage "Signing JAR: $JAR_NAME"


jarsigner \
  -keystore "$KEYSTORE_PATH" \
  -storepass "$KEYSTORE_PASSWORD" \
  "target/$JAR_NAME" \
  "$KEY_ALIAS"
TASK_STATUS=$?
if [ $TASK_STATUS -ne 0 ]; then
  logErrorMessage "Failed to signed the jar $JAR_NAME"
  exit 1
fi
#######################################
# Verify Signed JAR
#######################################
logInfoMessage "Verifying signed JAR"

jarsigner -verify -verbose -certs "target/$JAR_NAME"

TASK_STATUS=$?
if [ $TASK_STATUS -ne 0 ]; then
  logErrorMessage "Failed to verify the jar target/$JAR_NAME"
  exit 1
fi
#######################################
# Save Task Status
#######################################
logInfoMessage "Build and signing completed successfully"
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
