#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source getDynamicVars.sh
source set_npmrc.sh

ACTIVITY_SUB_TASK_CODE="MVN_EXECUTE"

TASK_STATUS=0
WORKSPACE="${WORKSPACE:-/bp/workspace}"

logInfoMessage "DEBUG FINAL CHECK: ACTIVITY_SUB_TASK_CODE=[${ACTIVITY_SUB_TASK_CODE}] EXECUTION_TASK_ID=[${EXECUTION_TASK_ID}]"

SAVE_TASK_CODE="MVN_EXECUTE_${INSTRUCTION_TYPE}"

# Milestone: Start
add_event "MAVEN INIT" "Successful" "Preparation for ${INSTRUCTION_TYPE} initiated" "Codebase target: ${CODEBASE_DIR}"
sleep 10

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll $INSTRUCTION_TYPE the code available at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

sleep 10


set_npmrc

# Change to the codebase directory
cd "${CODEBASE_LOCATION}" || { 
    add_event "DIRECTORY ACCESS" "Failed" \
                "Failed to change directory to $CODEBASE_LOCATION" \
                "Check path and permissions"
    logErrorMessage "Failed to change directory to $CODEBASE_LOCATION"; 
    exit 1; 
}

# Source variable logic
if [ -n "$SOURCE_VARIABLE_REPO" ]; then
    if [ -n "$INSTRUCTION" ]; then
        logInfoMessage "INSTRUCTION is provided. Skipping fetching details from SOURCE_VARIABLE_REPO."
    else
        logInfoMessage "Fetching details from $SOURCE_VARIABLE_REPO as INSTRUCTION is not provided."
        fetch_service_details
        source /usr/local/bin/switch_versions.sh
    fi
else
    logInfoMessage "SOURCE_VARIABLE_REPO is not defined. Skipping fetching details from SOURCE_VARIABLE_REPO."
fi

# Switch maven INSTRUCTION based on INSTRUCTION_TYPE
if [ -z "$INSTRUCTION" ]; then
    case "$INSTRUCTION_TYPE" in
        "BUILD")  export INSTRUCTION=$MAVEN_BUILD_INSTRUCTION ;;
        "DEPLOY") export INSTRUCTION=$MAVEN_DEPLOY_INSTRUCTION ;;
        "TEST")   export INSTRUCTION=$MAVEN_TEST_INSTRUCTION ;;
        "CUSTOM") export INSTRUCTION=$MAVEN_CUSTOM_INSTRUCTION ;;
        "SONAR_SCAN" ) export INSTRUCTION=$MAVEN_SONAR_SCAN_INSTRUCTION ;;
        *) logErrorMessage "Unsupported $INSTRUCTION_TYPE: Executing default mvn $INSTRUCTION"
            ;;
    esac
fi

if [ -z "$INSTRUCTION" ]; then
    logErrorMessage "INSTRUCTION is not set. Exiting..."
    add_event "MAVEN INIT" "Failed" \
        "INSTRUCTION variable is not set" \
        "Check pipeline config for INSTRUCTION or INSTRUCTION_TYPE"
    saveTaskStatus 1 "${SAVE_TASK_CODE}" 
    exit 1
fi

# Custom logic to handle for codeartifact
if [[ "${CODEARTIFACT}" = "true" ]]; then
    logInfoMessage "CodeArtifact is enabled. Generating and exporting auth token."
    if [[ -n "$DOMAIN" && -n "$DOMAIN_OWNER" && -n "$REGION" ]]; then
        add_event "CODEARTIFACT AUTH" "Successful" \
                    "Generating AWS Auth Token" \
                    "Domain: $DOMAIN | Region: $REGION"
        export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
        --domain "$DOMAIN" \
        --domain-owner "$DOMAIN_OWNER" \
        --region "$REGION" \
        --query authorizationToken \
        --output text)
    else
        add_event "CODEARTIFACT AUTH" "Failed" \
                    "Required env variables missing for CodeArtifact" \
                    "Check DOMAIN, DOMAIN_OWNER, and REGION"
        logErrorMessage "Required environment variables (DOMAIN, DOMAIN_OWNER, REGION) are not set. Auth token not generated/export."
        saveTaskStatus 1 "${SAVE_TASK_CODE}" 
        exit 1
    fi
fi

if [[ -n "$EXTRA_COMMAND" ]]; then
  logInfoMessage "Executing extra command: $EXTRA_COMMAND"
  eval "$EXTRA_COMMAND"
fi

MAVEN_OPTIONS=${MAVEN_OPTIONS:-}

# Determine suffix based on SONAR_TESTING_TYPE
SONAR_SUFFIX=""
case "$SONAR_TESTING_TYPE" in
    Integration) SONAR_SUFFIX="-it" ;;
    Unit) SONAR_SUFFIX="-ut" ;;
    *) SONAR_SUFFIX="" ;;
esac

