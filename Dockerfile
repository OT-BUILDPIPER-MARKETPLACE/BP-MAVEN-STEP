# Use an official Ubuntu as a parent image
FROM ubuntu:20.04

# Install basic utilities and curl
RUN apt-get update && \
    apt-get install -y curl wget unzip tar git jq

# Install multiple versions of JDK
RUN mkdir -p /opt/jdk
RUN wget -qO- https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.12+7/OpenJDK11U-jdk_x64_linux_hotspot_11.0.12_7.tar.gz | tar xvz -C /opt/jdk
RUN wget -qO- https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.2+8/OpenJDK17U-jdk_x64_linux_hotspot_17.0.2_8.tar.gz | tar xvz -C /opt/jdk
RUN wget -qO- https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u312-b07/OpenJDK8U-jdk_x64_linux_hotspot_8u312b07.tar.gz | tar xvz -C /opt/jdk
RUN wget -qO- https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21+35/OpenJDK21U-jdk_x64_linux_hotspot_21_35.tar.gz | tar xvz -C /opt/jdk

# Install multiple versions of Maven
RUN mkdir -p /opt/maven
RUN wget -qO- https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz | tar xvz -C /opt/maven
RUN wget -qO- https://archive.apache.org/dist/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.tar.gz | tar xvz -C /opt/maven
RUN wget -qO- https://archive.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz | tar xvz -C /opt/maven

# Set environment variables for JDK installations
ENV JAVA_VERSION ""
ENV JAVA_HOME_8 /opt/jdk/jdk8u312-b07
ENV JAVA_HOME_11 /opt/jdk/jdk-11.0.12+7
ENV JAVA_HOME_17 /opt/jdk/jdk-17.0.2+8
ENV JAVA_HOME_21 /opt/jdk/jdk-21+35

# Set environment variables for Maven installations
ENV MAVEN_VERSION ""
ENV MAVEN_HOME_363 /opt/maven/apache-maven-3.6.3
ENV MAVEN_HOME_381 /opt/maven/apache-maven-3.8.1
ENV MAVEN_HOME_354 /opt/maven/apache-maven-3.5.4

# Add Maven binaries to PATH
ENV PATH $JAVA_HOME_8/bin:$MAVEN_HOME_363/bin:$JAVA_HOME_11/bin:$MAVEN_HOME_381/bin:$JAVA_HOME_17/bin:$JAVA_HOME_354/bin:$JAVA_HOME_21/bin:$PATH

# Copy the script to switch JDK and Maven versions
COPY switch_versions.sh /usr/local/bin/switch_versions.sh
RUN chmod +x /usr/local/bin/switch_versions.sh

# Old Details
ENV SLEEP_DURATION 5s
ENV INSTRUCTION package

COPY build-sign.sh .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

ENV ACTIVITY_SUB_TASK_CODE MVN_EXECUTE

# Entrypoint 
ENTRYPOINT ["./build-sign.sh"]
