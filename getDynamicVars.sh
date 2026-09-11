source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/proxy-handling.sh

# Set GIT_SSL_FLAG to the git config flag when SSL verification should be disabled.
# Usage: export GIT_SSL_FLAG=true  → passes -c http.sslVerify=false to git commands
#        GIT_SSL_FLAG unset/empty  → plain git clone with no extra flags
GIT_SSL_FLAG="${GIT_SSL_FLAG:-}"

# Function to clone the repository, extract details, and set environment variables
function fetch_service_details() {

    # Build the git SSL option array based on GIT_SSL_FLAG
    local git_ssl_opts=()
    if [[ "$GIT_SSL_FLAG" == "true" ]]; then
        git_ssl_opts=(-c http.sslVerify=false)
        echo "SSL verification disabled for git operations."
    fi

    # Repository details
    # local SOURCE_VARIABLE_REPO="https://github.com/buildpipermasterpipeline.git"
    local LOCAL_REPO_DIR="/tmp/buildpipermasterpipeline"

    # Ensure the directory exists
    if [ ! -d "$LOCAL_REPO_DIR" ]; then
        echo "Directory $LOCAL_REPO_DIR does not exist. Creating it..."
        mkdir -p "$LOCAL_REPO_DIR" || { echo "Failed to create directory $LOCAL_REPO_DIR."; return 1; }
    fi

    # Clone the repository with retry logic (3 attempts total)
    if [ ! -d "$LOCAL_REPO_DIR/.git" ]; then
        echo "Cloning repository $SOURCE_VARIABLE_REPO into $LOCAL_REPO_DIR on branch $APPLICATION_NAME with depth 2..."

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
            output=$(run_without_proxy_then_with_fallback git "${git_ssl_opts[@]}" clone --branch "$APPLICATION_NAME" --depth 2 "$SOURCE_VARIABLE_REPO" "$LOCAL_REPO_DIR" 2>&1)
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
        git "${git_ssl_opts[@]}" fetch origin "$APPLICATION_NAME" --depth 2 || { echo "Error: Fetching latest changes failed."; return 1; }
        git "${git_ssl_opts[@]}" pull origin "$APPLICATION_NAME" || { echo "Error: Pulling latest changes failed for branch $APPLICATION_NAME."; return 1; }
    fi

    # Path to the mavenrepos.json file
    local json_file="$LOCAL_REPO_DIR/mavenrepos.json"

    # Check if mavenrepos.json exists
    if [ ! -f "$json_file" ]; then
        echo "Error: $json_file not found for branch $APPLICATION_NAME"
        return 1
    fi

    # Find the service details in the JSON file
    echo "Extracting service details for $CODEBASE_DIR..."

    # Check if CODEBASE_DIR is not set or empty, use getServiceName to get a default value
    if [ -z "$CODEBASE_DIR" ]; then
        CODEBASE_DIR=$(echo "$DEPLOY_SERVICE_NAME" | sed -E 's/-(dev|prod|qa|staging|uat)-.*$//')
        echo "CODEBASE_DIR was empty, using deployment service name: $CODEBASE_DIR"
    fi

    local service_data=$(jq -r --arg CODEBASE_DIR "$CODEBASE_DIR" '.repositories[] | select(.bitbucketRepoName == $CODEBASE_DIR)' "$json_file")

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
}