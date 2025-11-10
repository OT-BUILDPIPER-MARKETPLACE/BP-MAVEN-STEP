# Use an official Ubuntu as a parent image
FROM ubuntu:20.04

# Install basic utilities and curl
RUN apt-get update && \
    apt-get install -y curl wget unzip tar git jq && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user 'buildpiper' with UID/GID 65522
RUN groupadd -g 65522 buildpiper && \
    useradd -m -u 65522 -g 65522 -s /bin/bash buildpiper

# Install multiple versions of JDK
RUN mkdir -p /opt/jdk && cd /opt/jdk && \
    wget -qO- https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.12+7/OpenJDK11U-jdk_x64_linux_hotspot_11.0.12_7.tar.gz | tar xvz && \
    wget -qO- https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.2+8/OpenJDK17U-jdk_x64_linux_hotspot_17.0.2_8.tar.gz | tar xvz && \
    wget -qO- https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u312-b07/OpenJDK8U-jdk_x64_linux_hotspot_8u312b07.tar.gz | tar xvz && \
    wget -qO- https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21+35/OpenJDK21U-jdk_x64_linux_hotspot_21_35.tar.gz | tar xvz

# Install multiple versions of Maven
RUN mkdir -p /opt/maven && cd /opt/maven && \
    wget -qO- https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz | tar xvz && \
    wget -qO- https://archive.apache.org/dist/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.tar.gz | tar xvz && \
    wget -qO- https://archive.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz | tar xvz

# Change ownership of /opt directories
RUN mkdir /bp && chown -R buildpiper:buildpiper /opt/jdk /opt/maven /bp

# Set environment variables for JDK installations
ENV JAVA_VERSION=""
ENV JAVA_HOME_8=/opt/jdk/jdk8u312-b07
ENV JAVA_HOME_11=/opt/jdk/jdk-11.0.12+7
ENV JAVA_HOME_17=/opt/jdk/jdk-17.0.2+8
ENV JAVA_HOME_21=/opt/jdk/jdk-21+35

# Set environment variables for Maven installations
ENV MAVEN_VERSION=""
ENV MAVEN_HOME_363=/opt/maven/apache-maven-3.6.3
ENV MAVEN_HOME_381=/opt/maven/apache-maven-3.8.1
ENV MAVEN_HOME_354=/opt/maven/apache-maven-3.5.4

# Add Maven binaries to PATH
ENV PATH=$JAVA_HOME_8/bin:$JAVA_HOME_11/bin:$JAVA_HOME_17/bin:$JAVA_HOME_21/bin:$MAVEN_HOME_363/bin:$MAVEN_HOME_381/bin:$MAVEN_HOME_354/bin:$PATH

# Copy scripts
COPY build.sh /home/buildpiper/build.sh
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

# Set permissions
RUN chmod +x /home/buildpiper/build.sh && \
    chown -R buildpiper:buildpiper /home/buildpiper /opt/buildpiper

# Runtime environment variables
ENV SLEEP_DURATION=5s
ENV INSTRUCTION=package
ENV ACTIVITY_SUB_TASK_CODE=MVN_EXECUTE

# Switch to non-root user
USER buildpiper
WORKDIR /home/buildpiper

# Entrypoint
ENTRYPOINT ["./build.sh"]
