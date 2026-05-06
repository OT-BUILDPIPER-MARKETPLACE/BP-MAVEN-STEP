#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source getDynamicVars.sh
source set_npmrc.sh

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

TASK_STATUS=0
WORKSPACE="${WORKSPACE:-/bp/workspace}"
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
SAVE_TASK_CODE="MVN_EXECUTE_${INSTRUCTION_TYPE}"

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
logInfoMessage "> Starting step: maven"
logInfoMessage "> Instruction type : ${INSTRUCTION_TYPE}"
logInfoMessage "> Codebase location: ${CODEBASE_LOCATION}"

add_event "INITIALIZATION" "Successful" \
    "Maven step initialized for ${INSTRUCTION_TYPE}" \
    "Codebase: ${CODEBASE_DIR} | Instruction type: ${INSTRUCTION_TYPE}"

sleep "$SLEEP_DURATION"

set_npmrc

# ---------------------------------------------------------------
# 2. Workspace Navigation
# ---------------------------------------------------------------
logInfoMessage "> Navigating to codebase directory..."

cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "> Failed to navigate to codebase directory: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Failed to navigate to codebase directory" \
        "Path: ${CODEBASE_LOCATION} | Verify WORKSPACE and CODEBASE_DIR are set correctly"
    saveTaskStatus 1 "${SAVE_TASK_CODE}"
    exit 1
}

logInfoMessage "> Successfully navigated to: ${CODEBASE_LOCATION}"
add_event "WORKSPACE_NAVIGATION" "Successful" \
    "Navigated to codebase directory" \
    "Path: ${CODEBASE_LOCATION}"

# ---------------------------------------------------------------
# 3. Source Variable Resolution
# ---------------------------------------------------------------
logInfoMessage "> Resolving source variables..."

if [ -n "$SOURCE_VARIABLE_REPO" ]; then
    if [ -n "$INSTRUCTION" ]; then
        logInfoMessage "> INSTRUCTION already provided — skipping SOURCE_VARIABLE_REPO fetch"
    else
        logInfoMessage "> Fetching details from SOURCE_VARIABLE_REPO: ${SOURCE_VARIABLE_REPO}"
        fetch_service_details
        source /usr/local/bin/switch_versions.sh
    fi
else
    logInfoMessage "> SOURCE_VARIABLE_REPO not defined — skipping fetch"
fi

# ---------------------------------------------------------------
# 4. Instruction Resolution
# ---------------------------------------------------------------
logInfoMessage "> Resolving Maven instruction..."

if [ -z "$INSTRUCTION" ]; then
    case "$INSTRUCTION_TYPE" in
        "BUILD")      export INSTRUCTION=$MAVEN_BUILD_INSTRUCTION ;;
        "DEPLOY")     export INSTRUCTION=$MAVEN_DEPLOY_INSTRUCTION ;;
        "TEST")       export INSTRUCTION=$MAVEN_TEST_INSTRUCTION ;;
        "CUSTOM")     export INSTRUCTION=$MAVEN_CUSTOM_INSTRUCTION ;;
        "SONAR_SCAN") export INSTRUCTION=$MAVEN_SONAR_SCAN_INSTRUCTION ;;
        *)
            logErrorMessage "> Unsupported INSTRUCTION_TYPE: '${INSTRUCTION_TYPE}' — falling back to default mvn ${INSTRUCTION}"
            ;;
    esac
fi

if [ -z "$INSTRUCTION" ]; then
    logErrorMessage "> INSTRUCTION is not set. Cannot proceed."
    add_event "INSTRUCTION_RESOLUTION" "Failed" \
        "INSTRUCTION variable is not set — cannot determine Maven command" \
        "Check pipeline config for INSTRUCTION or INSTRUCTION_TYPE: ${INSTRUCTION_TYPE}"
    saveTaskStatus 1 "${SAVE_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Resolved instruction: mvn ${INSTRUCTION}"
add_event "INSTRUCTION_RESOLUTION" "Successful" \
    "Maven instruction resolved for ${INSTRUCTION_TYPE}" \
    "Instruction: mvn ${INSTRUCTION} | Type: ${INSTRUCTION_TYPE}"

# ---------------------------------------------------------------
# 5. CodeArtifact Auth (if enabled)
# ---------------------------------------------------------------
if [[ "${CODEARTIFACT}" = "true" ]]; then
    logInfoMessage "> CodeArtifact enabled — generating AWS auth token..."

    if [[ -n "$DOMAIN" && -n "$DOMAIN_OWNER" && -n "$REGION" ]]; then
        add_event "CODEARTIFACT_AUTH" "Successful" \
            "Generating AWS CodeArtifact auth token" \
            "Domain: ${DOMAIN} | Region: ${REGION}"

        export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
            --domain "$DOMAIN" \
            --domain-owner "$DOMAIN_OWNER" \
            --region "$REGION" \
            --query authorizationToken \
            --output text)

        logInfoMessage "> CodeArtifact auth token generated successfully"
    else
        logErrorMessage "> Required CodeArtifact variables missing (DOMAIN, DOMAIN_OWNER, REGION)"
        add_event "CODEARTIFACT_AUTH" "Failed" \
            "Required env variables missing for CodeArtifact auth" \
            "Check DOMAIN, DOMAIN_OWNER, and REGION in pipeline config"
        saveTaskStatus 1 "${SAVE_TASK_CODE}"
        exit 1
    fi
