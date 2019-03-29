#set -x
set -e
tmp=alllog
  errors=`cat $tmp|grep "Total errors"|awk '{print $NF}'`
  rps=`cat $tmp|grep "Requests per second"|awk '{print $NF}'`
  totaltime=`cat $tmp|grep "Total time" |awk '{print $(NF-1)}'`

  #totaltime=`echo $totaltime|cut -d ' ' -f 11`

  latency=`cat $tmp|grep "Mean latency" |awk '{print $(NF-1)}'`

  #echo $latency
  #latency=`echo $latency|cut -d ' ' -f 11`
  echo $errors >> plot.csv
  echo $rps >> plot.csv
  echo $totaltime >> plot.csv
  echo $latency >> plot.csv
