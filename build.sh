#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source getDynamicVars.sh
source set_npmrc.sh
source jacoco-sonar-nexus.sh

TASK_STATUS=0

ACTIVITY_SUB_TASK_CODE="MVN_EXECUTE_${INSTRUCTION_TYPE}"

# Set the codebase location
CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll $INSTRUCTION_TYPE the code available at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

# saveTaskStatusNew ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE} "CODEBASE LOCATION SET" "Codebase path configured successfully"

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
        source /usr/local/bin/switch_versions.sh
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
        "SONAR_SCAN" )
            if [[ "$SONAR_TESTING_TYPE" == "Unit" && -n "${MAVEN_UT_INSTRUCTION:-}" ]]; then
                export INSTRUCTION="$MAVEN_UT_INSTRUCTION"
            else
                export INSTRUCTION="$MAVEN_SONAR_SCAN_INSTRUCTION"
            fi
            ;;
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

# If finalized INSTRUCTION contains a custom Maven settings path, set it as default (~/.m2/settings.xml)
SETTINGS_PATH=""
if [[ -n "$INSTRUCTION" ]]; then
    # Tokenize to robustly handle "--settings <path>" and "-s <path>", as well as equals forms
    read -r -a __WORDS <<< "$INSTRUCTION"
    for (( __i=0; __i<${#__WORDS[@]}; __i++ )); do
        __w="${__WORDS[__i]}"
        case "$__w" in
            --settings=*) SETTINGS_PATH="${__w#--settings=}" ;;
            --settings)
                if (( __i+1<${#__WORDS[@]} )); then SETTINGS_PATH="${__WORDS[__i+1]}"; fi ;;
            -s=*) SETTINGS_PATH="${__w#-s=}" ;;
            -s)
                if (( __i+1<${#__WORDS[@]} )); then SETTINGS_PATH="${__WORDS[__i+1]}"; fi ;;
        esac
    done
    if [[ -n "$SETTINGS_PATH" ]]; then
        # Resolve relative path from current CODEBASE_LOCATION if needed
        if [[ ! -f "$SETTINGS_PATH" && -f "$CODEBASE_LOCATION/$SETTINGS_PATH" ]]; then
            SETTINGS_PATH="$CODEBASE_LOCATION/$SETTINGS_PATH"
        fi
        if [[ -f "$SETTINGS_PATH" ]]; then
            mkdir -p "$HOME/.m2"
            cp -f "$SETTINGS_PATH" "$HOME/.m2/settings.xml"
            logInfoMessage "Applied custom Maven settings from [$SETTINGS_PATH] to [$HOME/.m2/settings.xml]"
        else
            logErrorMessage "Specified Maven settings file not found: $SETTINGS_PATH"
        fi
    fi
fi

# Ensure it's empty if null or not present
MAVEN_OPTIONS=${MAVEN_OPTIONS:-}

# Determine suffix based on SONAR_TESTING_TYPE
SONAR_SUFFIX=""
case "$SONAR_TESTING_TYPE" in
    Integration)
        SONAR_SUFFIX="-it"
        ;;
    Unit)
        SONAR_SUFFIX="-ut"
        ;;
    *)
        SONAR_SUFFIX=""
        ;;
esac

if [[ "$INSTRUCTION_TYPE" == "SONAR_SCAN" ]]; then
    # Optional feature-flag to use Nexus + JaCoCo merge helper
    if [[ "${ENABLE_JACOCO_NEXUS,,}" == "true" ]]; then
        logInfoMessage "Using jacoco-sonar-nexus.sh helper for [$SONAR_TESTING_TYPE]"

        # Map env for helper script
        export SONAR_HOST_URL="${SONAR_HOST_URL:-$SONAR_URL}"
        # Ensure SONAR_TOKEN is exported for child script
        export SONAR_TOKEN="${SONAR_TOKEN}"
        export BASE_PROJECT_KEY="${BASE_PROJECT_KEY:-$CODEBASE_DIR}"

        # Allow alternative Nexus credentials variable names
        export USERNAME="${USERNAME:-${NEXUS_USERNAME:-}}"
        export PASSWORD="${PASSWORD:-${NEXUS_PASSWORD:-}}"

        # Prefer Maven plugin for JaCoCo unless explicitly overridden
        export JACOCO_TOOL="${JACOCO_TOOL:-mvn}"

        # Best-effort default for UT exec path if not provided
        if [[ -z "${JACOCO_FILE_PATH:-}" ]]; then
            GUESS_JACOCO=$(find . -type f -path "*/target/jacoco.exec" | head -n1 || true)
            if [[ -n "$GUESS_JACOCO" ]]; then
                export JACOCO_FILE_PATH="$GUESS_JACOCO"
                logInfoMessage "Detected JACOCO_FILE_PATH at [$JACOCO_FILE_PATH]"
            fi
        fi

        SCRIPT_DIR="$(dirname "$0")"
        case "$SONAR_TESTING_TYPE" in
            Unit)
                logInfoMessage "Running UT upload + Sonar via helper"
                jacoco_sonar_nexus ut
                ;;
            Integration)
                logInfoMessage "Running IT download + merge + Sonar via helper"
                jacoco_sonar_nexus it-merge
                ;;
            *)
                logErrorMessage "ENABLE_JACOCO_NEXUS=true requires SONAR_TESTING_TYPE to be 'Unit' or 'Integration'"
                exit 1
                ;;
        esac
    else
        logInfoMessage "Executing Sonar Scan for project [$CODEBASE_DIR$SONAR_SUFFIX]"

        # Log command safely (hide token)
        logInfoMessage "mvn $INSTRUCTION $MAVEN_OPTIONS -Dsonar.projectKey=$CODEBASE_DIR$SONAR_SUFFIX -Dsonar.projectName=$CODEBASE_DIR$SONAR_SUFFIX -Dsonar.host.url=$SONAR_URL -Dsonar.login=******"

        # Execute actual command
        mvn $INSTRUCTION $MAVEN_OPTIONS \
            -Dsonar.projectKey="${CODEBASE_DIR}${SONAR_SUFFIX}" \
            -Dsonar.projectName="${CODEBASE_DIR}${SONAR_SUFFIX}" \
            -Dsonar.host.url="$SONAR_URL" \
            -Dsonar.login="$SONAR_TOKEN"
    fi
else
    logInfoMessage "Executing mvn $INSTRUCTION $MAVEN_OPTIONS"
    mvn $INSTRUCTION $MAVEN_OPTIONS
fi

TASK_STATUS=$?

# Save the task status
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
# saveTaskStatusNew ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE} "Executed mvn command" "Executed mvn $INSTRUCTION $MAVEN_OPTIONS"

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
    # saveTaskStatusNew ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE} "Analyzed mvn test reports" "Executed mvn $INSTRUCTION $MAVEN_OPTIONS" 
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
    # saveTaskStatusNew ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE} "Analyzed maven custom test report" "Executed mvn $INSTRUCTION $MAVEN_OPTIONS"
fi