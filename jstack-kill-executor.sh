#!/bin/bash

process=$1
executor=$2
host=$3
isKill=$4

date_dir=$(date +'%m-%d-%Y-%H')
aws_key="ssh-key.pem"
s3_base="watcher/info"

jstack_parent_directory="/root/watcher/jstacks/processs"

#Make sure to clone 'FlameGraph' repo to following location
#(git clone https://github.com/brendangregg/FlameGraph.git)
flamegraph_parent_directory="/root/flamegraph"

#rm -rf ${jstack_parent_directory}
mkdir -p ${jstack_parent_directory}/${process}/${date_dir}/Summary
mkdir -p ${jstack_parent_directory}/${process}/${date_dir}/GC-Details
mkdir -p ${jstack_parent_directory}/${process}/${date_dir}/jstacks
mkdir -p ${jstack_parent_directory}/${process}/${date_dir}/flamegraphs

#Collecting jstacks
container=$(ssh -o StrictHostKeyChecking=no -i ${aws_key} ubuntu@$host "sudo docker ps --no-trunc | grep -- '--executor-id $executor' | grep '${process}'" | awk '{print $1}')
pid=$(ssh -o StrictHostKeyChecking=no -i ${aws_key} ubuntu@$host "sudo docker exec $container jps" | grep CoarseGrainedExecutorBackend | cut -d' ' -f1)
for i in {1..3}
do
  ssh -o StrictHostKeyChecking=no -i ${aws_key} ubuntu@$host "sudo docker exec $container jstack $pid" >> ${jstack_parent_directory}/${process}/${date_dir}/jstacks/jstack.${executor}.${process}.${i}.txt
  file=jstack.${executor}.${process}.${i}.txt
  threads_count=`cat ${jstack_parent_directory}/${process}/${date_dir}/jstacks/${file} | grep "java.lang.Thread.State" | wc -l`
  runnable_count=`cat ${jstack_parent_directory}/${process}/${date_dir}/jstacks/${file} | grep "java.lang.Thread.State" | grep -i "runnable" |  wc -l`
  blocked_count=`cat ${jstack_parent_directory}/${process}/${date_dir}/jstacks/${file} | grep "java.lang.Thread.State" | grep -i "blocked" |  wc -l`
  waiting_count=`cat ${jstack_parent_directory}/${process}/${date_dir}/jstacks/${file} | grep "java.lang.Thread.State" | grep -i "waiting" | grep -v -i "timed" | wc -l`
  timed_count=`cat ${jstack_parent_directory}/${process}/${date_dir}/jstacks/${file} | grep "java.lang.Thread.State" | grep -i "timed_waiting" |  wc -l`
  echo "Total Thread Count : "${threads_count} >> ${jstack_parent_directory}/${process}/${date_dir}/Summary/summary-${file}
  echo "RUNNABLE           : "${runnable_count} >> ${jstack_parent_directory}/${process}/${date_dir}/Summary/summary-${file}
  echo "BLOCKED            : "${blocked_count} >> ${jstack_parent_directory}/${process}/${date_dir}/Summary/summary-${file}
  echo "WAITING            : "${waiting_count} >> ${jstack_parent_directory}/${process}/${date_dir}/Summary/summary-${file}
  echo "TIMED_WAITING      : "${timed_count} >> ${jstack_parent_directory}/${process}/${date_dir}/Summary/summary-${file}

  sleep 5
done

date > ${jstack_parent_directory}/.last-threaddump

#Generating flamegraphs
rm -rf ${flamegraph_parent_directory}/workdir/${process}
mkdir -p ${flamegraph_parent_directory}/workdir/${process}
${flamegraph_parent_directory}/FlameGraph/stackcollapse-jstack.pl ${jstack_parent_directory}/${process}/${date_dir}/jstacks/jstack.${executor}.${process}.1.txt ${jstack_parent_directory}/${process}/${date_dir}/jstacks/jstack.${executor}.${process}.2.txt ${jstack_parent_directory}/${process}/${date_dir}/jstacks/jstack.${executor}.${process}.3.txt >> ${flamegraph_parent_directory}/workdir/${process}/jstack.${executor}.${process}.folded
${flamegraph_parent_directory}/FlameGraph/flamegraph.pl ${flamegraph_parent_directory}/workdir/${process}/jstack.${executor}.${process}.folded > ${jstack_parent_directory}/${process}/${date_dir}/flamegraphs/flamegraph.${executor}.${process}.svg

ssh -o StrictHostKeyChecking=no -i ${aws_key} ubuntu@$host "sudo docker exec $container jstat -gcutil $pid 3000 5" >> ${jstack_parent_directory}/${process}/${date_dir}/GC-Details/gc-details.${executor}.${process}.${i}.txt

aws s3 cp ${jstack_parent_directory}/${process}/${date_dir} s3://${s3_base}/${process}/jstacks/${date_dir} --recursive

#Kill executors if kill switch is enabled and copy data to S3
if ($isKill)
then
  ssh -o StrictHostKeyChecking=no -i ${aws_key} ubuntu@$host "sudo docker kill $container"
  notify-slack.sh -c watcher-slack-channel -u "Someone is struggling" -i warning -h slack-hook -m "*What happened?:* $process executor hung.\n*Executor:* $executor\n*Host:* $host\n*Thread dumps:* http://application.watcher:8000/processs/${process}/${date_dir} \n *Actions taken:* \n1. Thread dumps and GC details collected and uploaded to s3://${s3_base}/${process}/jstacks/${date_dir}\n2. Flamegraphs generated and available in http://application.watcher:8000/processs/${process}/${date_dir}/flamegraphs \n3. Executor Killed" -T "process" -C ECB22E
else
  notify-slack.sh -c watcher-slack-channel -u "Someone is struggling" -i warning -h slack-hook -m "*What happened?:* $process executor hung.\n*Executor:* $executor\n*Host:* $host\n*Thread dumps:* http://application.watcher:8000/processs/${process}/${date_dir} \n *Actions taken:* \n1. Thread dumps and GC details collected and uploaded to s3://${s3_base}/${process}/jstacks/${date_dir}\n2. Flamegraphs generated and available in http://application.watcher:8000/processs/${process}/${date_dir}/flamegraphs" -T "process" -C ECB22E
fi
