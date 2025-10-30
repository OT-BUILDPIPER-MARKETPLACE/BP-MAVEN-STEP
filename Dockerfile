FROM registry.buildpiper.in/base-image/java-maven:2.0.8-nr

# Install packages as root (do NOT switch to non-root yet)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2-utils \
    findutils \
    grep \
    sed \
    gawk \
    coreutils \
    bash \
 && rm -rf /var/lib/apt/lists/*

# Inherit buildpiper user and permissions (switch after installs)
USER buildpiper

# Set up NVM environment variable
ENV HOME="/home/buildpiper"
ENV NVM_DIR="$HOME/.nvm"
ENV INSTRUCTION_TYPE="BUILD"

# Install NVM, Node.js v14.21.3, and a compatible version of pnpm
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    bash -lc "source \"$NVM_DIR/nvm.sh\" && nvm install v14.21.3 && nvm use v14.21.3 && npm install -g pnpm@7" && \
    bash -lc "echo 'export NVM_DIR=\"$NVM_DIR\"' >> \"$HOME/.bashrc\" && \
              echo '[ -s \"$NVM_DIR/nvm.sh\" ] && \\. \"$NVM_DIR/nvm.sh\"' >> \"$HOME/.bashrc\" && \
              echo '[ -s \"$NVM_DIR/bash_completion\" ] && \\. \"$NVM_DIR/bash_completion\"' >> \"$HOME/.bashrc\""

# Verify installation of Node.js and compatible pnpm version
RUN bash -c "source $NVM_DIR/nvm.sh && node -v && nvm current && pnpm -v"

# Old Details
ENV SLEEP_DURATION 5s

COPY --chown=buildpiper:buildpiper build.sh .
COPY --chown=buildpiper:buildpiper getDynamicVars.sh .
COPY --chown=buildpiper:buildpiper set_npmrc.sh .
ADD --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
RUN chmod +x build.sh set_npmrc.sh getDynamicVars.sh

ENV ENABLE_MAVEN_SILENT_MODE false
ENV SOURCE_JSON_FILE mavenrepos.json
ENV VALIDATION_FAILURE_ACTION WARNING 
ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE
ENTRYPOINT [ "/usr/local/bin/switch_versions.sh", "./build.sh" ]

CMD ["bash"]
