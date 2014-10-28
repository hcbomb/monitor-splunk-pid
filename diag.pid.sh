#!/bin/bash

pid=$(/opt/splunk/bin/splunk status | grep splunkd | grep -Eo "[0-9]+")
mydate=$(date +%F.%T)
logfile=pid.diag.$mydate.txt
delay=0.1
nTimes=10
myhost=$(hostname | cut -d. -f1)
email_dest=hcanivel@salesforce.com
archive="archive.pids"

# THERE CAN ONLY BE ONE
mypid0="$$"
mypid1="$((($mypid0+1)))"
#dpids="$(ps aux | grep diag.pid.sh | grep -vE "grep|$mypid0|$mypid1" | awk '{print $2}')"
#echo "$(ps aux | grep diag.pid.sh | grep -vE "grep" )"
#echo -e "my pid: $mypid0 $mypid1 \n\npids only:\n\t$dpids"
#if [[ -n "$dpids" ]]; then
#  echo "$mydate. found some pre-existing diags running: $dpids #KILLTHEM" #>> $logfile
#  kill -9 $dpids
#fi
#exit

echo "starting new diag file at: $mydate" >> $logfile 2>&1

while sleep 60; do
  secs=$(date +%s)
  mydate=$(date +%F.%T)

  echo "[$mydate]" >> $logfile 2>&1
  piddir="/proc/$pid"
  if [[ ! -d $piddir || -z "$(/opt/splunk/bin/splunk status | grep splunkd | grep -Eo "[0-9]+")" ]]; then
    # reset pid
    oldpid="$(echo $pid)"
    echo "Splunk is dead. Restarting. time: $mydate"
    su - splunk -c '/opt/splunk/bin/splunk start'
    mydate=$(date +%F.%T)
    pid=$(/opt/splunk/bin/splunk status | grep splunkd | grep -Eo "[0-9]+")
    echo "splunkd $oldpid died. new: $pid" >> $logfile 2>&1
    # tar this file (may be too large to send)
    tar czf $logfile.tgz $logfile
    # email notification
    # optional time throttling
    echo "the splunkds is dead. old: $oldpid new: $pid" | mail -a $logfile.tgz -s "$myhost: $splunkd died at $mydate" $email_dest
    # update for new file
    if [[ ! -d $archive ]]; then 
      mkdir $archive
    fi
    # move ALL THE DIAGS
    mv pid.diag.*.txt pid.diag.*.tgz $archive
    logfile=pid.diag.$mydate.txt
    echo "starting new diag file at: $mydate" >> $logfile 2>&1
    echo "[$mydate]" >> $logfile 2>&1
  fi
  echo "pid status =============>" >> $logfile 2>&1
  cat $piddir/status >> $logfile 2>&1
  echo "pid stack =============>" >> $logfile 2>&1
  cat $piddir/stack >> $logfile 2>&1
  echo "pid stat =============>" >> $logfile 2>&1
  cat $piddir/stat >> $logfile 2>&1
  echo "pid statm =============>" >> $logfile 2>&1
  cat $piddir/statm >> $logfile 2>&1
  echo "top =============>" >> $logfile 2>&1
  top -b -d $delay -n $nTimes -p $pid >> $logfile 2>&1
  echo "pidstat =============>" >> $logfile 2>&1
  pidstat -p $pid >> $logfile >> $logfile 2>&1
  echo "pmap =============>" >> $logfile 2>&1
  pmap -x $pid >> $logfile >> $logfile 2>&1
  #echo "lsof =============>" >> $logfile 2>&1
  #lsof -p $pid >> $logfile 2>&1
  echo "-------" >> $logfile 2>&1
done
