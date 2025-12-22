# **Change Log for Docker Image: `registry.buildpiper.in/maven-execute`**  

**Tag:** `2.5.2.2`  
**Release Date:** *2025-02-20*  
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*  

## **Enhancements:**

- Enhanced Maven execution logic by introducing INSTRUCTION_TYPE handling.
  - Supports BUILD, DEPLOY, TEST, and CUSTOM instructions.
  - Logs execution details for each instruction type.
  - Added error handling for unsupported instruction types, defaulting to BUILD with an error message.
- Introduced conditional handling for Maven silent mode.
- Added a new environment variable `ENABLE_MAVEN_SILENT_MODE`.
- When `ENABLE_MAVEN_SILENT_MODE` is set to `true`, the script appends `-B -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn` to the `mvn` command.
- Improved logging to display executed Maven commands with or without the silent mode options.
Included error handling for unsupported Java and Maven versions.
- Implemented `fetch_service_details` function call based on `SOURCE_VARIABLE_REPO` and `INSTRUCTION` conditions.

**References:**
[How to remove downloading messages from Maven log output](https://blogs.itemis.com/en/in-a-nutshell-removing-artifact-messages-from-maven-log-output)
[Base Image Tag 2.0.3](https://hub.docker.com/layers/mukulmj/custom-ubuntu-java-maven/2.0.3/images/sha256-0d3cb75d96d9c9aefd009af8a5ed802ee686ca739d6dcd03015b25c84fdcca6b)
[Maven has now a an option to suppress the transfer progress when downloading/uploading in interactive mode.](https://maven.apache.org/docs/3.6.1/release-notes.html#:~:text=with%20MNG%2D6618-,User%20visible%20Changes,scm%20part%20in%20the%20pom%20for%20multi%20module%20builds%20like%20this%3A,-%3Cproject%20child.project)

---

Here’s the updated change log for version `2.5.2.3` incorporating your additions:  

---

**Tag:** `2.5.2.3`  
**Release Date:** *2025-03-01*  
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*  

## **Enhancements & New Additions:**  

### **1. Added Node.js & Package Manager Support**

- Integrated NVM (v0.40.1) to manage Node.js installations.
- Installed Node.js v14 and set it as the default version.  
- Installed globally compatible versions of `npm` (v6) and `pnpm` (v7).  
- Verified successful installation by logging Node.js, npm, and pnpm versions.  
- **Reference:** [Node.js Download](https://nodejs.org/en/download)  

### **2. Introduced `set_npmrc.sh` Script for npm Configuration**  

- **New script:** `set_npmrc.sh` to manage `.npmrc` configurations dynamically.  
- Checks for an existing `.npmrc` in the target `CODEBASE_LOCATION`.  
- If found, sets it as the default and backs up any existing global `.npmrc`.  
- Ensures seamless npm registry configuration management.  

### **3. Other Improvements**  

- Retained all enhancements from version `2.5.2.2`, including:  
  - Enhanced Maven execution with `INSTRUCTION_TYPE` handling.  
  - Conditional handling of Maven silent mode using `ENABLE_MAVEN_SILENT_MODE`.  
  - Improved error handling for unsupported Java and Maven versions.  
  - `fetch_service_details` function now executes based on `SOURCE_VARIABLE_REPO` and `INSTRUCTION` conditions.  

---

**Tag:** `2.5.2.4`
**Release Date:** *2025-06-30*
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

## **Enhancements & New Additions:**

### **1. Base Image Update**

* **Updated base image:**

  * `FROM registry.buildpiper.in/base-image/java-maven:2.0.5`
* Modernized Java and Maven environment compatibility.

### **2. New Entrypoint Script for Version Switching**

* **Added `switch_versions.sh` as the main `ENTRYPOINT`:**

  * Initializes Java and Maven version setup automatically during container start.
  * When `fetch_service_details` is used, `switch_versions.sh` executes again to ensure environment consistency.
* **Entrypoint Configuration:**

  ```dockerfile
  ENTRYPOINT ["/usr/local/bin/switch_versions.sh", "./build.sh"]
  ```
### **3. Improved Repository Cloning & Proxy Handling**

* **Enhanced `getDynamicVars.sh`:**

  * Implements multiple retry attempts when cloning repositories.
  * Introduced dynamic proxy support:

    * Uses proxy if cloning fails initially.
    * Automatically removes proxy for specific commands that must bypass it.

### **4. Dynamic Maven Instruction Selection**

* Added logic to **switch Maven `INSTRUCTION` dynamically** based on `INSTRUCTION_TYPE` if `INSTRUCTION` is not explicitly set:

  ```bash
  if [ -z "$INSTRUCTION" ]; then
      case "$INSTRUCTION_TYPE" in
          "BUILD")  export INSTRUCTION=$MAVEN_BUILD_INSTRUCTION ;;
          "DEPLOY") export INSTRUCTION=$MAVEN_DEPLOY_INSTRUCTION ;;
          "TEST")   export INSTRUCTION=$MAVEN_TEST_INSTRUCTION ;;
          "CUSTOM") export INSTRUCTION=$MAVEN_CUSTOM_INSTRUCTION ;;
          *)
              logErrorMessage "Unsupported $INSTRUCTION_TYPE: Executing default mvn $INSTRUCTION"
              ;;
      esac
  fi
  ```
* Ensures consistent build/deploy/test workflows across pipelines.

### **5. Test Result Management Enhancements**

* **New Environment Variables:**

  * `ENABLE_CUSTOM_HTML_SCAN`
    Enables parsing of custom HTML reports to extract failed test cases.
  * `TEST_FAILURE_THRESHOLD`
    Configurable test failure threshold percentage (e.g., `50` for 50%).
  * `TEST_RESULT_DIR`
    Path to the directory containing test result files.

### **6. Retained Enhancements from `2.5.2.3`**

* Node.js & Package Manager support with `nvm`, `npm`, and `pnpm`.
* `set_npmrc.sh` script for dynamic `.npmrc` management.
* Enhanced Maven execution, error handling, and dynamic instruction selection logic.

---

**Tag:** `2.5.2.5`
**Release Date:** *2025-08-05*
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

## **Enhancements & New Additions:**

### **1. Test Report Variable Enhancements**

* **New dynamic environment variable fetching for test management:**

  ```bash
  export TEST_FAILURE_THRESHOLD=$(echo "$service_data" | jq -r '.TEST_FAILURE_THRESHOLD')
  export TEST_RESULT_DIR=$(echo "$service_data" | jq -r '.TEST_RESULT_DIR')
  export MAVEN_OPTIONS=$(echo "$service_data" | jq -r '.MAVEN_OPTIONS')
  ```
* **Improvements:**

  * Fetches threshold, test result directory, and Maven options dynamically from `mavenrepos.json`.
  * Supports per-service configuration for pipelines.
  * Simplifies test management in multi-service/multi-module builds.


### **2. Maven Repository-Driven Variable Resolution**

* Extended `getDynamicVars.sh` and `fetch_service_details` to **fetch additional variables from Maven repository metadata**:

  **Supported keys:**

  * `TEST_FAILURE_THRESHOLD` → Controls max allowable test failures before marking pipeline as failed.
  * `TEST_RESULT_DIR` → Points to directory containing test reports for parsing.
  * `MAVEN_OPTIONS` → Allows passing additional Maven CLI flags dynamically.

* **Behavior:**

  * Defaults applied if variables are not set in the Maven repository.
  * Integrated with **`switch_versions.sh`** to ensure environment consistency across builds and test report parsing.

---

### **3. Improved Test Report Management**

* Test results can now be **evaluated dynamically** based on service-specific configurations.
* Enhanced compatibility with **custom HTML reports** and **JUnit XML parsing**.
* Can terminate the pipeline early if failure threshold is exceeded.

---

### **4. Retained Enhancements from `2.5.2.4`**

* Node.js, npm, pnpm multi-version support.
* Proxy-aware repository cloning with retry logic.
* Dynamic Maven `INSTRUCTION` handling.
* Entrypoint script `switch_versions.sh` for automatic Java/Maven version switching.

---

**Tag:** `2.5.2.6`
**Release Date:** *2025-09-02*
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

### 🔄 Changes

* Enhanced **Java & Maven version handling** logic:

  * Default `JAVA_VERSION` and `MAVEN_VERSION` are now taken from the standard service configuration.
  * If `INSTRUCTION_TYPE` is set to **`TEST`**, the system now dynamically overrides these values with `TEST_JAVA_VERSION` and `TEST_MAVEN_VERSION`.

### ✅ Impact

* Provides more flexibility in running test-specific builds.
* Ensures proper environment alignment between build and test phases.

### 📌 Notes

* No breaking changes introduced.
* Backward compatibility maintained for non-test instruction types.

---

**Tag:** `2.5.2.7`
**Release Date:** *2025-10-01*
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

### 🔄 Changes

* **[NEW]** Added Java version support for **22**, **23**, and **24**.

### ✅ Impact

* Expands supported Java ecosystem to the latest releases.
* Enables builds and tests to leverage the most recent Java versions.

### 📌 Notes

* Fully backward compatible.
* No changes required in existing configurations.

---

**Tag:** `2.5.2.8`
**Release Date:** *2025-10-08*
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

### 🔄 Changes

* **\[NEW]** Added dynamic handling for `SONAR_TESTING_TYPE` to auto-append suffixes (`-it` or `-ut`) to Sonar project keys and names.
* **\[NEW]** Implemented `INSTRUCTION_TYPE=SONAR_SCAN` handling to execute Sonar-specific Maven commands.
* **\[ENHANCED]** Added `MAVEN_SONAR_SCAN_INSTRUCTION` resolution inside instruction switch block.
* **\[IMPROVED]** Ensured sensitive data (`SONAR_TOKEN`) is masked in logs for better security.

### ✅ Impact

* Enables SonarQube scans for both **unit** and **integration** testing pipelines automatically.
* Prevents accidental exposure of secrets in logs.
* Expands automation coverage for Maven Sonar scan workflows.

### 📌 Notes

* Backward compatible with all previous tags.
* No configuration changes required.
* Works seamlessly with both legacy and new pipeline configurations.

---

**Tag:** `2.5.2.8-nr`
**Release Date:** *2025-10-30*
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

### 🔄 Changes

* **[NEW]** Added failure threshold control for test reports
  * Supports both XML (surefire) and HTML custom test reports
  * Configurable `TEST_FAILURE_THRESHOLD` (default: 50%)
  * Handles both Maven surefire XML reports and custom HTML reports

* **[ENHANCED]** Test report parsing improvements:
  * XML parsing for surefire reports using standard Maven output
  * HTML parsing using `xmllint` for custom test result formats
  * Supports dynamic report paths via `TEST_RESULT_DIR`

* **[IMPROVED]** Build failure conditions:
  * Fails build if test failure rate exceeds threshold
  * Copies test reports to execution directory for archival
  * Provides detailed failure statistics in build logs

### ✅ Impact

* Better control over test quality gates in CI/CD pipelines
* More flexible test report handling for different testing frameworks
* Improved visibility into test failures and their impact on builds

### 📌 Notes

* Backward compatible with previous versions
* Requires `libxml2-utils` for HTML report parsing
* Set `ENABLE_CUSTOM_HTML_SCAN=true` to enable HTML report parsing

---

**Tag:** `2.5.2.8-nr-ut-it`
**Release Date:** *2025-12-23*
**Maintainer:** *[Mukul Joshi](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*
## **Enhancements & Fixes**

### **1. JaCoCo + Sonar + Nexus helper hardening**
- Added comprehensive, masked debug tracing to `jacoco-sonar-nexus.sh` using `log-functions.sh`.
  - Pretty `PS4` shows `file:line`; sensitive values (tokens/passwords and URL basic‑auth) are masked in traces.
- Nexus operations improved with clear, credential‑free URL logging.
  - `nexus_upload` prints the final artifact URL on success.
  - `nexus_download` logs source URL, uses retries/timeouts, and reports the downloaded file size.
- Introduced robust file placement with an atomic download workflow:
  - Download to a temporary file, then `robust_move_file` (`mv → cp+rm → cat` fallback) to the final destination.
  - Detailed diagnostics when destination directories are not writable.
- New directory utility `ensure_writable_dir` with automatic fallback to `/tmp` when `DOWNLOAD_DIR` is unusable.
- Fixed argument parsing in `nexus_download` to prevent empty destination paths and added guards in `robust_move_file`.

### **2. Configurability for downloads**
- New flags:
  - `DOWNLOAD_ATOMIC` (default: `true`) to enable temp‑file + atomic move.
  - `DOWNLOAD_FORCE_LOCAL` (default: `false`) to force using the current workspace path even if not fully writable.
- `DOWNLOAD_DIR` defaults to `jacoco_download` with automatic fallback to `/tmp/jacoco_download` when needed.

### **3. JaCoCo CLI retrieval resilience**
- `ensure_jacoco_cli` now prefers a pre‑bundled jar, then local Maven repo, then a mirror or Maven Central.
  - Supports corporate mirrors via `JACOCO_MAVEN_REPO_URL` and Nexus via `NEXUS_URL`/`REPO_NAME`.
  - Environment variables used: `JACOCO_CLI_VERSION`, `JACOCO_MVN_VERSION`, and optional `JACOCO_CLI_JAR`.
### **4. Docker image updates for cross‑version compatibility**

- Base image now prefetches the JaCoCo CLI `nodeps` jar into `/opt/jacoco`.
  - Adds `ENV` wiring for:
  - `JACOCO_CLI_VERSION` (default `0.8.11`)
  - `JACOCO_CLI_JAR` (e.g., `/opt/jacoco/org.jacoco.cli-0.8.11-nodeps.jar`)
  - `JACOCO_MVN_VERSION` (default `0.8.11`) for the Maven plugin.

### **5. Accurate report generation for IT and merged coverage**
- `report_xml_from_exec()` now accepts a module directory override so the CLI points to the correct `<module>/target/classes` even when `.exec` files live in a separate download folder.
- If classes are missing, the helper performs a lightweight build (`mvn -DskipTests package`) at the module or root.
- Multi‑module support: when a single `target/classes` isn’t found, the CLI receives all module class/source directories discovered under the workspace.
- `run_it_and_merge()` passes the correct module directory for IT and merged reports, eliminating `FileNotFoundException: ./target/classes` errors.

### **6. Additional variables & defaults**
- Supported/added variables:
  - `UT_NEXUS_PATH` (default `ut/latest/jacoco-ut.exec`)
  - `IT_NEXUS_PATH` (default `it/latest/jacoco-it.exec`)
  - `DOWNLOAD_DIR`, `DOWNLOAD_ATOMIC`, `DOWNLOAD_FORCE_LOCAL`
  - `JACOCO_CLI_VERSION`, `JACOCO_MVN_VERSION`, `JACOCO_CLI_JAR`, `JACOCO_MAVEN_REPO_URL`

### **7. Compatibility & Notes**
- Backward compatible; no breaking changes.
- Secrets remain masked in logs; Nexus/Sonar URLs are logged without credentials.
- Works across a wide range of Java/Maven versions due to the `nodeps` JaCoCo CLI jar.

---

## **Usage Guide (UT and IT+Merge)**

### **Required Environment Variables**

- `USERNAME`, `PASSWORD`: Nexus credentials
- `NEXUS_URL`, `REPO_NAME`: Nexus base URL and repository name
- `APPLICATION_NAME`, `CODEBASE_DIR`: Service and codebase identifiers used in Nexus pathing
- `SONAR_HOST_URL`, `SONAR_TOKEN`: SonarQube endpoint and token
- `BASE_PROJECT_KEY`: Base key used for Sonar projects (`-ut`, `-it`, and combined)

### **Optional Environment Variables**

- `JACOCO_FILE_PATH`: UT `.exec` path (auto-detected if omitted)
- `UT_NEXUS_PATH` / `IT_NEXUS_PATH`: Nexus paths for UT/IT execs (defaults: `ut/latest/jacoco-ut.exec`, `it/latest/jacoco-it.exec`)
- `DOWNLOAD_DIR`: Directory for downloads (default: `jacoco_download`, with fallback to `/tmp/jacoco_download`)
- `DOWNLOAD_ATOMIC`: `true|false` (default `true`) — temp download + atomic move vs direct write
- `DOWNLOAD_FORCE_LOCAL`: `true|false` (default `false`) — force using CWD paths even if potentially not writable
- `JACOCO_CLI_VERSION`, `JACOCO_MVN_VERSION`, `JACOCO_CLI_JAR`, `JACOCO_MAVEN_REPO_URL`: control JaCoCo CLI/plugin versions and mirror

### **UT Workflow**

1. Generate UT coverage and publish Sonar; upload the UT exec to Nexus (`latest` and timestamped):

```bash
export USERNAME=your_user
export PASSWORD=your_pass
export NEXUS_URL=https://nexus.example.com
export REPO_NAME=integration-testing
export APPLICATION_NAME=your-service
export CODEBASE_DIR=your-module-or-path
export SONAR_HOST_URL=https://sonar.example.com
export SONAR_TOKEN=your_sonar_token
export BASE_PROJECT_KEY=myproject

# Optional
export JACOCO_FILE_PATH=rest/target/jacoco.exec
export DOWNLOAD_ATOMIC=true
export DOWNLOAD_FORCE_LOCAL=false

bash BP-MAVEN-STEP/jacoco-sonar-nexus.sh ut
```

Results:
- Creates `target/site/jacoco/jacoco.xml` under the UT module.
- Publishes Sonar for `myproject-ut`.
- Uploads UT exec to Nexus at `ut/latest/jacoco-ut.exec` and `ut/<timestamp>/jacoco-ut.exec`.

### **IT + Merge Workflow**

Preconditions:
- UT step above has uploaded `ut/latest/jacoco-ut.exec`.
- IT exec is available in Nexus (default `it/latest/jacoco-it.exec`).

Run IT analysis, publish Sonar for `-it`, merge UT+IT, publish combined:

```bash
export USERNAME=your_user
export PASSWORD=your_pass
export NEXUS_URL=https://nexus.example.com
export REPO_NAME=integration-testing
export APPLICATION_NAME=your-service
export CODEBASE_DIR=your-module-or-path
export SONAR_HOST_URL=https://sonar.example.com
export SONAR_TOKEN=your_sonar_token
export BASE_PROJECT_KEY=myproject

# Optional / confirm paths
export IT_NEXUS_PATH=it/latest/jacoco-it.exec
export UT_NEXUS_PATH=ut/latest/jacoco-ut.exec
export DOWNLOAD_DIR=jacoco_download

bash BP-MAVEN-STEP/jacoco-sonar-nexus.sh it-merge
```

Results:
- Generates `target/site/jacoco-it/jacoco.xml` and publishes `myproject-it`.
- Merges UT+IT into `DOWNLOAD_DIR/jacoco-merged.exec`.
- Generates `target/site/jacoco-merged/jacoco.xml` and publishes combined `myproject`.

### **Troubleshooting Tips**

- Set `DEBUG=true` to see masked command traces and URLs.
- If classes are missing, the script builds them (`mvn -DskipTests package`). Ensure `pom.xml` exists at module or root.
- For restricted environments, set `JACOCO_MAVEN_REPO_URL` to a reachable mirror/Nexus to fetch the JaCoCo CLI jar.
- If `DOWNLOAD_DIR` is not writable, the helper falls back to `/tmp`; override behavior with `DOWNLOAD_FORCE_LOCAL=true`.