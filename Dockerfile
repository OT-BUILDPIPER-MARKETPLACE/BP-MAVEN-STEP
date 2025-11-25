FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------
# Install system packages
# ---------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y curl wget unzip tar git jq bash ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------
# Create BuildPiper user + directory structure
# ---------------------------------------------------------------------
RUN groupadd -g 65522 buildpiper && \
    useradd -m -u 65522 -g 65522 -s /bin/bash buildpiper && \
    mkdir -p \
      /app \
      /bp/data \
      /bp/execution_dir \
      /bp/workspace \
      /opt/buildpiper/shell-functions \
      /opt/buildpiper/data \
      /src/reports \
      /home/buildpiper/reports \
      /usr/local/bin \
      /opt/jdk \
      /opt/maven && \
    chown -R buildpiper:buildpiper /app /bp /opt /home/buildpiper /src /usr/local/bin /tmp

# ---------------------------------------------------------------------
# Environment defaults
# ---------------------------------------------------------------------
ENV SLEEP_DURATION=5s
ENV INSTRUCTION=package
ENV ACTIVITY_SUB_TASK_CODE=MVN_EXECUTE

# ---------------------------------------------------------------------
# Copy BuildPiper shell functions + script
# ---------------------------------------------------------------------
WORKDIR /app

COPY --chown=buildpiper:buildpiper build.sh ./build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/ /opt/buildpiper/shell-functions/
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/data /opt/buildpiper/data

RUN chmod +x /app/build.sh

# ---------------------------------------------------------------------
# Switch to non-root
# ---------------------------------------------------------------------
USER buildpiper

ENTRYPOINT ["./build.sh"]

