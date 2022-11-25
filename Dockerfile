FROM maven:3.3-jdk-8

RUN apt-get -y  --force-yes install debian-keyring debian-archive-keyring || true
RUN apt-key update || true
RUN apt-get -y update || true
RUN apt-get -y --force-yes install jq 

ENV SLEEP_DURATION 5s
ENV INSTRUCTION pacakge

COPY build.sh .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE

ENTRYPOINT [ "./build.sh" ]