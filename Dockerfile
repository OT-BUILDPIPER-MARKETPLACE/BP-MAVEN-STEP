FROM 3.6.3-openjdk-11

RUN apt-get update || true
RUN apt-get install jq 
ENV SLEEP_DURATION 5s
COPY build.sh .
COPY BP-BASE-SHELL-STEPS/functions.sh .

ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE

ENTRYPOINT [ "./build.sh" ]
