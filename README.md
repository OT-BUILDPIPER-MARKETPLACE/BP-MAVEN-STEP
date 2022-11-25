# BP-MAVEN-STEP

I'll use maven to build the java project


## Setup
* Clone the code available at [BP-MAVEN-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-MAVEN-STEP)
* Build the docker image

```
git submodule init
git submodule update
docker build -t ot/mvn-execute-step:0.2 .
```

* Do local testing via image only
```
# Build code with default settings 
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ ot/mvn-execute-step:0.2

# Only compile the code
docker run -it --rm -v $PWD:/src -e WORKSPACE=/src -e CODEBASE_DIR=/ -e INSTRUCTION=compile ot/mvn-execute-step:0.2
```