FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------------
# Install basic utilities
# -------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        unzip \
        tar \
        git \
        jq \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------
# Prepare directories
# -------------------------------------------------------
RUN mkdir -p /opt/jdk /opt/maven

# -------------------------------------------------------
# JDK INSTALLS (ONE PER LAYER, CLEANED)
# -------------------------------------------------------

# JDK 8
RUN wget -q https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u312-b07/OpenJDK8U-jdk_x64_linux_hotspot_8u312b07.tar.gz \
    && tar xzf OpenJDK8U-jdk_x64_linux_hotspot_8u312b07.tar.gz -C /opt/jdk \
    && rm -f OpenJDK8U-jdk_x64_linux_hotspot_8u312b07.tar.gz

# JDK 11
RUN wget -q https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.12+7/OpenJDK11U-jdk_x64_linux_hotspot_11.0.12_7.tar.gz \
    && tar xzf OpenJDK11U-jdk_x64_linux_hotspot_11.0.12_7.tar.gz -C /opt/jdk \
    && rm -f OpenJDK11U-jdk_x64_linux_hotspot_11.0.12_7.tar.gz

# JDK 17
RUN wget -q https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.2+8/OpenJDK17U-jdk_x64_linux_hotspot_17.0.2_8.tar.gz \
    && tar xzf OpenJDK17U-jdk_x64_linux_hotspot_17.0.2_8.tar.gz -C /opt/jdk \
    && rm -f OpenJDK17U-jdk_x64_linux_hotspot_17.0.2_8.tar.gz

# JDK 21 - Existing version
RUN wget -q https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21+35/OpenJDK21U-jdk_x64_linux_hotspot_21_35.tar.gz \
    && tar xzf OpenJDK21U-jdk_x64_linux_hotspot_21_35.tar.gz -C /opt/jdk \
    && rm -f OpenJDK21U-jdk_x64_linux_hotspot_21_35.tar.gz

# JDK 25 - Existing version
RUN wget -q https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25%2B36/OpenJDK25U-jdk_x64_linux_hotspot_25_36.tar.gz \
    && tar xzf OpenJDK25U-jdk_x64_linux_hotspot_25_36.tar.gz -C /opt/jdk \
    && rm -f OpenJDK25U-jdk_x64_linux_hotspot_25_36.tar.gz

# -------------------------------------------------------
# JDK 25.0.4.1 - Existing version
# -------------------------------------------------------
RUN mkdir -p /opt/jdk/jdk-25.0.4.1+1 \
    && wget -q -O /tmp/jdk25.tar.gz \
       "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4.1_1.tar.gz" \
    && tar xzf /tmp/jdk25.tar.gz \
       --strip-components=1 \
       -C /opt/jdk/jdk-25.0.4.1+1 \
    && rm -f /tmp/jdk25.tar.gz


# -------------------------------------------------------
# JDK 21.0.13.1+2 - Latest Temurin JDK 21
# -------------------------------------------------------
RUN mkdir -p /opt/jdk/jdk-21.0.13.1+2 \
    && wget -q -O /tmp/temurin-jdk21-latest.tar.gz \
       "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13.1_2.tar.gz" \
    && tar xzf /tmp/temurin-jdk21-latest.tar.gz \
       --strip-components=1 \
       -C /opt/jdk/jdk-21.0.13.1+2 \
    && rm -f /tmp/temurin-jdk21-latest.tar.gz

# -------------------------------------------------------
# JDK 25.0.5.1+2 - Latest Temurin JDK 25
# -------------------------------------------------------
RUN mkdir -p /opt/jdk/jdk-25.0.5.1+2 \
    && wget -q -O /tmp/temurin-jdk25-latest.tar.gz \
       "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5.1%2B2/OpenJDK25U-jdk_x64_linux_hotspot_25.0.5.1_2.tar.gz" \
    && tar xzf /tmp/temurin-jdk25-latest.tar.gz \
       --strip-components=1 \
       -C /opt/jdk/jdk-25.0.5.1+2 \
    && rm -f /tmp/temurin-jdk25-latest.tar.gz

# -------------------------------------------------------
# MAVEN INSTALLS (ONE PER LAYER)
# -------------------------------------------------------

