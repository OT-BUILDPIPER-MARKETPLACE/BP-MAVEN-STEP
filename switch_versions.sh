#!/bin/bash

# Function to display usage instructions
display_usage() {
  echo "##############################################"
  echo "# Welcome to the Java & Maven Switcher #"
  echo "##############################################"
  echo "# Usage:"
  echo "# Set the following environment variables to control the versions:"
  echo "#"
  echo "# - JAVA_VERSION: Choose from 8, 11, 17, or 21 (default: 8)"
  echo "#   Example: JAVA_VERSION=11"
  echo "#"
  echo "# - MAVEN_VERSION: Choose from 3.6.3, 3.8.1, 3.9.9 or 3.5.4 (default: 3.6.3)"
  echo "#   Example: MAVEN_VERSION=3.8.1"
  echo "#"
  echo "# If no values are provided, the script will default to JDK 8 and Maven 3.6.3."
  echo "##############################################"
  echo ""
}

# Default versions
JAVA_VERSION=${JAVA_VERSION:-8}
MAVEN_VERSION=${MAVEN_VERSION:-3.6.3}

# Check for unsupported JAVA_VERSION
if [ "$JAVA_VERSION" != "8" ] && [ "$JAVA_VERSION" != "11" ] && [ "$JAVA_VERSION" != "17" ] && [ "$JAVA_VERSION" != "21" ]; then
  echo "Error: Unsupported JAVA_VERSION: $JAVA_VERSION"
  display_usage
  exit 1
fi

# Check for unsupported MAVEN_VERSION
if [ "$MAVEN_VERSION" != "3.6.3" ] && [ "$MAVEN_VERSION" != "3.8.1" ] && [ "$MAVEN_VERSION" != "3.5.4" ] && [ "$MAVEN_VERSION" != "3.9.9" ]; then
  echo "Error: Unsupported MAVEN_VERSION: $MAVEN_VERSION"
  display_usage
  exit 1
fi

# If default values are being used, display a message
if [ -z "$JAVA_VERSION" ] && [ -z "$MAVEN_VERSION" ]; then
  echo "No JAVA_VERSION or MAVEN_VERSION provided, using defaults."
  display_usage
fi

# Switch Java version
if [ "$JAVA_VERSION" == "8" ]; then
  export JAVA_HOME=$JAVA_HOME_8
elif [ "$JAVA_VERSION" == "11" ]; then
  export JAVA_HOME=$JAVA_HOME_11
elif [ "$JAVA_VERSION" == "17" ]; then
  export JAVA_HOME=$JAVA_HOME_17
  elif [ "$JAVA_VERSION" == "21" ]; then
  export JAVA_HOME=$JAVA_HOME_21
fi

# Switch Maven version
if [ "$MAVEN_VERSION" == "3.6.3" ]; then
  export MAVEN_HOME=$MAVEN_HOME_363
elif [ "$MAVEN_VERSION" == "3.8.1" ]; then
  export MAVEN_HOME=$MAVEN_HOME_381
elif [ "$MAVEN_VERSION" == "3.5.4" ]; then
  export MAVEN_HOME=$MAVEN_HOME_354
elif [ "$MAVEN_VERSION" == "3.9.9" ]; then
  export MAVEN_HOME=$MAVEN_HOME_399
fi

# Update PATH
export PATH=$JAVA_HOME/bin:$MAVEN_HOME/bin:$PATH

# Log the selected versions
echo "Using JDK version: $JAVA_VERSION ($JAVA_HOME)"
echo "Using Maven version: $MAVEN_VERSION ($MAVEN_HOME)"

# Execute the passed command
exec "$@"