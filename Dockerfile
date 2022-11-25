FROM maven:3.3-jdk-8

RUN apt-get update || true
RUN apt-get install jq 
ENV SLEEP_DURATION 5s
ENV INSTRUCTION pacakge
COPY build.sh .
COPY BP-BASE-SHELL-STEPS/functions.sh .

ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE

ENTRYPOINT [ "./build.sh" ]