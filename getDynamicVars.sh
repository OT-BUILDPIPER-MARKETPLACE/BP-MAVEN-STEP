source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/proxy-handling.sh

# Set GIT_SSL_FLAG to the git config flag when SSL verification should be disabled.
GIT_SSL_FLAG="${GIT_SSL_FLAG:-}"

# Function to clone the repository, extract details, and set environment variables
function fetch_service_details() {

    # --------------------------------------------------
    # Fetch Git Integration details
    # --------------------------------------------------
    for VAR in FERNET_KEY GIT_REPO; do
        if [[ -z "${!VAR:-}" ]]; then
            echo "ERROR: $VAR is not set"
            return 1
        fi
    done

    # --------------------------------------------------
    # Decrypt Git credentials and extract Git URL/branch
    # --------------------------------------------------
    python3 - <<'PY' > /tmp/git_creds
import os
import json
from cryptography.fernet import Fernet

repo = json.loads(os.environ["GIT_REPO"])["integration_1"]

fernet = Fernet(os.environ["FERNET_KEY"].encode())

username = fernet.decrypt(
    repo["GIT_USERNAME"].encode()
).decode()

password = fernet.decrypt(
    repo["GIT_PASSWORD"].encode()
).decode()

git_url = repo.get("GIT_URL", "")

print(username)
print(password)
print(git_url)
PY

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Git credential decryption failed"
        return 1
    fi

    # --------------------------------------------------
    # Read decrypted values
    # --------------------------------------------------
    GIT_USERNAME=$(sed -n '1p' /tmp/git_creds)
    GIT_PASSWORD=$(sed -n '2p' /tmp/git_creds)
    GIT_URL=$(sed -n '3p' /tmp/git_creds)

    rm -f /tmp/git_creds

    # --------------------------------------------------
    # Validate Git details
    # --------------------------------------------------
    if [[ -z "$GIT_USERNAME" || -z "$GIT_PASSWORD" ]]; then
        echo "ERROR: Git username/password is empty after decryption"
        return 1
    fi

    if [[ -z "$GIT_URL" ]]; then
        echo "ERROR: Git URL could not be determined"
        return 1
    fi

   

    logInfoMessage "Git credentials decrypted successfully"
    logInfoMessage "Git URL    : $GIT_URL"

    # --------------------------------------------------
    # Map integration values to existing variables
    # --------------------------------------------------
    export SOURCE_VARIABLE_REPO="$GIT_URL"

    # --------------------------------------------------
    # Git authentication
    # --------------------------------------------------
    export GIT_USERNAME
    export GIT_PASSWORD
    export GIT_TERMINAL_PROMPT=0

    export GIT_ASKPASS="/tmp/git-askpass.sh"

    cat > "$GIT_ASKPASS" <<'EOF'
#!/bin/bash

if [[ "$1" == *Username* || "$1" == *username* ]]; then
    echo "$GIT_USERNAME"
elif [[ "$1" == *Password* || "$1" == *password* ]]; then
    echo "$GIT_PASSWORD"
fi
EOF

    chmod 700 "$GIT_ASKPASS"

    # --------------------------------------------------
    # Build Git SSL option
    # --------------------------------------------------
    local git_ssl_opts=()

    if [[ "$GIT_SSL_FLAG" == "true" ]]; then
        git_ssl_opts=(-c http.sslVerify=false)
        echo "SSL verification disabled for git operations."
    fi

    # --------------------------------------------------
    # Repository details
    # --------------------------------------------------
    local LOCAL_REPO_DIR="/tmp/buildpipermasterpipeline"

    if [ ! -d "$LOCAL_REPO_DIR" ]; then
        echo "Directory $LOCAL_REPO_DIR does not exist. Creating it..."

        mkdir -p "$LOCAL_REPO_DIR" || {
            echo "Failed to create directory $LOCAL_REPO_DIR."
            rm -f "$GIT_ASKPASS"
            return 1
        }
    fi

    # --------------------------------------------------
    # Clone repository
    # --------------------------------------------------
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

            output=$(run_without_proxy_then_with_fallback \
                git "${git_ssl_opts[@]}" clone \
                --branch "$APPLICATION_NAME" \
                --depth 2 \
                "$SOURCE_VARIABLE_REPO" \
                "$LOCAL_REPO_DIR" 2>&1)

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
            rm -f "$GIT_ASKPASS"
            return 1
        fi

    else

        echo "Repository already exists. Fetching latest changes..."

        cd "$LOCAL_REPO_DIR" || {
            echo "Error: Cannot change directory to $LOCAL_REPO_DIR"
            rm -f "$GIT_ASKPASS"
            return 1
        }

        git "${git_ssl_opts[@]}" fetch origin "$APPLICATION_NAME" --depth 2 || {
            echo "Error: Fetching latest changes failed."
            rm -f "$GIT_ASKPASS"
            return 1
        }

        git "${git_ssl_opts[@]}" pull origin "$APPLICATION_NAME" || {
            echo "Error: Pulling latest changes failed for branch $APPLICATION_NAME."
            rm -f "$GIT_ASKPASS"
            return 1
        }
    fi

    # --------------------------------------------------
    # Path to mavenrepos.json
    # --------------------------------------------------
    local json_file="$LOCAL_REPO_DIR/mavenrepos.json"

    if [ ! -f "$json_file" ]; then
        echo "Error: $json_file not found for branch $APPLICATION_NAME"
        rm -f "$GIT_ASKPASS"
        return 1
    fi

    # --------------------------------------------------
    # Find service details
    # --------------------------------------------------
    echo "Extracting service details for $CODEBASE_DIR..."

    if [ -z "$CODEBASE_DIR" ]; then
        CODEBASE_DIR=$(echo "$DEPLOY_SERVICE_NAME" | sed -E 's/-(dev|prod|qa|staging|uat)-.*$//')
        echo "CODEBASE_DIR was empty, using deployment service name: $CODEBASE_DIR"
    fi

    local service_data

    service_data=$(jq -r \
        --arg CODEBASE_DIR "$CODEBASE_DIR" \
        '.repositories[] | select(.bitbucketRepoName == $CODEBASE_DIR)' \
        "$json_file")

    if [ -z "$service_data" ]; then
        echo "Error: Service $CODEBASE_DIR not found in $json_file"
        rm -f "$GIT_ASKPASS"
        return 1
    fi

    # --------------------------------------------------
    # Extract Maven details
    # --------------------------------------------------
    export JAVA_VERSION=$(echo "$service_data" | jq -r '.JAVA_VERSION')
    export MAVEN_VERSION=$(echo "$service_data" | jq -r '.MAVEN_VERSION')

    export MAVEN_BUILD_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_BUILD_INSTRUCTION')
    export MAVEN_DEPLOY_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_DEPLOY_INSTRUCTION')
    export MAVEN_TEST_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_TEST_INSTRUCTION')
    export MAVEN_CUSTOM_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_CUSTOM_INSTRUCTION')

    export TEST_FAILURE_THRESHOLD=$(echo "$service_data" | jq -r '.TEST_FAILURE_THRESHOLD')
    export TEST_RESULT_DIR=$(echo "$service_data" | jq -r '.TEST_RESULT_DIR')

    export MAVEN_OPTIONS=$(echo "$service_data" | jq -r '.MAVEN_OPTIONS // empty')

    export TEST_JAVA_VERSION=$(echo "$service_data" | jq -r '.TEST_JAVA_VERSION')
    export TEST_MAVEN_VERSION=$(echo "$service_data" | jq -r '.TEST_MAVEN_VERSION')

    export MAVEN_SONAR_SCAN_INSTRUCTION=$(echo "$service_data" | jq -r '.MAVEN_SONAR_SCAN_INSTRUCTION')
    export SONAR_URL=$(echo "$service_data" | jq -r '.SONAR_URL')
    export ENCRYPTED_SONAR_TOKEN=$(echo "$service_data" | jq -r '.ENCRYPTED_SONAR_TOKEN')

    # --------------------------------------------------
    # Set INSTRUCTION
    # --------------------------------------------------
    if [[ "$INSTRUCTION_TYPE" == "TEST" ]]; then
        export INSTRUCTION="$MAVEN_TEST_INSTRUCTION"
        export JAVA_VERSION="$TEST_JAVA_VERSION"
        export MAVEN_VERSION="$TEST_MAVEN_VERSION"

    elif [[ "$INSTRUCTION_TYPE" == "DEPLOY" ]]; then
        export INSTRUCTION="$MAVEN_DEPLOY_INSTRUCTION"

    elif [[ "$INSTRUCTION_TYPE" == "CUSTOM" ]]; then
        export INSTRUCTION="$MAVEN_CUSTOM_INSTRUCTION"

    else
        export INSTRUCTION="$MAVEN_BUILD_INSTRUCTION"
    fi

    if [[ -z "$INSTRUCTION" || "$INSTRUCTION" == "null" ]]; then
        echo "ERROR: INSTRUCTION could not be determined from mavenrepos.json"
        rm -f "$GIT_ASKPASS"
        return 1
    fi

    echo "Maven instruction: $INSTRUCTION"

    # --------------------------------------------------
    # Decrypt Sonar token
    # --------------------------------------------------
    SONAR_TOKEN=$(getDecryptedCredential \
        "$FERNET_KEY" \
        "$ENCRYPTED_SONAR_TOKEN")

    export SONAR_TOKEN

    # --------------------------------------------------
    # Remove cloned repository
    # --------------------------------------------------
    echo "Removing the cloned repository..."

    rm -rf "$LOCAL_REPO_DIR" || {
        echo "Error: Failed to remove directory $LOCAL_REPO_DIR."
        rm -f "$GIT_ASKPASS"
        return 1
    }

    rm -f "$GIT_ASKPASS"

    echo "Environment variables have been set and repository has been removed."

    bash /usr/local/bin/switch_versions.sh
}