#! /bin/bash
if [[ $# -ne 1 ]]
  then
    echo "please provid the name of chrome build (e.g out/ref/chrome -> ref)"
    exit 1
fi

if [[ -z "${ENVIRONMENT_FOLDER}" ]]; then
  echo "ENVIRONMENT_FOLDER not set, leave"
  exit 1
fi
# set the environment properly, find better folder for the original script
if [ ! -f ${ENVIRONMENT_FOLDER}/environment_patched.sh ]
then
    echo "environment_patched.sh doest not exist. Aborting..."
    exit 255
fi
source ${ENVIRONMENT_FOLDER}/environment_patched.sh 

TYPESAFETY_CHROMIUM_FOLDER=${TYPESAFETY_FOLDER}/chromium
TYPESAFETY_CHROMIUM_EVAL_FOLDER=${TYPESAFETY_CHROMIUM_FOLDER}/eval
export TYPEPLUS_LOG_PATH=/tmp/chromium

export DISPLAY=:1

VERSION=${1}
echo $VERSION

RUNS=1
for I in $(seq 1 $RUNS)
do
    echo $I
    rm -drf /home/nbadoux/Downloads/JetStream*

    /home/nbadoux/chromium/out/${VERSION}/chrome browserbench.org/JetStream --no-sandbox --single-process --disable-gpu --no-first-run --enable-field-trial-config --enable-benchmarking &
    CHROME_PID=$!
    sleep 25
    xdotool key Return 
    sleep 570
    xdotool  mousemove 312 343 click 3
    sleep 1
    xdotool mousemove 396 444 click 1
    sleep 1 
    xdotool key Return 
    sleep 1
    xdotool key Return
    sleep 1
    kill -2 $CHROME_PID
    cp "/home/nbadoux/Downloads/JetStream 2.1.html" ${TYPESAFETY_CHROMIUM_EVAL_FOLDER}/${VERSION}_${I}.html
done
# grep -oP '(?<=score">).*(?=</div><label>Score)' *.html
