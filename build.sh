#!/bin/bash
source functions.sh

echo "I'll build the code available at [$WORKSPACE] and have mounted at [$CODEBASE_DIR]"
sleep  $SLEEP_DURATION

cd  $WORKSPACE/${CODEBASE_DIR}
mvn $INSTRUCTION
if [ $? -eq 0 ]
then
  generateOutput mvn_execute true "Congratulations build succeeded!!!"
  echo "build sucessfull"
elif  [ $? != 0 ]
then 
  generateOutput mvn_execute false "Build failed please check!!!!!"
  echo "build unsucessfull"
  exit 1
fi
