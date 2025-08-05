#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source getDynamicVars.sh

# Set the codebase location
CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll build the code available at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

# Change to the codebase directory
cd "${CODEBASE_LOCATION}" || { logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"; exit 1; }

# Main logic to check conditions and call fetch_service_details
if [ -n "$SOURCE_VARIABLE_REPO" ]; then
    # Check if INSTRUCTION is provided
    if [ -n "$INSTRUCTION" ]; then
        echo "INSTRUCTION is provided. Skipping fetching details from SOURCE_VARIABLE_REPO."
    else
        echo "Fetching details from $SOURCE_VARIABLE_REPO as INSTRUCTION is not provided."
        fetch_service_details
    fi

    # Switch Java version based on JAVA_VERSION
    case "$JAVA_VERSION" in
        "8")
            export JAVA_HOME=$JAVA_HOME_8
            ;;
        "11")
            export JAVA_HOME=$JAVA_HOME_11
            ;;
        "17")
            export JAVA_HOME=$JAVA_HOME_17
            ;;
        "21")
            export JAVA_HOME=$JAVA_HOME_21
            ;;
        *)
            logErrorMessage "Unsupported JAVA_VERSION: $JAVA_VERSION"
            exit 1
            ;;
    esac

    # Switch Maven version based on MAVEN_VERSION
    case "$MAVEN_VERSION" in
        "3.6.3")
            export MAVEN_HOME=$MAVEN_HOME_363
            ;;
        "3.8.1")
            export MAVEN_HOME=$MAVEN_HOME_381
            ;;
        "3.5.4")
            export MAVEN_HOME=$MAVEN_HOME_354
            ;;
        "3.9.9")
            export MAVEN_HOME=$MAVEN_HOME_399
            ;;
        *)
            logErrorMessage "Unsupported MAVEN_VERSION: $MAVEN_VERSION"
            exit 1
            ;;
    esac

    # Update PATH to include Java and Maven binaries
    export PATH="$JAVA_HOME/bin:$MAVEN_HOME/bin:$PATH"

    # Log the selected versions
    echo "Using JDK version: $JAVA_VERSION ($JAVA_HOME)"
    echo "Using Maven version: $MAVEN_VERSION ($MAVEN_HOME)"
else
    logErrorMessage "SOURCE_VARIABLE_REPO is not defined. Skipping fetching details from SOURCE_VARIABLE_REPO."
    # exit 1
fi

# Execute the Maven command
logInfoMessage "Executing mvn $INSTRUCTION"
mvn $INSTRUCTION

# Capture the task status
TASK_STATUS=$?

# Save the task status
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}