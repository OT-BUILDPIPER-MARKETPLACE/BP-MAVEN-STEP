#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "I'll build the code available at [$CODEBASE_LOCATION]"
sleep "$SLEEP_DURATION"

cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "Failed to change directory to ${CODEBASE_LOCATION}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
}

# -------------------------------------------------------
# Determine JDK path based on JAVA_VERSION
# -------------------------------------------------------
case "$JAVA_VERSION" in
    "8")
        JDK_PATH="/opt/jdk/jdk8u312-b07"
        export JAVA_HOME="${JAVA_HOME_8}"
        ;;
    "11")
        JDK_PATH="/opt/jdk/jdk-11.0.12+7"
        export JAVA_HOME="${JAVA_HOME_11}"
        ;;
    "17")
        JDK_PATH="/opt/jdk/jdk-17.0.2+8"
        export JAVA_HOME="${JAVA_HOME_17}"
        ;;
    "21")
        JDK_PATH="/opt/jdk/jdk-21+35"
        export JAVA_HOME="${JAVA_HOME_21}"
        ;;
    "25")
        JDK_PATH="/opt/jdk/jdk-25+36"
        export JAVA_HOME="${JAVA_HOME_25}"
        ;;
    "2504")
        JDK_PATH="/opt/jdk/jdk-25.0.4.1+1"
        export JAVA_HOME="${JAVA_HOME_2504}"
        ;;
    "2110131")
        JDK_PATH="/opt/jdk/jdk-21.0.13.1+2"
        export JAVA_HOME="${JAVA_HOME_2110131}"
        ;;
    "250501")
        JDK_PATH="/opt/jdk/jdk-25.0.5.1+2"
        export JAVA_HOME="${JAVA_HOME_250501}"
        ;;
    *)
        logErrorMessage "Unsupported JAVA_VERSION: ${JAVA_VERSION}. Supported values: 8, 11, 17, 21, 25, 2504, 21130103, 2110131, 250501."
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
        ;;
esac

# -------------------------------------------------------
# Validate selected JDK
# -------------------------------------------------------
if [ ! -x "${JDK_PATH}/bin/java" ]; then
    logErrorMessage "Java executable not found: ${JDK_PATH}/bin/java"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

# -------------------------------------------------------
# Switch Maven version
# -------------------------------------------------------
case "$MAVEN_VERSION" in
    "3.5.4")
        export MAVEN_HOME="${MAVEN_HOME_354}"
        ;;
    "3.6.3")
        export MAVEN_HOME="${MAVEN_HOME_363}"
        ;;
    "3.8.1")
        export MAVEN_HOME="${MAVEN_HOME_381}"
        ;;
    "3.9.16")
        export MAVEN_HOME="${MAVEN_HOME_3916}"
        ;;
    *)
        echo "Maven version '${MAVEN_VERSION:-default}' not specified or unsupported. Using Maven 3.6.3."
        export MAVEN_HOME="${MAVEN_HOME_363}"
        ;;
esac

# -------------------------------------------------------
# Update PATH
# -------------------------------------------------------
export PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"

# -------------------------------------------------------
# Log selected versions
# -------------------------------------------------------
echo "Using JAVA_VERSION: ${JAVA_VERSION}"
echo "Using JAVA_HOME: ${JAVA_HOME}"
echo "Using Maven version: ${MAVEN_VERSION:-default}"
echo "Using MAVEN_HOME: ${MAVEN_HOME}"

"${JAVA_HOME}/bin/java" -version

# -------------------------------------------------------
# Import certificate using selected JDK
# -------------------------------------------------------
"${JDK_PATH}/bin/keytool" \
    -import \
    -alias jetty \
    -keystore "${JDK_PATH}/lib/security/cacerts" \
    -file ./nexus.cer \
    -storepass changeit \
    -noprompt

if [ $? -ne 0 ]; then
    logErrorMessage "Keytool command failed for JAVA_VERSION: ${JAVA_VERSION}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

# -------------------------------------------------------
# Run Maven
# -------------------------------------------------------
mvn ${INSTRUCTION}
TASK_STATUS=$?

# -------------------------------------------------------
# Save task status
# -------------------------------------------------------
saveTaskStatus "${TASK_STATUS}" "${ACTIVITY_SUB_TASK_CODE}"