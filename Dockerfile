FROM registry.buildpiper.in/base-image/java-maven:2.0.5

RUN apt-get update && apt-get install -y \
    libxml2-utils \
    findutils \
    grep \
    sed \
    gawk \
    coreutils \
    bash

# Set up NVM environment variable
ENV NVM_DIR="/root/.nvm"

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install NVM, Node.js v14.21.3, and a compatible version of pnpm
RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    bash -c "source $NVM_DIR/nvm.sh && nvm install v14.21.3 && nvm use v14.21.3 && npm install -g pnpm@7" && \
    echo 'export NVM_DIR="/root/.nvm"' >> /root/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /root/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /root/.bashrc

# Verify installation of Node.js and compatible pnpm version
RUN bash -c "source $NVM_DIR/nvm.sh && node -v && nvm current && pnpm -v"

# Old Details
ENV SLEEP_DURATION 5s

COPY build.sh .
COPY getDynamicVars.sh .
COPY set_npmrc.sh .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
RUN chmod +x build.sh set_npmrc.sh getDynamicVars.sh

ENV ENABLE_MAVEN_SILENT_MODE false
ENV SOURCE_JSON_FILE mavenrepos.json

ENV VALIDATION_FAILURE_ACTION WARNING    
ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE
ENTRYPOINT [ "/usr/local/bin/switch_versions.sh", "./build.sh" ]

# Default command
CMD ["bash"]