fi

# ---------------------------------------------------------------
# 6. Extra Command (if provided)
# ---------------------------------------------------------------
if [[ -n "$EXTRA_COMMAND" ]]; then
    logInfoMessage "> Executing extra command: ${EXTRA_COMMAND}"
    eval "$EXTRA_COMMAND"
fi

MAVEN_OPTIONS=${MAVEN_OPTIONS:-}

# ---------------------------------------------------------------
# 7. Maven Execution
# ---------------------------------------------------------------
SONAR_SUFFIX=""
case "$SONAR_TESTING_TYPE" in
    Integration) SONAR_SUFFIX="-it" ;;
    Unit)        SONAR_SUFFIX="-ut" ;;
    *)           SONAR_SUFFIX="" ;;
esac

echo ""
echo "> Maven Execution Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Instruction Type" "${INSTRUCTION_TYPE}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Codebase" "${CODEBASE_DIR}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Maven Instruction" "${INSTRUCTION}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Maven Options" "${MAVEN_OPTIONS:-(none)}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

if [[ "$INSTRUCTION_TYPE" == "SONAR_SCAN" ]]; then
    logInfoMessage "> Executing Sonar Scan for project: ${CODEBASE_DIR}${SONAR_SUFFIX}"
    logInfoMessage "> Command: mvn ${INSTRUCTION} ${MAVEN_OPTIONS} -Dsonar.projectKey=${CODEBASE_DIR}${SONAR_SUFFIX} -Dsonar.projectName=${CODEBASE_DIR}${SONAR_SUFFIX} -Dsonar.host.url=${SONAR_URL} -Dsonar.login=******"

    add_event "MAVEN_EXECUTION" "Successful" \
        "Executing Sonar Scan" \
        "Project key: ${CODEBASE_DIR}${SONAR_SUFFIX} | Sonar URL: ${SONAR_URL}"

    mvn $INSTRUCTION $MAVEN_OPTIONS \
        -Dsonar.projectKey="${CODEBASE_DIR}${SONAR_SUFFIX}" \
        -Dsonar.projectName="${CODEBASE_DIR}${SONAR_SUFFIX}" \
        -Dsonar.host.url="$SONAR_URL" \
        -Dsonar.login="$SONAR_TOKEN"
else
    logInfoMessage "> Executing: mvn ${INSTRUCTION} ${MAVEN_OPTIONS}"

    add_event "MAVEN_EXECUTION" "Successful" \
        "Executing Maven command for ${INSTRUCTION_TYPE}" \
        "Command: mvn ${INSTRUCTION} ${MAVEN_OPTIONS}"

    mvn $INSTRUCTION $MAVEN_OPTIONS
fi

TASK_STATUS=$?

if [ "${TASK_STATUS}" -eq 0 ]; then
    logInfoMessage "> Maven execution completed successfully (exit: ${TASK_STATUS})"
    add_event "MAVEN_EXECUTION_RESULT" "Successful" \
        "Maven command completed successfully" \
        "Instruction: ${INSTRUCTION_TYPE} | Exit Code: ${TASK_STATUS}"
else
    logErrorMessage "> Maven execution failed (exit: ${TASK_STATUS})"
    add_event "MAVEN_EXECUTION_RESULT" "Failed" \
        "Maven command failed — review build logs above" \
        "Instruction: ${INSTRUCTION_TYPE} | Exit Code: ${TASK_STATUS}"
fi

saveTaskStatus "${TASK_STATUS}" "${SAVE_TASK_CODE}"

