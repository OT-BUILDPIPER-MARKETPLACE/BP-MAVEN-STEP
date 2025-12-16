FROM registry.buildpiper.in/base-image/java-maven:2.0.8-nr

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
RUN chmod +x /home/buildpiper/build.sh /home/buildpiper/getDynamicVars.sh 

# Old Details
ENV SLEEP_DURATION 5s
ENV ENABLE_MAVEN_SILENT_MODE false
ENV SOURCE_JSON_FILE mavenrepos.json
ENV VALIDATION_FAILURE_ACTION WARNING 
ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE

USER buildpiper

ENTRYPOINT [ "/usr/local/bin/switch_versions.sh", "./build.sh" ]

CMD ["bash"]