# Execution Milestone
if [[ "$INSTRUCTION_TYPE" == "SONAR_SCAN" ]]; then
    logInfoMessage "Executing Sonar Scan for project [$CODEBASE_DIR$SONAR_SUFFIX]"

    # Log command safely (hide token)
    logInfoMessage "mvn $INSTRUCTION $MAVEN_OPTIONS -Dsonar.projectKey=$CODEBASE_DIR$SONAR_SUFFIX -Dsonar.projectName=$CODEBASE_DIR$SONAR_SUFFIX -Dsonar.host.url=$SONAR_URL -Dsonar.login=******"
    add_event "SONAR SCAN" "Successful" \
                "Executing Sonar Scan for project" \
                "Key: ${CODEBASE_DIR}${SONAR_SUFFIX}"
    # Execute actual command    
    mvn $INSTRUCTION $MAVEN_OPTIONS \
        -Dsonar.projectKey="${CODEBASE_DIR}${SONAR_SUFFIX}" \
        -Dsonar.projectName="${CODEBASE_DIR}${SONAR_SUFFIX}" \
        -Dsonar.host.url="$SONAR_URL" \
        -Dsonar.login="$SONAR_TOKEN"
else
    add_event "MAVEN EXECUTION" "Successful" \
                "Running Maven command" \
                "mvn $INSTRUCTION $MAVEN_OPTIONS"
    mvn $INSTRUCTION $MAVEN_OPTIONS
fi

TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${SAVE_TASK_CODE}

# Default XML scan
if [[ "$INSTRUCTION_TYPE" == "TEST" ]]; then
    add_event "TEST ANALYSIS" "Successful" \
                "Parsing JUnit XML reports" \
                "Threshold: ${TEST_FAILURE_THRESHOLD:-50}%"
                
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
        add_event "TEST ANALYSIS" "Failed" \
                    "No test results found to parse" \
                    "Check target/surefire-reports/ directory"
        exit 1
    fi
    FAIL_PERCENT=$(( 100 * FAIL / TOTAL ))
    THRESHOLD="${TEST_FAILURE_THRESHOLD:-50}"
    logInfoMessage "Updating surefire-reports in /bp/execution_dir/${GLOBAL_TASK_ID}......."

    cp -rf target/surefire-reports /bp/execution_dir/${GLOBAL_TASK_ID}/
        logWarnMessage "Test failure rate: $FAIL_PERCENT% (Threshold: $THRESHOLD%)"

    if (( FAIL_PERCENT > THRESHOLD )); then
        add_event "TEST THRESHOLD" "Failed" \
                    "Failure rate $FAIL_PERCENT% exceeds threshold $THRESHOLD%" \
                    "Failing build based on test results"
        TASK_STATUS=1
    fi
    saveTaskStatus ${TASK_STATUS} ${SAVE_TASK_CODE}
fi

# Custom HTML scan
if [[ "$INSTRUCTION_TYPE" == "TEST" && "${ENABLE_CUSTOM_HTML_SCAN,,}" == "true" ]]; then
    add_event "HTML REPORT SCAN" "Successful" \
                "Parsing custom HTML reports" \
                "Directory: ${TEST_RESULT_DIR:-Results}"

    TEST_RESULT_DIR="${TEST_RESULT_DIR:-Results}"
    REPORT_HTML=$(find "$TEST_RESULT_DIR" -type f -name "*.html" -printf "%T@ %p\n" | sort -nr | head -1 | awk '{print $2}')
    THRESHOLD="${TEST_FAILURE_THRESHOLD:-50}"

    if [[ -z "$REPORT_HTML" || ! -f "$REPORT_HTML" ]]; then
        add_event "HTML REPORT SCAN" "Failed" \
                    "No HTML report file found" \
                    "Target path: $TEST_RESULT_DIR"
        exit 1
    fi

    TOTAL=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Tests executed')]]/td[2])" "$REPORT_HTML" 2>/dev/null)
    PASS=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Pass Test count')]]/td[2])" "$REPORT_HTML" 2>/dev/null)
    FAIL=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Fail Test count')]]/td[2])" "$REPORT_HTML" 2>/dev/null)

    FAIL_PERCENT=$(( 100 * FAIL / TOTAL ))

    logInfoMessage "Total Tests executed : $TOTAL"
    logInfoMessage "Total Pass Test count: $PASS"
    logInfoMessage "Total Fail Test count: $FAIL"
    logInfoMessage "Test failure rate    : $FAIL_PERCENT% (Threshold: $THRESHOLD%)"

    if (( FAIL_PERCENT > THRESHOLD )); then
            logErrorMessage "Test failure rate ($FAIL_PERCENT%) exceeded threshold ($THRESHOLD%). Failing build."
        logInfoMessage "Updating Results in /bp/execution_dir/${GLOBAL_TASK_ID}......."
        add_event "TEST THRESHOLD" "Failed" \
                    "HTML report failure rate $FAIL_PERCENT% > $THRESHOLD%" \
                    "Check report: $REPORT_HTML"
        cp -rf $TEST_RESULT_DIR /bp/execution_dir/${GLOBAL_TASK_ID}/
        TASK_STATUS=1
    else
            logInfoMessage "✅ Test failure rate is within threshold."
        logInfoMessage "Updating Results in /bp/execution_dir/${GLOBAL_TASK_ID}......."

        add_event "TEST THRESHOLD" "Successful" \
                    "Failure rate $FAIL_PERCENT% within limit" \
                    "Build successful"
        cp -rf $TEST_RESULT_DIR /bp/execution_dir/${GLOBAL_TASK_ID}/
        TASK_STATUS=0
    fi
    saveTaskStatus ${TASK_STATUS} ${SAVE_TASK_CODE}
fi