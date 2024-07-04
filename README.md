# BP-MAVEN-STEP

I'll use maven to build the java project


## Setup
* Clone the code available at [BP-MAVEN-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-MAVEN-STEP)
* Build the docker image

```
git submodule init
git submodule update
docker build -t registry.buildpiper.in/maven-execute:air_3.8_jdk17 .
```

* Do local testing via image only
```
# Build code with default settings 
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ registry.buildpiper.in/maven-execute:air_3.8_jdk17

# Only compile the code
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ -e INSTRUCTION=compile registry.buildpiper.in/maven-execute:air_3.8_jdk17
```

# Reference

[package manager](https://github.com/oracle/container-images/issues/16)
[base image](https://hub.docker.com/layers/library/maven/3.8-openjdk-17/images/sha256-62e6a9e10fb57f3019adeea481339c999930e7363f2468d1f51a7c0be4bca26d?context=explore)