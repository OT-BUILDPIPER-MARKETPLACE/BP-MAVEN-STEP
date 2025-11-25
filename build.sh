#!/bin/bash
set -euo pipefail

# ================================================================
# Load BP Functions
# ================================================================
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

# ================================================================
# Setup
# ================================================================
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

logInfoMessage "=============================================================="
logInfoMessage " Starting Maven Executor (Runtime Download Mode)"
logInfoMessage " Codebase : ${CODEBASE_LOCATION}"
logInfoMessage " Instruction : ${INSTRUCTION}"
logInfoMessage " JAVA_VERSION : ${JAVA_VERSION}"
logInfoMessage " MAVEN_VERSION : ${MAVEN_VERSION}"
logInfoMessage "=============================================================="

mkdir -p "${CODEBASE_LOCATION}"
cd "${CODEBASE_LOCATION}"

# ================================================================
# Runtime JDK Installer
# ================================================================
download_jdk() {
  local version="$1"
  local url=""

  case "$version" in
    "8")
      url="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u412-b08/OpenJDK8U-jdk_x64_linux_hotspot_8u412b08.tar.gz"
      ;;
    "11")
      url="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.25+9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.25_9.tar.gz"
      ;;
    "17")
      url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13+11/OpenJDK17U-jdk_x64_linux_hotspot_17.0.13_11.tar.gz"
      ;;
    "21")
      url="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5+11/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz"
      ;;
    *)
      logErrorMessage "Unsupported JAVA_VERSION: $version"
      saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
      exit 1
      ;;
  esac

  logInfoMessage "Downloading JDK $version ..."
  rm -rf /opt/jdk/*
  curl -sSL "$url" | tar -xz -C /opt/jdk

  # FIXED: Pick only the real JDK directory
  JDK_PATH="$(find /opt/jdk -maxdepth 1 -type d -name 'jdk-*' | head -n 1)"
}

# ================================================================
# Runtime Maven Installer
# ================================================================
download_maven() {
  local version="$1"
  local url=""

  case "$version" in
    "3.5.4")
      url="https://archive.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz"
      ;;
    "3.6.3")
      url="https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz"
      ;;
    "3.8.1")
      url="https://archive.apache.org/dist/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.tar.gz"
      ;;
    *)
      logErrorMessage "Unsupported MAVEN_VERSION: $version"
      saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
      exit 1
      ;;
  esac

  logInfoMessage "Downloading Maven $version ..."
  rm -rf /opt/maven/*
  curl -sSL "$url" | tar -xz -C /opt/maven

  # FIXED: Pick the correct Maven directory
  MVN_PATH="$(find /opt/maven -maxdepth 1 -type d -name 'apache-maven-*' | head -n 1)"
}

# ================================================================
# Download & configure JDK + Maven
# ================================================================
download_jdk "${JAVA_VERSION}"
download_maven "${MAVEN_VERSION}"

export JAVA_HOME="${JDK_PATH}"
export MAVEN_HOME="${MVN_PATH}"
export PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"

logInfoMessage "JAVA_HOME = ${JAVA_HOME}"
logInfoMessage "MAVEN_HOME = ${MAVEN_HOME}"

# ================================================================
# Import certificate if exists
# ================================================================
CERT_PATH="./nexus.cer"

if [[ -f "${CERT_PATH}" ]]; then
    logInfoMessage "Importing Nexus cert..."
    keytool -import -alias jetty \
        -keystore "${JAVA_HOME}/lib/security/cacerts" \
        -file "${CERT_PATH}" \
        -storepass changeit -noprompt || true
fi

# ================================================================
# Execute Maven Build
# ================================================================
logInfoMessage "Running mvn ${INSTRUCTION}"

"${MAVEN_HOME}/bin/mvn" ${INSTRUCTION}
TASK_STATUS=$?

logInfoMessage "Build finished with status ${TASK_STATUS}"

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
exit ${TASK_STATUS}

