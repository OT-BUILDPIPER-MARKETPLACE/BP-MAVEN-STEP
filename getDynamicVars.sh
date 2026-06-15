source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/proxy-handling.sh
source /opt/buildpiper/shell-functions/getDataFile.sh   

# ----------------------------------------------------
# Resolve application name based on activity
# ----------------------------------------------------
resolve_application_name() {

    # Default to pipeline value
    RESOLVED_APPLICATION_NAME="$APPLICATION_NAME"

    local APP_ENV
    APP_ENV=$(get_application_and_env)
    local APPLICATION="${APP_ENV%%:*}"
    local ENVIRONMENT="${APP_ENV##*:}"

    # Rollback → override only for repo checkout
    if [[ "$ACTIVITY_MASTER_CODE" == "ROLLBACK_STATELESS_APP" ]]; then
        local ROLLBACK_APP_NAME
        ROLLBACK_APP_NAME=$APPLICATION

        if [[ -n "$ROLLBACK_APP_NAME" && "$ROLLBACK_APP_NAME" != "null" ]]; then
            RESOLVED_APPLICATION_NAME="$ROLLBACK_APP_NAME"
        fi
    fi

    echo "Resolved Application Name (repo branch): $RESOLVED_APPLICATION_NAME"
}

# Function to clone the repository, extract details, and set environment variables
function fetch_service_details() {
    
    resolve_application_name
    
    # Repository details
    # local SOURCE_VARIABLE_REPO="https://github.com/buildpipermasterpipeline.git"
    local LOCAL_REPO_DIR="/tmp/buildpipermasterpipeline"

    # Ensure the directory exists
    if [ ! -d "$LOCAL_REPO_DIR" ]; then
        echo "Directory $LOCAL_REPO_DIR does not exist. Creating it..."
        mkdir -p "$LOCAL_REPO_DIR" || { echo "Error: Failed to create directory $LOCAL_REPO_DIR."; return 1; }
    fi

    # Clone the repository with retry logic (3 attempts total)
    if [ ! -d "$LOCAL_REPO_DIR/.git" ]; then
        echo "Cloning repository $SOURCE_VARIABLE_REPO into $LOCAL_REPO_DIR on branch $RESOLVED_APPLICATION_NAME with depth 2..."

        attempt=1
        max_attempts=3
        wait_times=(0 30 60)

        while [ $attempt -le $max_attempts ]; do
            if [ $attempt -gt 1 ]; then
                sleep_time=${wait_times[$((attempt-1))]}
                echo "Retrying clone attempt $attempt after $sleep_time seconds..."
                sleep "$sleep_time"
            fi

            echo "Attempt $attempt: Cloning..."
            output=$(run_without_proxy_then_with_fallback git clone --branch "$RESOLVED_APPLICATION_NAME" --depth 2 "$SOURCE_VARIABLE_REPO" "$LOCAL_REPO_DIR" 2>&1)
            clone_status=$?

            if [ $clone_status -eq 0 ]; then
                echo "Clone successful on attempt $attempt."
                break
            else
                echo "Clone attempt $attempt failed: $output"
            fi

            attempt=$((attempt + 1))
        done

        if [ $clone_status -ne 0 ]; then
            echo "Error: Cloning failed after $max_attempts attempts."
            return 1
        fi
    else
        echo "Repository already exists. Fetching latest changes..."
        cd "$LOCAL_REPO_DIR" || { echo "Error: Cannot change directory to $LOCAL_REPO_DIR"; return 1; }
        git fetch origin "$RESOLVED_APPLICATION_NAME" --depth 2 || { echo "Error: Fetching latest changes failed."; return 1; }
        git pull origin "$RESOLVED_APPLICATION_NAME" || { echo "Error: Pulling latest changes failed for branch $RESOLVED_APPLICATION_NAME."; return 1; }
    fi

    # Path to the mavenrepos.json file
    local json_file="$LOCAL_REPO_DIR/mavenrepos.json"
    local env_suffixes_file="$LOCAL_REPO_DIR/env_suffixes.txt"  # <-- Path for env suffixes file
    local yq_query_file="$LOCAL_REPO_DIR/deployment_patch.yq"  # <-- Path for yq query file

    # Check if mavenrepos.json exists
    if [ ! -f "$json_file" ]; then
        echo "Error: $json_file not found for branch $RESOLVED_APPLICATION_NAME"
        return 1
    fi

    # ----------------------------------------------------
    # Resolve CODEBASE_DIR / GIT SOURCE per activity
    # ----------------------------------------------------
    resolve_codebase_dir() {
        # ---------------- BUILD ----------------
        # Build must use workspace repo
        if [[ "$ACTIVITY_MASTER_CODE" == "ENVIRONMENT_BUILD" ]]; then
            if [[ -n "$CODEBASE_DIR" ]]; then
                echo "Using CODEBASE_DIR from build workspace: $CODEBASE_DIR"
                return
            fi
        fi
        # ---------------- DEPLOY & ROLLBACK ----------------
        # Use git_repo stored in metadata
        if [[ "$ACTIVITY_MASTER_CODE" == "deploy_stateless_app" || "$ACTIVITY_MASTER_CODE" == "ROLLBACK_STATELESS_APP" ]]; then

            local META_FILE=""
            if [[ "$ACTIVITY_MASTER_CODE" == "deploy_stateless_app" ]]; then
                META_FILE="/bp/data/deploy_stateless_app"
            else
                META_FILE="/bp/data/ROLLBACK_STATELESS_APP"
            fi

            if [[ -f "$META_FILE" ]]; then
                GIT_REPO=$(jq -r '.git_repo // .buildpiper_meta_data.git_repo // empty' "$META_FILE" 2>/dev/null)

                if [[ -n "$GIT_REPO" ]]; then
                    CODEBASE_DIR=$(basename "$GIT_REPO" .git)
                    echo "Derived CODEBASE_DIR from git_repo: $CODEBASE_DIR"
                    return
                fi
            fi
        fi
        # ---------------- FINAL FALLBACK ----------------
        # Use COMPONENT_NAME instead of service name
        if [[ -z "$CODEBASE_DIR" && -n "$COMPONENT_NAME" ]]; then

            # remove environment and infra suffix patterns
            CODEBASE_DIR=$(echo "$COMPONENT_NAME" | sed -E '
                s/-(dev|prod|qa|staging|uat|sit)-.*$//;
                s/-buildpiper.*$//;
                s/-k8s.*$//;
                s/-service$//;
                s/-svc$//;
            ')
            echo "Fallback CODEBASE_DIR derived from COMPONENT_NAME: $CODEBASE_DIR"
            return
        fi
        # ---------------- LAST SAFETY ----------------
        if [[ -z "$CODEBASE_DIR" ]]; then
            echo "WARNING: Unable to resolve CODEBASE_DIR — dynamic notification mapping may fail"
        fi
    }

    # Find the service details in the JSON file
    echo "Extracting service details for $CODEBASE_DIR..."
    # Execute resolver
    resolve_codebase_dir

    # # Function to get the deployment service name
    # function getDeploymentServiceName() {
    #   DEPLOY_SERVICE_NAME=$(jq -r '.k8s_manifest[] | select(.k8s_manifest_type == "service") | .metadata.name' < /bp/data/deploy_stateless_app)
    #   echo "$DEPLOY_SERVICE_NAME"
    # }
    
    # # Check if CODEBASE_DIR is not set or empty, use deployment service name
    # if [ -z "$CODEBASE_DIR" ]; then
    #     # Get the deployment service name
    #     DEPLOY_SERVICE_NAME=$(getDeploymentServiceName)
    #     CODEBASE_DIR=$(echo "$DEPLOY_SERVICE_NAME" | sed -E 's/-(dev|prod|qa|staging|uat)-.*$//')
    #     echo "CODEBASE_DIR was empty, using deployment service name: $CODEBASE_DIR"
    # fi
    
    # Try to match CODEBASE_DIR with repositories[]
    service_data=$(jq -r --arg CODEBASE_DIR "$CODEBASE_DIR" '.repositories[] | select(.bitbucketRepoName == $CODEBASE_DIR)' "$json_file")
    
    # If not matched, fallback to value of git_repo from deployment env
    if [ -z "$service_data" ]; then
        echo "No matching repo for CODEBASE_DIR: $CODEBASE_DIR. Falling back to git_repo from deployment env."
    
        # Extract git_repo value from the container env
        git_repo_value=$(jq -r '
          .k8s_manifest[]
          | select(.k8s_manifest_type == "deployment")
          | .spec.template.spec.containers[]
          | .env[]
          | select(.name == "git_repo")
          | .value
        ' /bp/data/deploy_stateless_app)
    
        if [ -n "$git_repo_value" ]; then
            CODEBASE_DIR="$git_repo_value"
            echo "Using git_repo value as CODEBASE_DIR: $CODEBASE_DIR"
            service_data=$(jq -r --arg CODEBASE_DIR "$CODEBASE_DIR" '.repositories[] | select(.bitbucketRepoName == $CODEBASE_DIR)' "$json_file")
        fi
    fi
    
    # Final check if still not found
    if [ -z "$service_data" ]; then
        echo "Error: Service $CODEBASE_DIR not found in $json_file"
        return 1
    fi

    # Extract the specific details and export them as environment variables
    export JAVA_VERSION=$(echo "$service_data" | jq -r '.JAVA_VERSION')    
    export MAVEN_VERSION=$(echo "$service_data" | jq -r '.MAVEN_VERSION')
    export MAVEN_BUILD_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_BUILD_INSTRUCTION')
    export MAVEN_DEPLOY_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_DEPLOY_INSTRUCTION')
    export MAVEN_TEST_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_TEST_INSTRUCTION')
    export MAVEN_CUSTOM_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_CUSTOM_INSTRUCTION')
    export TEST_FAILURE_THRESHOLD=$(echo "$service_data" | jq -r '.TEST_FAILURE_THRESHOLD')
    export TEST_RESULT_DIR=$(echo "$service_data" | jq -r '.TEST_RESULT_DIR')
    # Extract MAVEN_OPTIONS (may be null or empty)
    MAVEN_OPTIONS=$(echo "$service_data" | jq -r '.MAVEN_OPTIONS // empty')
    export TEST_JAVA_VERSION=$(echo "$service_data" | jq -r '.TEST_JAVA_VERSION')
    export TEST_MAVEN_VERSION=$(echo "$service_data" | jq -r '.TEST_MAVEN_VERSION')
    export MAVEN_SONAR_SCAN_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_SONAR_SCAN_INSTRUCTION')
    export SONAR_URL=$(echo "$service_data" | jq -r '.SONAR_URL')
    export ENCRYPTED_SONAR_TOKEN=$(echo "$service_data" | jq -r '.ENCRYPTED_SONAR_TOKEN')

    # Decrypt the token using the getDecryptedCredential function
    SONAR_TOKEN=$(getDecryptedCredential "$FERNET_KEY" "$ENCRYPTED_SONAR_TOKEN")

    # Override versions if INSTRUCTION_TYPE=TEST
    if [[ "$INSTRUCTION_TYPE" == "TEST" ]]; then
      export JAVA_VERSION="$TEST_JAVA_VERSION"
      export MAVEN_VERSION="$TEST_MAVEN_VERSION"
    fi

    # Remove the cloned repository
    echo "Removing the cloned repository..."
    rm -rf "$LOCAL_REPO_DIR" || { echo "Error: Failed to remove directory $LOCAL_REPO_DIR."; return 1; }

    echo "Environment variables have been set and repository has been removed."
    bash /usr/local/bin/switch_versions.sh

    echo "Environment variables have been set and repository has been removed."
}