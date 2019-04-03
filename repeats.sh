set -x
set -e
tmp=tmpfile
function runload {
    /usr/local/bin/loadtest --insecure -n 100  -c 1 -k -m POST -H "authorization: Basic MjNiYzQ2YjEtNzFmNi00ZWQ1LThjNTQtODE2YWE0ZjhjNTAyOjEyM3pPM3haQ0xyTU42djJCS0sxZFhZRnBYbFBrY2NPRnFtMTJDZEFzTWdSVTRWck5aOWx5R1ZDR3VNREdJd1A=" -T "application/json" -p "timeout30" "https://172.17.0.1/api/v1/namespaces/guest/actions/sleepy?blocking=true">$tmp
    cat $tmp
    cat $tmp >> alllog
}

function repeat {
for t in `seq 1 1 15`
do
    echo "iterator " $t
    runload
    sleep 20
done
}
for mem in `seq 1 1 5`
do 
    date >> alllog
    echo "memory"=$mem*1024 >> alllog
    wskdev -d invoker -t local -e invoker_user_memory="$[$mem*1024]m" -e skip_pull_runtimes=True
    sleep 20
    repeat
done 

