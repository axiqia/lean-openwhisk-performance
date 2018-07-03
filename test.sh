#!/bin/bash

requests=100
resultfile=results
owc_initial_concurrency=1
load_initial_concurrency=1
step=1
maxowconcurrency=1
repeats=30

usage() {
    cat <<EOM

Usage: $(basename $0) <-u OPENWHISK_URL> <-t OW_AUTH_USER:PASS> <-a ACTION> <-o OW_HOME> <--owc-max OW_MAX_CONCURRENCY> <--payloads ACTION_PAYLOAD_FILENAME> [<--user username> <--ip address>] [--file filename] [--requests count] [--owc-initial int] [--load-initial int] [--step int] [--repeats int] [--load-max int]
Options:
  -u, --url    		OpenWhisk instance URL, e,g, https://192.168.33.18
  -t, --authorization 	OpenWhisk authorization string (USER:PASSWORD), e.g. 23bc46b2-71f6-4ed5-8c54-816aa4c8c502:123zO1xZCLrMN6v2BKd1dXYFpXlPkccOFqm32CdAsMgRU4VrNZ9lyGVCGuMDGIwP
  -a, --action          Action in OpenWhisk (should be created before running $(basename $0))
  -o, --owhome          OpenWhisk home directory, e.g. /home/osboxes/openwhisk
  --owc-max		Maximum OpenWhisk concurrency the  test will iterate to
  --payloads            File(s) name(s) containing action payload test will iterate over, e.g. "timeout30payload1K timeout30payload100K"

  --user		Machine username, required in case of remote OpenWhisk instance  
  -i, --ip		Machine ip (or hostname). Required in case of remote OpenWhisk instance

  -f, --file  		Optional. Output file where results stored, default is "results"
  --requests            Optional. Number of requests per repeat iteration, default is 100
  --owc-initial		Optional. OpenWhisk initial concurrency, default is 1
  --load-initial	Optional. Loadtest initial concurrency, default is 1
  --step		Optional. Concurrency (load and ow) increment steps, default is 1
  --repeats		Optional. Number of repeats of each test iteration, default 30
  --load-max 		Optional. Maximal loadtest concurrency. Hidden functionality: in case not specified, will iterate only over points when (OW-CONCURRENCY==LOADTEST-CONCURRENCY)
  
Example:


running "sleepy" action on local OpenWhisk instance (running on localhost) with 2 payload files:
$(basename $0) -u https://localhost -t 33bc56b1-71f6-4ed5-7c54-816aa4f8c501:224fO3xZCLrMN6b2NKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyHVCGuMDGIwP --owhome /home/osboxes/openwhisk --owc-max 5 --payloads "timeout30payload1K timeout30payload100K" --action sleepy


running "sleepy" action on remote OpenWhisk instance running on a host 192.168.33.18 with user osboxes (requires config of password-less ssh access to the 192.168.33.18 using SSH keys)
$(basename $0) -u https://localhost -t 33bc56b1-71f6-4ed5-7c54-816aa4f8c501:224fO3xZCLrMN6b2NKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyHVCGuMDGIwP --owhome /home/osboxes/openwhisk --owc-max 5 --payloads timeout30payload1K --action sleepy --repeats 3 --user osboxes --ip 192.168.33.18


EOM
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -u|--url) owurl="$2"; shift ;;
    -t|--authorization) authorization="$2"; shift ;;
    --requests) requests="$2"; shift;;
    -a|--action) action="$2"; shift ;;
    -o|--owhome) owhome="$2"; shift ;;
    --payloads) PAYLOADS=("$2"); shift ;;
    --user) user="$2"; shift ;;
    -i|--ip) ip="$2"; shift ;;
    -f|--file) resultfile="$2"; shift ;;
    --owc-initial) owc_initial_concurrency="$2"; shift ;;
    --load-initial) load_initial_concurrency="$2"; shift ;;
    --step) step="$2"; shift;;
    --repeats) repeats="$2"; shift ;;
    --load-max) maxloadtestconcurrency="$2"; shift ;;
    --owc-max) maxowconcurrency="$2";shift ;;
    -h | --help ) usage; exit ;;
    * ) usage; exit 1
    POSITIONAL+=("$1")
    shift ;;
esac
    shift
done
set -- "${POSITIONAL[@]}"

if [[ -z $owurl || -z $authorization || -z ${PAYLOADS} || -z ${action} || -z ${owhome} || -z ${maxowconcurrency} ]]; then
  echo 'one or more mandatory variables are undefined'
  usage
  exit 1
fi

authorization="Basic "$(echo -n "$authorization" | openssl base64 -A)
ANSIBLE_HOME=${owhome}/ansible
tmp=mytemptestfile


echo $'\n\n'>>${resultfile}
echo "========================================================">>result
date>>${resultfile}
echo -e "ow concurrency,loadtestconcurrency,latency,rps,errors,requests,totaltime(sec),realtotaltime(msec),payloadfile">>${resultfile}
date>>resultslog

islocal () {
  [[ -z $user && -z $ip ]] 
}