# ---------------------------------------------------------------
# 8. JUnit XML Test Analysis (TEST only)
# ---------------------------------------------------------------
if [[ "$INSTRUCTION_TYPE" == "TEST" ]]; then
    logInfoMessage "> Parsing JUnit XML reports from target/surefire-reports/..."

    add_event "TEST_ANALYSIS" "Successful" \
        "Parsing JUnit XML test reports" \
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
        logErrorMessage "> No test results found in target/surefire-reports/"
        add_event "TEST_ANALYSIS" "Failed" \
            "No JUnit XML test results found to parse" \
            "Check target/surefire-reports/ directory exists and contains TEST-*.xml files"
        saveTaskStatus 1 "${SAVE_TASK_CODE}"
        exit 1
    fi

    FAIL_PERCENT=$(( 100 * FAIL / TOTAL ))
    THRESHOLD="${TEST_FAILURE_THRESHOLD:-50}"

    echo ""
    echo "> JUnit Test Analysis Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Total Tests" "${TOTAL}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Failed / Errors" "${FAIL}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Failure Rate" "${FAIL_PERCENT}%"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Threshold" "${THRESHOLD}%"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    logInfoMessage "> Copying surefire-reports to /bp/execution_dir/${GLOBAL_TASK_ID}/"
    cp -rf target/surefire-reports "/bp/execution_dir/${GLOBAL_TASK_ID}/"

    logWarningMessage "> Test failure rate: ${FAIL_PERCENT}% (Threshold: ${THRESHOLD}%)"

    if (( FAIL_PERCENT > THRESHOLD )); then
        logErrorMessage "> Failure rate ${FAIL_PERCENT}% exceeds threshold ${THRESHOLD}% — failing build"
        add_event "TEST_THRESHOLD" "Failed" \
            "Failure rate ${FAIL_PERCENT}% exceeds threshold ${THRESHOLD}% — build failed" \
            "Total: ${TOTAL} | Failed: ${FAIL} | Threshold: ${THRESHOLD}%"
        TASK_STATUS=1
    else
        logInfoMessage "> Test failure rate ${FAIL_PERCENT}% is within threshold ${THRESHOLD}%"
        add_event "TEST_THRESHOLD" "Successful" \
            "Test failure rate ${FAIL_PERCENT}% is within threshold ${THRESHOLD}%" \
            "Total: ${TOTAL} | Failed: ${FAIL} | Threshold: ${THRESHOLD}%"
    fi

    saveTaskStatus "${TASK_STATUS}" "${SAVE_TASK_CODE}"
fi

# ---------------------------------------------------------------
# 9. Custom HTML Test Analysis (TEST + ENABLE_CUSTOM_HTML_SCAN)
# ---------------------------------------------------------------
if [[ "$INSTRUCTION_TYPE" == "TEST" && "${ENABLE_CUSTOM_HTML_SCAN,,}" == "true" ]]; then
    logInfoMessage "> Parsing custom HTML test reports..."

    add_event "HTML_REPORT_SCAN" "Successful" \
        "Parsing custom HTML test reports" \
        "Directory: ${TEST_RESULT_DIR:-Results}"

    TEST_RESULT_DIR="${TEST_RESULT_DIR:-Results}"
    REPORT_HTML=$(find "$TEST_RESULT_DIR" -type f -name "*.html" -printf "%T@ %p\n" | sort -nr | head -1 | awk '{print $2}')
    THRESHOLD="${TEST_FAILURE_THRESHOLD:-50}"

    if [[ -z "$REPORT_HTML" || ! -f "$REPORT_HTML" ]]; then
        logErrorMessage "> No HTML report found in: ${TEST_RESULT_DIR}"
        add_event "HTML_REPORT_SCAN" "Failed" \
            "No HTML report file found in configured directory" \
            "Target path: ${TEST_RESULT_DIR} | Verify TEST_RESULT_DIR is set correctly"
        saveTaskStatus 1 "${SAVE_TASK_CODE}"
        exit 1
    fi

    logInfoMessage "> Found HTML report: ${REPORT_HTML}"

    TOTAL=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Tests executed')]]/td[2])" "$REPORT_HTML" 2>/dev/null)
    PASS=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Pass Test count')]]/td[2])" "$REPORT_HTML" 2>/dev/null)
    FAIL=$(xmllint --html --xpath "string(//tr[td[contains(., 'Total Fail Test count')]]/td[2])" "$REPORT_HTML" 2>/dev/null)

    FAIL_PERCENT=$(( 100 * FAIL / TOTAL ))

    echo ""
    echo "> HTML Test Report Summary"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Parameter" "Value"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Report File" "${REPORT_HTML}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Total Tests" "${TOTAL}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Passed" "${PASS}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Failed" "${FAIL}"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Failure Rate" "${FAIL_PERCENT}%"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    printf '| %-28s | %-48s |\n' "Threshold" "${THRESHOLD}%"
    printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
    echo ""

    logInfoMessage "> Copying HTML results to /bp/execution_dir/${GLOBAL_TASK_ID}/"
    cp -rf "$TEST_RESULT_DIR" "/bp/execution_dir/${GLOBAL_TASK_ID}/"

    if (( FAIL_PERCENT > THRESHOLD )); then
        logErrorMessage "> HTML test failure rate (${FAIL_PERCENT}%) exceeds threshold (${THRESHOLD}%) — failing build"
        add_event "HTML_TEST_THRESHOLD" "Failed" \
            "HTML report failure rate ${FAIL_PERCENT}% exceeds threshold ${THRESHOLD}%" \
            "Report: ${REPORT_HTML} | Failed: ${FAIL}/${TOTAL}"
        TASK_STATUS=1
    else
        logInfoMessage "> HTML test failure rate ${FAIL_PERCENT}% is within threshold ${THRESHOLD}%"
        add_event "HTML_TEST_THRESHOLD" "Successful" \
            "HTML report failure rate ${FAIL_PERCENT}% is within threshold ${THRESHOLD}%" \
            "Report: ${REPORT_HTML} | Passed: ${PASS}/${TOTAL}"
        TASK_STATUS=0
    fi

    saveTaskStatus "${TASK_STATUS}" "${SAVE_TASK_CODE}"
fi