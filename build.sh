#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source getDynamicVars.sh
source set_npmrc.sh

TASK_STATUS=0

ACTIVITY_SUB_TASK_CODE="MVN_EXECUTE_${INSTRUCTION_TYPE}"

# Set the codebase location
CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll $INSTRUCTION_TYPE the code available at [$CODEBASE_LOCATION]"
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

if [[ -n "$EXTRA_COMMAND" ]]; then
  logInfoMessage "Executing extra command: $EXTRA_COMMAND"
  eval "$EXTRA_COMMAND"
else
  logInfoMessage "No extra command provided. Skipping."
fi

# Execute the Maven command
logInfoMessage "Executing mvn $INSTRUCTION $MAVEN_OPTIONS"
mvn $INSTRUCTION $MAVEN_OPTIONS
TASK_STATUS=$?

# Save the task status
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}

# Default XML scan (always runs for TEST)
if [[ "$INSTRUCTION_TYPE" == "TEST" ]]; then
    REPORTS=$(find target/surefire-reports/ -name "TEST-*.xml" 2>/dev/null)
    TOTAL=0
    FAIL=0
    for REPORT in $REPORTS; do
        T=$(grep -oP '(?<=tests=")[0-9]+' "$REPORT" | awk '{s+=$1} END {print s}')
        F=$(grep -oP '(?<=failures=")[0-9]+' "$REPORT" | awk '{s+=$1} END {print s}')
        E=$(grep -oP '(?<=errors=")[0-9]+' "$REPORT" | awk '{s+=$1} END {print s}')
        TOTAL=$((TOTAL + T))
        FAIL=$((FAIL + F + E))
    done
    if [[ "$TOTAL" -eq 0 ]]; then
        logErrorMessage "No tests found or unable to parse test report."
        exit 1
    fi
    FAIL_PERCENT=$(( 100 * FAIL / TOTAL ))
    THRESHOLD="${TEST_FAILURE_THRESHOLD:-50}"
    logInfoMessage "Updating surefire-reports in /bp/execution_dir/${GLOBAL_TASK_ID}......."
    cp -rf target/surefire-reports /bp/execution_dir/${GLOBAL_TASK_ID}/
    echo "Test failure rate: $FAIL_PERCENT% (Threshold: $THRESHOLD%)"
    if (( FAIL_PERCENT > THRESHOLD )); then
        logErrorMessage "Test failure rate ($FAIL_PERCENT%) exceeded threshold ($THRESHOLD%). Failing build."
        logInfoMessage "Updating target/surefire-reports in /bp/execution_dir/${GLOBAL_TASK_ID}......."
        cp -rf target/surefire-reports /bp/execution_dir/${GLOBAL_TASK_ID}/
        TASK_STATUS=1
    fi
    saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
fi

# Custom HTML scan (only runs if ENABLE_CUSTOM_HTML_SCAN is true)
if [[ "$INSTRUCTION_TYPE" == "TEST" && "${ENABLE_CUSTOM_HTML_SCAN,,}" == "true" ]]; then
    echo "CODEBASE_LOCATION is: $CODEBASE_LOCATION"
    TEST_RESULT_DIR="${TEST_RESULT_DIR:-Results}"
    echo "Custom HTML scan enabled. Checking for HTML reports in $TEST_RESULT_DIR"
    
    ls -l "$TEST_RESULT_DIR"

    REPORT_HTML=$(find "$TEST_RESULT_DIR" -type f -name "*.html" -printf "%T@ %p\n" | sort -nr | head -1 | awk '{print $2}')
    THRESHOLD="${TEST_FAILURE_THRESHOLD:-50}"

    if [[ -z "$REPORT_HTML" || ! -f "$REPORT_HTML" ]]; then
        logErrorMessage "Could not find any HTML report file under $TEST_RESULT_DIR"
        exit 1
    fi

    echo "Using report file: $REPORT_HTML"

    TOTAL=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Tests executed')]]/td[2])" "$REPORT_HTML" 2>/dev/null)
    PASS=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Pass Test count')]]/td[2])" "$REPORT_HTML" 2>/dev/null)
    FAIL=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Fail Test count')]]/td[2])" "$REPORT_HTML" 2>/dev/null)

    FAIL_PERCENT=$(( 100 * FAIL / TOTAL ))

    echo "Total Tests executed : $TOTAL"
    echo "Total Pass Test count: $PASS"
    echo "Total Fail Test count: $FAIL"
    echo "Test failure rate    : $FAIL_PERCENT% (Threshold: $THRESHOLD%)"

    if (( FAIL_PERCENT > THRESHOLD )); then
        logErrorMessage "Test failure rate ($FAIL_PERCENT%) exceeded threshold ($THRESHOLD%). Failing build."
        logInfoMessage "Updating Results in /bp/execution_dir/${GLOBAL_TASK_ID}......."
        cp -rf $TEST_RESULT_DIR /bp/execution_dir/${GLOBAL_TASK_ID}/
        TASK_STATUS=1
    else
        echo "✅ Test failure rate is within threshold."
        logInfoMessage "Updating Results in /bp/execution_dir/${GLOBAL_TASK_ID}......."
        cp -rf $TEST_RESULT_DIR /bp/execution_dir/${GLOBAL_TASK_ID}/
        TASK_STATUS=0
    fi
    saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
fi
