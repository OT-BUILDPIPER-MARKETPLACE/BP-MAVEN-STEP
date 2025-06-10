#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source getDynamicVars.sh
source set_npmrc.sh

TASK_STATUS=0

# Set the codebase location
CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll build the code available at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

# Set the npmrc file default location
set_npmrc

# Change to the codebase directory
cd "${CODEBASE_LOCATION}" || { logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"; exit 1; }

# Main logic to check conditions and call fetch_service_details
if [ -n "$SOURCE_VARIABLE_REPO" ]; then
    # Check if INSTRUCTION is provided
    if [ -n "$INSTRUCTION" ]; then
        logInfoMessage "INSTRUCTION is provided. Skipping fetching details from SOURCE_VARIABLE_REPO."
    else
        logInfoMessage "Fetching details from $SOURCE_VARIABLE_REPO as INSTRUCTION is not provided."
        fetch_service_details
    fi

else
    logInfoMessage "SOURCE_VARIABLE_REPO is not defined. Skipping fetching details from SOURCE_VARIABLE_REPO."
    # exit 1
fi

# Switch maven INSTRUCTION based on INSTRUCTION_TYPE
if [ -z "$INSTRUCTION" ]; then
    case "$INSTRUCTION_TYPE" in
        "BUILD")  export INSTRUCTION=$MAVEN_BUILD_INSTRUCTION ;;
        "DEPLOY") export INSTRUCTION=$MAVEN_DEPLOY_INSTRUCTION ;;
        "TEST")   export INSTRUCTION=$MAVEN_TEST_INSTRUCTION ;;
        "CUSTOM") export INSTRUCTION=$MAVEN_CUSTOM_INSTRUCTION ;;
        *) logErrorMessage "Unsupported $INSTRUCTION_TYPE: Executing default mvn $INSTRUCTION"
            ;;
    esac
fi

## Check if ENABLE_MAVEN_SILENT_MODE is set
MAVEN_OPTIONS=""
if [[ "${ENABLE_MAVEN_SILENT_MODE,,}" == "true" ]]; then
    MAVEN_OPTIONS="--no-transfer-progress"
    # MAVEN_OPTIONS="-B -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"
fi

# Ensure INSTRUCTION is set before executing Maven
if [ -z "$INSTRUCTION" ]; then
    logErrorMessage "INSTRUCTION is not set. Exiting..."
    exit 1
    TASK_STATUS=$?
fi

# Custom logic to handle for Indepay
if [[ -n "$DOMAIN" && -n "$DOMAIN_OWNER" && -n "$REGION" ]]; then
  export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
    --domain "$DOMAIN" \
    --domain-owner "$DOMAIN_OWNER" \
    --region "$REGION" \
    --query authorizationToken \
    --output text)
else
  echo "Required environment variables (DOMAIN, DOMAIN_OWNER, REGION) are not set. Skipping token export."
fi
# Execute the Maven command
logInfoMessage "Executing mvn $INSTRUCTION $MAVEN_OPTIONS"
mvn $INSTRUCTION $MAVEN_OPTIONS

# Capture the task status
TASK_STATUS=$?

# Save the task status
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