cleanup () {
  echo -e "\n==============\nClean up started\n=============="
  sleep 1

  if islocal; then
    docker rm -f controller-lean
  else
    echo running $user@$ip "docker rm -f controller-lean"
    ssh $user@$ip "docker rm -f controller-lean"
  fi

  sleep 1 
  echo -e "\n==============\nCleanup finished\n============"
}

cleanup

if islocal; then
  /usr/local/bin/ansible-playbook ${ANSIBLE_HOME}/openwhisk-lean.yml -i ${ANSIBLE_HOME}/environments/local -e controller_akka_provider=local
else
  ssh $user@$ip "/usr/local/bin/ansible-playbook ${ANSIBLE_HOME}/openwhisk-lean.yml -i ${ANSIBLE_HOME}/environments/local -e controller_akka_provider=local"
fi

ANSIBLE_YML=${ANSIBLE_HOME}/controller-lean.yml
ANSIBLE_ENV="-e controller_akka_provider=local"
INVOKER_CONTAINER="controller-lean"


function updateOW {
  echo -e "\n===================\nUpdating concurrency to $1 in OW\n=========================\n"

  sleep 1
  echo -e "Running: /usr/bin/docker rm -f ${INVOKER_CONTAINER}"
  if islocal; then
    /usr/bin/docker rm -f ${INVOKER_CONTAINER}    
  else
    ssh $user@$ip "/usr/bin/docker rm -f ${INVOKER_CONTAINER}"
  fi  
  sleep 1

  LIMITS="-e limit_invocations_per_minute=99999 -e limit_invocations_concurrent=99999 -e limit_invocations_concurrent_system=99999"
  echo -e "Running: /usr/local/bin/ansible-playbook ${ANSIBLE_YML} -e invoker_coreshare=$1 -e invoker_numcore=1 ${LIMITS} ${ANSIBLE_ENV}"
  
  if islocal; then
    /usr/local/bin/ansible-playbook ${ANSIBLE_YML} -i ${ANSIBLE_HOME}/environments/local -e invoker_coreshare=$1 -e invoker_numcore=1 ${LIMITS} ${ANSIBLE_ENV}
  else
    ssh $user@$ip "/usr/local/bin/ansible-playbook ${ANSIBLE_YML} -i ${ANSIBLE_HOME}/environments/local -e invoker_coreshare=$1 -e invoker_numcore=1 ${LIMITS} ${ANSIBLE_ENV}"
  fi

  sleep 15
  echo "OW concurrency updated to $1, warming up with payload $2"

  echo -e "Running: /usr/local/bin/loadtest --insecure -n $requests -c $1 -k -m POST -H "authorization: $authorization" -T "application/json" -p $2 $owurl/api/v1/namespaces/_/actions/${action}?blocking=true"
  /usr/local/bin/loadtest --insecure -n $requests -c $1 -k -m POST -H "authorization: $authorization" -T "application/json" -p $2 $owurl/api/v1/namespaces/_/actions/${action}?blocking=true
  echo "done warming..."
  sleep 2
}

function runload {
  echo "running loadtest"
  date
  start=`date +%s%3N`

  echo -e "Running: /usr/local/bin/loadtest --insecure -n $requests -c $lc -k -m POST -H "authorization: $authorization" -T "application/json" -p $payload $owurl/api/v1/namespaces/_/actions/${action}?blocking=true>$tmp"
  /usr/local/bin/loadtest --insecure -n $requests -c $lc -k -m POST -H "authorization: $authorization" -T "application/json" -p $payload $owurl/api/v1/namespaces/_/actions/${action}?blocking=true>$tmp

  realtotaltime=$[`date +%s%3N`-$start]

  cat $tmp
  errors=`cat $tmp|grep "Total errors"|awk '{print $NF}'`
  rps=`cat $tmp|grep "Requests per second"|awk '{print $NF}'`
  totaltime=`cat $tmp|grep "Total time"`
  totaltime=`echo $totaltime|cut -d ' ' -f 11`

  latency=`cat $tmp|grep "Mean latency"`
  echo $latency
  latency=`echo $latency|cut -d ' ' -f 11`

  echo -e "result: $owc,$lc,$latency,$rps,$errors,$requests,${totaltime}(sec),${realtotaltime}(msec),$payload"
  result="$owc,$lc,$latency,$rps,$errors,$requests,${totaltime}(sec),${realtotaltime}(msec),$payload"
  echo $result>>${resultfile}

  echo $result>>resultslog
  cat $tmp>>resultslog
  sleep 2
}

function runrepeats {
  for i in `seq 1 ${repeats}`;
  do
    date
    echo ----------------
    echo "Runload, iteration ${i}"
    runload
  done
}

for owc in `seq ${owc_initial_concurrency} $step $maxowconcurrency`
do
  updateOW $owc ${PAYLOADS[0]} 
  date
  for payload in ${PAYLOADS[@]}
  do
    if [[ -z $maxloadtestconcurrency ]]; then
      #in case $maxloadtestconcurrency not set, lc == owc
      lc=$owc
      runrepeats 
    else
      for lc in `seq ${load_initial_concurrency} $step $maxloadtestconcurrency`
      do     
        for i in `seq 1 ${repeats}`;
        do
          runrepeats
	done
      done
    fi
  done
done
