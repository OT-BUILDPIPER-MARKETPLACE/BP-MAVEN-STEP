FROM maven:3.8-openjdk-17

# Step 2: Update system
RUN microdnf -y update || true

# Step 3: Install jq without --force-yes
RUN microdnf -y install jq

ENV SLEEP_DURATION 5s
ENV INSTRUCTION package

COPY build.sh .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE

ENTRYPOINT [ "./build.sh" ]