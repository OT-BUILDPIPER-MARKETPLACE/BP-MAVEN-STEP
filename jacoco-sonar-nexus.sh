# Load logging helpers for consistent, colorized output
# Uses DEBUG env var (true/false) to control debug verbosity
__JACOCO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${__JACOCO_SCRIPT_DIR}/BP-BASE-SHELL-STEPS/log-functions.sh" ]]; then
  # shellcheck disable=SC1091
  . "${__JACOCO_SCRIPT_DIR}/BP-BASE-SHELL-STEPS/log-functions.sh"
fi

# Mask sensitive values in a line before logging
__mask_sensitive() {
  local line="$1"
  # Known-sensitive variables to scrub if present
  local -a vars=(
    "PASSWORD" "PASS" "TOKEN" "SECRET" "KEY" "AUTH" "CREDENTIAL" "CREDENTIALS"
    "AWS_SECRET_ACCESS_KEY" "AWS_ACCESS_KEY_ID" "GITHUB_TOKEN" "SONAR_TOKEN"
    "NEXUS_PASSWORD" "NEXUS_USERNAME"
  )
  local v
  for v in "${vars[@]}"; do
    if [[ -n "${!v+x}" && -n "${!v}" ]]; then
      line="${line//${!v}/***}"
    fi
  done
  # Mask URL basic-auth credentials: https://user:pass@host -> https://user:***@host
  line="$(echo "$line" | sed -E 's#(https?://[^:@/]+):[^@/]*@#\1:***@#g')"
  echo "$line"
}

