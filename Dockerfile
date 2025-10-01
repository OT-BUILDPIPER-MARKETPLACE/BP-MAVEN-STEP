FROM registry.buildpiper.in/base-image/java-maven:2.0.5

RUN apt-get update && apt-get install -y \
    libxml2-utils \
    findutils \
    grep \
    sed \
    gawk \
    coreutils \
    bash

RUN groupadd -g 65522 buildpiper && \
    useradd -u 65522 -g buildpiper -d /home/buildpiper -m buildpiper && \
    chown -R buildpiper:buildpiper /home/buildpiper
    
RUN mkdir -p /home/buildpiper/.m2 && \
    chown -R buildpiper:buildpiper /home/buildpiper/.m2


WORKDIR /home/buildpiper

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

# Copy necessary scripts and set ownership
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper getDynamicVars.sh /home/buildpiper/getDynamicVars.sh
COPY --chown=buildpiper:buildpiper set_npmrc.sh /home/buildpiper/set_npmrc.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/data /opt/buildpiper/data/


# Create workspace and reports directories with correct ownership
RUN mkdir -p /bp/workspace /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /bp /opt /home/buildpiper

# Make scripts executable
RUN chmod +x /home/buildpiper/build.sh /home/buildpiper/getDynamicVars.sh /home/buildpiper/set_npmrc.sh

# Old Details
ENV SLEEP_DURATION 5s
ENV ENABLE_MAVEN_SILENT_MODE false
ENV SOURCE_JSON_FILE mavenrepos.json
ENV VALIDATION_FAILURE_ACTION WARNING 
ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE

# Switch to non-root user
USER buildpiper

ENTRYPOINT [ "/usr/local/bin/switch_versions.sh", "./build.sh" ]

CMD ["bash"]