# Maven 3.5.4
RUN wget -q https://archive.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz \
    && tar xzf apache-maven-3.5.4-bin.tar.gz -C /opt/maven \
    && rm -f apache-maven-3.5.4-bin.tar.gz

# Maven 3.6.3
RUN wget -q https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz \
    && tar xzf apache-maven-3.6.3-bin.tar.gz -C /opt/maven \
    && rm -f apache-maven-3.6.3-bin.tar.gz

# Maven 3.8.1
RUN wget -q https://archive.apache.org/dist/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.tar.gz \
    && tar xzf apache-maven-3.8.1-bin.tar.gz -C /opt/maven \
    && rm -f apache-maven-3.8.1-bin.tar.gz

# Maven 3.9.16
RUN wget -q https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz \
    && tar xzf apache-maven-3.9.16-bin.tar.gz -C /opt/maven \
    && rm -f apache-maven-3.9.16-bin.tar.gz

# -------------------------------------------------------
# Create non-root user and group (UID/GID 65522)
# -------------------------------------------------------
RUN groupadd -g 65522 buildpiper \
    && useradd -u 65522 -g 65522 -m -s /bin/bash buildpiper

# -------------------------------------------------------
# Ownership
# -------------------------------------------------------
RUN chown -R buildpiper:buildpiper /opt/jdk /opt/maven

# -------------------------------------------------------
# Environment variables
# -------------------------------------------------------

# Existing JDKs
ENV JAVA_HOME_8=/opt/jdk/jdk8u312-b07
ENV JAVA_HOME_11=/opt/jdk/jdk-11.0.12+7
ENV JAVA_HOME_17=/opt/jdk/jdk-17.0.2+8
ENV JAVA_HOME_21=/opt/jdk/jdk-21+35
ENV JAVA_HOME_25=/opt/jdk/jdk-25+36
ENV JAVA_HOME_2504=/opt/jdk/jdk-25.0.4.1+1

# Latest Temurin JDK 21
ENV JAVA_HOME_2110131=/opt/jdk/jdk-21.0.13.1+2

# Latest Temurin JDK 25
ENV JAVA_HOME_250501=/opt/jdk/jdk-25.0.5.1+2

# Maven versions
ENV MAVEN_HOME_354=/opt/maven/apache-maven-3.5.4
ENV MAVEN_HOME_363=/opt/maven/apache-maven-3.6.3
ENV MAVEN_HOME_381=/opt/maven/apache-maven-3.8.1
ENV MAVEN_HOME_3916=/opt/maven/apache-maven-3.9.16

# -------------------------------------------------------
# Default Java: JDK 8
# Default Maven: 3.9.16
# -------------------------------------------------------
ENV JAVA_HOME=$JAVA_HOME_8
ENV MAVEN_HOME=$MAVEN_HOME_3916

ENV PATH=$JAVA_HOME/bin:$MAVEN_HOME/bin:$JAVA_HOME_11/bin:$JAVA_HOME_17/bin:$JAVA_HOME_21/bin:$JAVA_HOME_25/bin:$JAVA_HOME_2504/bin:$JAVA_HOME_21130103/bin:$JAVA_HOME_2110131/bin:$JAVA_HOME_250501/bin:$MAVEN_HOME_381/bin:$MAVEN_HOME_363/bin:$MAVEN_HOME_354/bin:$PATH

# -------------------------------------------------------
# BuildPiper setup
# -------------------------------------------------------
RUN mkdir -p /opt/buildpiper/shell-functions /bp

ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

COPY build.sh /opt/buildpiper/build.sh

RUN chmod +x /opt/buildpiper/build.sh \
    && chown -R buildpiper:buildpiper /opt/buildpiper /bp

# -------------------------------------------------------
# Legacy vars
# -------------------------------------------------------
ENV SLEEP_DURATION=5s
ENV INSTRUCTION=package
ENV ACTIVITY_SUB_TASK_CODE=MVN_EXECUTE

# -------------------------------------------------------
# Non-root execution
# -------------------------------------------------------
USER buildpiper

WORKDIR /opt/buildpiper

ENTRYPOINT ["/opt/buildpiper/build.sh"]