# Enable xtrace with masking piped through logDebugMessage for DEBUG=true
__start_debug_trace() {
  if [[ "$(echo "${DEBUG:-}" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
    # Pretty PS4: show file:line for each traced command
    export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] '
    # Route xtrace to FD 4 and sanitize each line before logging
    # shellcheck disable=SC2069
    exec 4> >(while IFS= read -r __ln; do
      if declare -F logDebugMessage >/dev/null 2>&1; then
        logDebugMessage "$(__mask_sensitive "$__ln")"
      else
        # Fallback to plain echo if logger isn't available
        echo "$(__mask_sensitive "$__ln")"
      fi
    done)
    export BASH_XTRACEFD=4
    set -o xtrace
    # Let the user know debug is enabled (without leaking anything)
    if declare -F logInfoMessage >/dev/null 2>&1; then
      logInfoMessage "Debug trace enabled"
    fi
  fi
}

# Disable xtrace and close FD
__stop_debug_trace() {
  if [[ "$(echo "${DEBUG:-}" | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
    set +o xtrace 2>/dev/null || true
    # Close FD 4 if open
    { exec 4>&-; } 2>/dev/null || true
    if declare -F logInfoMessage >/dev/null 2>&1; then
      logInfoMessage "Debug trace disabled"
    fi
  fi
}


# Reusable helper to publish JaCoCo + Sonar and push/pull from Nexus
# Modes:
#   ut        -> use local UT exec, publish Sonar (-ut), upload UT exec to Nexus
#   it-merge  -> download IT + UT exec from Nexus, publish Sonar for IT (-it),
#                merge UT+IT and publish combined (no suffix)
#
# Required env vars (defaults shown or noted):
#   USERNAME, PASSWORD, NEXUS_URL, REPO_NAME, APPLICATION_NAME, CODEBASE_DIR
#   JACOCO_FILE_PATH (path to UT exec, e.g. rest/target/jacoco.exec)
#   SONAR_HOST_URL, SONAR_TOKEN
#   BASE_PROJECT_KEY (e.g. test-project)
# Optional:
#   IT_NEXUS_PATH (default: it/latest/jacoco-it.exec)
#   UT_NEXUS_PATH (default: ut/latest/jacoco-ut.exec)
#   JACOCO_CLI_VERSION (default: 0.8.11)
jacoco_sonar_nexus() {
: "${USERNAME:?missing USERNAME}"
: "${PASSWORD:?missing PASSWORD}"
: "${NEXUS_URL:?missing NEXUS_URL}"
: "${REPO_NAME:?missing REPO_NAME}"
: "${APPLICATION_NAME:?missing APPLICATION_NAME}"
: "${CODEBASE_DIR:?missing CODEBASE_DIR}"
: "${SONAR_HOST_URL:?missing SONAR_HOST_URL}"
: "${SONAR_TOKEN:?missing SONAR_TOKEN}"
: "${BASE_PROJECT_KEY:?missing BASE_PROJECT_KEY}"

# Start debug tracing (masked) and ensure cleanup on return
__start_debug_trace
trap '__stop_debug_trace' RETURN
MODE=${1:-}
if [[ -z "$MODE" ]]; then
  echo "Usage: $(basename "$0") <ut|it-merge>"
  exit 2
fi

DATE_TIME=${DATE_TIME:-$(date +"%Y-%m-%dT%H:%M:%S%:z")}
DOWNLOAD_DIR=${DOWNLOAD_DIR:-"jacoco_download"}
JACOCO_CLI_VERSION=${JACOCO_CLI_VERSION:-0.8.11}
JACOCO_MVN_VERSION=${JACOCO_MVN_VERSION:-0.8.11}
# Select tool: prefer Maven plugin by default when available
if [[ -z "${JACOCO_TOOL:-}" ]]; then
  if command -v mvn >/dev/null 2>&1; then
    JACOCO_TOOL=mvn
  else
    JACOCO_TOOL=cli
  fi
fi
if declare -F logInfoMessage >/dev/null 2>&1; then
  logInfoMessage "JaCoCo tool selected: ${JACOCO_TOOL}"
else
  echo "JaCoCo tool selected: ${JACOCO_TOOL}" >&2
fi
UT_NEXUS_PATH=${UT_NEXUS_PATH:-"ut/latest/jacoco-ut.exec"}
IT_NEXUS_PATH=${IT_NEXUS_PATH:-"it/latest/jacoco-it.exec"}

ensure_jacoco_cli() {
  local jar="$HOME/.m2/repository/org/jacoco/org.jacoco.cli/${JACOCO_CLI_VERSION}/org.jacoco.cli-${JACOCO_CLI_VERSION}-nodeps.jar"
  if [[ ! -f "$jar" ]]; then
    echo "Fetching JaCoCo CLI ${JACOCO_CLI_VERSION}…" >&2
    mvn -q -e -Dtransitive=false dependency:get -Dartifact=org.jacoco:org.jacoco.cli:${JACOCO_CLI_VERSION}:jar:nodeps >/dev/null || true
  fi
  echo "$jar"
}

discover_jacoco_exec() {
  # Prefer standard Maven UT exec locations
  local f
  f=$(find . -type f -path "*/target/jacoco.exec" -printf "%T@ %p\n" 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  if [[ -z "$f" ]]; then
    f=$(find . -type f -name "jacoco-ut.exec" -printf "%T@ %p\n" 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  fi
  # Last resort: any .exec that isn't a merged file
  if [[ -z "$f" ]]; then
    f=$(find . -type f -name "*.exec" ! -name "*merged*.exec" -printf "%T@ %p\n" 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  fi
  echo "$f"
}

# Try to locate a module with compiled classes when exec path is unknown
discover_classes_dir() {
  local d
  d=$(find . -type d -path "*/target/classes" -print -quit 2>/dev/null || true)
  echo "${d}"
}

sonar_with_xml() {
  # Args: xml_path project_key [project_name] [class_dir]
  local xml_path="$1"
  local project_key="$2"
  local project_name="${3:-$project_key}"
  local class_dir="${4:-}"

  if command -v mvn >/dev/null 2>&1; then
    mvn -q -e -DskipTests -DskipITs=true -DskipIT=true sonar:sonar \
      -Dsonar.projectKey="$project_key" \
      -Dsonar.projectName="$project_name" \
      -Dsonar.host.url="$SONAR_HOST_URL" \
      -Dsonar.login="$SONAR_TOKEN" \
      -Dsonar.coverage.jacoco.xmlReportPaths="$xml_path" \
      -Dsonar.java.binaries="${class_dir:-}" >/dev/null
  elif command -v sonar-scanner >/dev/null 2>&1; then
    sonar-scanner \
      -Dsonar.projectKey="$project_key" \
      -Dsonar.projectName="$project_name" \
      -Dsonar.host.url="$SONAR_HOST_URL" \
      -Dsonar.login="$SONAR_TOKEN" \
      -Dsonar.coverage.jacoco.xmlReportPaths="$xml_path" \
      -Dsonar.sources=. \
      -Dsonar.java.binaries="${class_dir:-}" >/dev/null
  else
    echo "Neither mvn nor sonar-scanner found in PATH"
    return 1
  fi
}

# Derive module directories from exec path like rest/target/jacoco.exec
module_from_exec() {
  local exec_path="$1"
  # Strip /target/…
  local module_dir
  module_dir=$(echo "$exec_path" | sed -E 's#(/)?target/.*$##')
  echo "$module_dir"
}

report_xml_from_exec() {
  local exec_path="$1"; shift
  local out_xml="$1"; shift
  local module_dir
  module_dir=$(module_from_exec "$exec_path")
  local classes_dir="$module_dir/target/classes"
  local sources_dir="$module_dir/src/main/java"
  if [[ "$JACOCO_TOOL" == "mvn" && -f "$module_dir/pom.xml" ]]; then
    if command -v mvn >/dev/null 2>&1; then
    # Build classes if needed
    if [[ ! -d "$classes_dir" ]]; then
      echo "Building classes for report generation (missing $classes_dir)…"
      mvn -q -e -f "$module_dir/pom.xml" -DskipTests package >/dev/null || true
    fi
    # Ask the jacoco-maven-plugin to generate the XML report; it will default to target/site/jacoco/jacoco.xml
    mvn -q -e -f "$module_dir/pom.xml" \
      -Djacoco.dataFile="$exec_path" \
      org.jacoco:jacoco-maven-plugin:${JACOCO_MVN_VERSION}:report >/dev/null || true
    local default_xml="$module_dir/target/site/jacoco/jacoco.xml"
    if [[ -f "$default_xml" ]]; then
      # If plugin produced exactly the requested path, don't copy over itself
      if [[ "$default_xml" != "$out_xml" ]]; then
        mkdir -p "$(dirname "$out_xml")"
        cp -f "$default_xml" "$out_xml"
      fi
      return 0
    fi
    echo "jacoco-maven-plugin did not produce report at $default_xml, falling back to CLI…"
    fi
  fi

  # Fallback to CLI
  local jacoco_cli
  jacoco_cli=$(ensure_jacoco_cli)
  if [[ ! -d "$classes_dir" && -f "$module_dir/pom.xml" ]]; then
    if command -v mvn >/dev/null 2>&1; then
      echo "Building classes for report generation (missing $classes_dir)…"
      mvn -q -e -f "$module_dir/pom.xml" -DskipTests package >/dev/null || true
    fi
  fi
  mkdir -p "$(dirname "$out_xml")"
  java -jar "$jacoco_cli" report "$exec_path" \
    --classfiles "$classes_dir" \
    --sourcefiles "$sources_dir" \
    --xml "$out_xml"
}

merge_execs() {
  local out_exec="$1"; shift
  # Try Maven plugin first if requested
  if [[ "$JACOCO_TOOL" == "mvn" && -f pom.xml ]]; then
    if command -v mvn >/dev/null 2>&1; then
    local data_files_csv
    data_files_csv=$(IFS=, ; echo "$*")
    mvn -q -e \
      -Djacoco.destFile="$out_exec" \
      -Djacoco.dataFiles="$data_files_csv" \
      org.jacoco:jacoco-maven-plugin:${JACOCO_MVN_VERSION}:merge >/dev/null || true
    fi
  fi
  if [[ ! -s "$out_exec" ]]; then
    # Fallback to CLI merge
    local jacoco_cli
    jacoco_cli=$(ensure_jacoco_cli)
    java -jar "$jacoco_cli" merge "$@" --destfile "$out_exec"
  fi
}

nexus_upload() {
  local src_file="$1"; shift
  local path_suffix="$1"; shift
  curl -sf -u "${USERNAME}:${PASSWORD}" --upload-file "$src_file" \
    "${NEXUS_URL}/repository/${REPO_NAME}/${APPLICATION_NAME}/${CODEBASE_DIR}/${path_suffix}"
}

nexus_download() {
  local path_suffix="$1"; shift
  local out_file="$2"; shift
  curl -sf -u "${USERNAME}:${PASSWORD}" -o "$out_file" \
    "${NEXUS_URL}/repository/${REPO_NAME}/${APPLICATION_NAME}/${CODEBASE_DIR}/${path_suffix}"
}

run_ut() {
  if [[ -z "${JACOCO_FILE_PATH:-}" ]]; then
    JACOCO_FILE_PATH=$(discover_jacoco_exec || true)
    if [[ -n "$JACOCO_FILE_PATH" ]]; then
      echo "Auto-detected JACOCO_FILE_PATH at $JACOCO_FILE_PATH"
    fi
  fi
  if [[ -z "${JACOCO_FILE_PATH:-}" || ! -f "$JACOCO_FILE_PATH" ]]; then
    echo "JaCoCo exec not found; attempting to run tests to generate coverage…"
    # Prefer pipeline-provided test instruction; fallback to 'test'
    if [[ -n "${INSTRUCTION:-}" ]]; then
      echo "Executing mvn ${INSTRUCTION} ${MAVEN_OPTIONS:-}"
      mvn ${INSTRUCTION} ${MAVEN_OPTIONS:-} || true
    else
      echo "Executing mvn test with JaCoCo enabled"
      mvn -q -e -DskipITs=true -DskipIT=true -Djacoco.skip=false test || true
    fi
    # Try discovery again after tests
    JACOCO_FILE_PATH=$(discover_jacoco_exec || true)
  fi
  : "${JACOCO_FILE_PATH:?missing JACOCO_FILE_PATH}"
  if [[ ! -f "$JACOCO_FILE_PATH" ]]; then
    echo "❌ JaCoCo exec not found at $JACOCO_FILE_PATH"
    exit 1
  fi

  echo "Generating UT jacoco.xml…"
  local module_dir
  module_dir=$(module_from_exec "$JACOCO_FILE_PATH")
  local ut_xml="$module_dir/target/site/jacoco/jacoco.xml"
  report_xml_from_exec "$JACOCO_FILE_PATH" "$ut_xml"

  echo "Publishing UT Sonar: ${BASE_PROJECT_KEY}-ut"
  sonar_with_xml "$ut_xml" "${BASE_PROJECT_KEY}-ut" "${BASE_PROJECT_KEY}-ut" "$module_dir/target/classes"

  echo "Uploading UT exec to Nexus…"
  nexus_upload "$JACOCO_FILE_PATH" "ut/${DATE_TIME}/jacoco-ut.exec"
  nexus_upload "$JACOCO_FILE_PATH" "ut/latest/jacoco-ut.exec"
  echo "✅ UT upload + Sonar complete"
}

run_it_and_merge() {
  mkdir -p "$DOWNLOAD_DIR"
  local module_dir
  # Derive module from configured UT path for classes/sources
  if [[ -n "${JACOCO_FILE_PATH:-}" && -f "${JACOCO_FILE_PATH}" ]]; then
    module_dir=$(module_from_exec "${JACOCO_FILE_PATH}")
  else
    # Fallback to a discovered classes directory
    local classes_guess
    classes_guess=$(discover_classes_dir || true)
    if [[ -n "$classes_guess" ]]; then
      module_dir="${classes_guess%/target/classes}"
    else
      module_dir="."
    fi
  fi
  local classes_dir="$module_dir/target/classes"

  echo "Downloading IT exec from Nexus…"
  local it_exec="$DOWNLOAD_DIR/jacoco-it.exec"
  nexus_download "$IT_NEXUS_PATH" "$it_exec"
  test -s "$it_exec" || { echo "IT exec empty"; exit 1; }

  echo "Generating IT jacoco.xml…"
  local it_xml="$module_dir/target/site/jacoco-it/jacoco.xml"
  report_xml_from_exec "$it_exec" "$it_xml"

  echo "Publishing IT Sonar: ${BASE_PROJECT_KEY}-it"
  sonar_with_xml "$it_xml" "${BASE_PROJECT_KEY}-it" "${BASE_PROJECT_KEY}-it" "$classes_dir"

  echo "Downloading UT exec from Nexus…"
  local ut_exec="$DOWNLOAD_DIR/jacoco-ut.exec"
  nexus_download "$UT_NEXUS_PATH" "$ut_exec"
  test -s "$ut_exec" || { echo "UT exec empty"; exit 1; }

  echo "Merging UT+IT execs…"
  local merged_exec="$DOWNLOAD_DIR/jacoco-merged.exec"
  merge_execs "$merged_exec" "$ut_exec" "$it_exec"

  echo "Generating merged jacoco.xml…"
  local merged_xml="$module_dir/target/site/jacoco-merged/jacoco.xml"
  report_xml_from_exec "$merged_exec" "$merged_xml"

  echo "Publishing Combined Sonar: ${BASE_PROJECT_KEY}"
  sonar_with_xml "$merged_xml" "${BASE_PROJECT_KEY}" "${BASE_PROJECT_KEY}" "$classes_dir"
  echo "✅ IT and merge + Sonar complete"
}

case "$MODE" in
  ut)
    run_ut
    ;;
  it-merge)
    run_it_and_merge
    ;;
  *)
    echo "Unknown mode: $MODE (use ut | it-merge)"
    exit 2
    ;;
 esac

}
