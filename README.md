# Performance evaluation for Lean OpenWhisk
A simple performance test for [`Lean OpenWhisk`](https://github.com/kpavel/incubator-openwhisk/tree/lean) . Determines throughput and end-user latency of the system using loadtest utility.
The test can be executed on the same machine where Lean Openwhisk installed or on another machine (will require SSH key setup for password-less access)

## Test setup
- A Lean OpenWhisk system is deployed.
- Test action created created in the Lean Openwhisk, e.g. you may use [`sleepy action`](https://github.com/kpavel/lean-openwhisk-performance/blob/master/sleepy.js)
- [`loadtest`](https://www.npmjs.com/package/loadtest) module installed on the machine where test.sh will be executed.
- (Optional in case OW running on remote machine) SSH password-less access configured (using SSH keys) from machine where test.sh is running to machine where Lean OpenWhisk instance

### Test flow
Based on input parameters the test iterates over specified payloads, and concurrencies e.g.

```shell
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
```


### Running the test:
e.g.
./test.sh -u https://192.168.33.18 -t 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP --owhome /home/osboxes/openwhisk --owc-initial 3 --owc-max 5 --payloads "timeout30 timeout30payload100K" --action sleepy --repeats 2

will result in alot of stdout and result file (`results` by default. can be specified as parameter, refer to the usage) containing data like:
```console
ow concurrency,loadtestconcurrency,latency,rps,errors,requests,totaltime(sec),realtotaltime(msec),payloadfile
3,3,96.8,31,0,100,3.271948778(sec),3464(msec),timeout30
3,3,84,35,0,100,2.852523208(sec),3034(msec),timeout30
3,3,227.9,13,0,100,7.85456818(sec),8083(msec),timeout30payload100K
3,3,184.9,16,0,100,6.2941276639999995(sec),6471(msec),timeout30payload100K
4,4,130.9,29,0,100,3.502904528(sec),3812(msec),timeout30
4,4,118.9,32,0,100,3.142050133(sec),3438(msec),timeout30
4,4,307.3,13,0,100,7.920198695(sec),8250(msec),timeout30payload100K
4,4,294.1,13,0,100,7.628119883(sec),7957(msec),timeout30payload100K
5,5,133.3,32,0,100,3.159170295(sec),3410(msec),timeout30
5,5,161.7,30,0,100,3.330637265(sec),3662(msec),timeout30
5,5,363.9,13,0,100,7.640142490000001(sec),7997(msec),timeout30payload100K
5,5,328.6,15,0,100,6.870895376(sec),7138(msec),timeout30payload100K
```
