#!/bin/bash
source /home/gor/easy_console/VARIABLE
export > /home/gor/easy_console/VARIABLE
DIRECTORY=$(date +"%d-%m-%Y")
echo "####################################################"
echo "Full Maintenance Started at $(date)"
echo "####################################################"
#sshpass -p '$PASSWORD_OF_PLATFORM_DB' ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP "tmux new-session -d -s platform_srms 'echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S python $PATH_OF_SCRIPT/delete_from_platform_srms.py'"
#sshpass -p '$PASSWORD_OF_PLATFORM_DB' ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP "tmux new-session -d -s wms_process 'echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S python $PATH_OF_SCRIPT/delete_from_platform_srms.py'"
#sshpass -p '$PASSWORD_OF_PLATFORM_DB' ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP "tmux new-session -d -s wms_notification 'echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S python $PATH_OF_SCRIPT/delete_from_platform_srms.py'"

echo "SKIPPING Archiving for RC 105"
#sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/archiving.escript
#sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/ppstaskrec_archival.escript
#sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/order_mod_archival.escript


echo "Checking Data sanity on Core Server"
data_sanity=`sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/data_sanity.escript  | awk -F[\(\)] '{print $2}'`
data_domain=`sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/data_validation.escript  | awk -F[\(\)] '{print $2}'`
echo "Data sanity is : " $data_sanity
echo "Data validate_all_tables is : " $data_domain
echo "Syncing Inventory on Core Server"
sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/sync_inventory.escript

echo "Starting Tmux session for archiving Postgres on Platform DB"
#Possibility of having issue with "" which we face in tmux

tmux new-session -d -s platform_srms "sshpass -p '$PASSWORD_OF_PLATFORM_DB' ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP 'echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S python $PATH_OF_SCRIPT/delete_from_platform_srms.py 30'"
tmux new-session -d -s wms_process "sshpass -p '$PASSWORD_OF_PLATFORM_DB' ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP 'echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S python $PATH_OF_SCRIPT/delete_from_wms_process.py 30'"
tmux new-session -d -s wms_notification "sshpass -p '$PASSWORD_OF_PLATFORM_DB' ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP 'echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S python $PATH_OF_SCRIPT/delete_from_wms_notification.py 30'"

#Need to execute below code when all above three tmux session has been completed
session_1="platform_srms"
session_2="wms_process"
session_3="wms_notification"
srms=false
process=false
notification=false

while [ "$srms" == false ] || [ "$process" == false ] || [ "$notification" == false ] 
do
	# Check if the session exists, discarding output
	# We can check $? for the exit status (zero for success, non-zero for failure)
	sleep 0.1
	tmux has-session -t $session_1 2>/dev/null
	
	if [ $? != 0 ]; then
	  	echo "PLATFORM SRMS ARCHIVING COMPLETE"
	  	srms=true
	else
		echo "platform_srms archiving is still running"
	fi
	sleep 0.1
	tmux has-session -t $session_2 2>/dev/null
	
	if [ $? != 0 ]; then
	  	echo "WMS PROCESS ARCHIVING COMPLETE"
	  	process=true
	else
		echo "wms_process archiving is still running"
	fi
	sleep 0.1
	tmux has-session -t $session_3 2>/dev/null
	
	if [ $? != 0 ]; then
	  echo "WMS NOTIFICATION ARCHIVING COMPLETE"
	  echo ""
	  notification=true
	else
		echo "wms_notification archiving is still running"
		echo ""
	fi
	sleep 2
done

echo "####################################################"
echo "Platform DB Archiving COMPLETE"
echo "####################################################"

sleep 1

echo "####################################################"
echo "Restarting Tower"
echo "####################################################"

sshpass -p "$PASSWORD_OF_TOWER" ssh -o StrictHostKeyChecking=no -t gor@$TOWER_IP "echo '$PASSWORD_OF_TOWER' | sudo -S docker restart tower"

sleep 5 #sleep for 5 second

echo "####################################################"
echo "Tower Status"
echo "####################################################"

sshpass -p "$PASSWORD_OF_TOWER" ssh -o StrictHostKeyChecking=no -t gor@$TOWER_IP "echo '$PASSWORD_OF_TOWER' | sudo -S docker status tower | cat"


echo "####################################################"
echo "Restarting Postgres Database"
echo "####################################################"

sshpass -p "$PASSWORD_OF_PLATFORM_DB" ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP "echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S systemctl restart postgresql@9.6-main.service"

echo "Going for sleep for 2 minutes"
runtime="2 minute"
endtime=$(date -ud "$runtime" +%s)

while [[ $(date -u +%s) -le $endtime ]]
do
    echo -n "Time Now: `date +%H:%M:%S`"
    echo -n "  I am still Awake counting 2 minutes"
    echo ""
    sleep 10
done

echo "####################################################"
echo "Postgres Database Status"
echo "####################################################"

sshpass -p "$PASSWORD_OF_PLATFORM_DB" ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP "echo '$PASSWORD_OF_PLATFORM_DB' | sudo -S systemctl status postgresql@9.6-main.service | cat"

echo "####################################################"
echo "Restarting Butler Interface"
echo "####################################################"

sshpass -p "$PASSWORD_OF_INTERFACE" ssh -o StrictHostKeyChecking=no -t gor@$INTERFACE_IP "echo '$PASSWORD_OF_INTERFACE' | sudo -S supervisorctl restart all"

# sleep for 1 minute
echo "Going for sleep for 1 minutes"
runtime="1 minute"
endtime=$(date -ud "$runtime" +%s)

while [[ $(date -u +%s) -le $endtime ]]
do
    echo -n "Time Now: `date +%H:%M:%S`"
    echo -n "  I am still Awake counting 1 minutes"
    echo ""
    sleep 10
done

echo "####################################################"
echo "Butler Interface Status"
echo "####################################################"

sshpass -p "$PASSWORD_OF_INTERFACE" ssh -o StrictHostKeyChecking=no -t gor@$INTERFACE_IP "echo '$PASSWORD_OF_INTERFACE' | sudo -S supervisorctl status all | cat"


echo "####################################################"
echo "Restarting Butler Server"
echo "####################################################"

if [ "$data_sanity" == "true" ] && [ "$data_domain" == "true" ]; then
	echo "Data sanity & Data domain validation check is true, Restarting Butler server is safe"
	echo "$PASSWORD_OF_CORE" | sudo -S service butler_server restart
	
	#Sleep for atleast 15 min
	echo "Going for sleep for 15 minutes"
	runtime="15 minute"
	endtime=$(date -ud "$runtime" +%s)
	
	while [[ $(date -u +%s) -le $endtime ]]
	do
	    echo -n "Time Now: `date +%H:%M:%S`"
	    echo -n "  I am still Awake counting 15 minutes"
	    echo ""
	    sleep 10
	done
	
	echo "####################################################"
	echo "Butler Server Status"
	echo "####################################################"
	
	echo "$PASSWORD_OF_CORE" | sudo -S service butler_server status | cat

else
	echo "Data sanity or Data domain validation check is FALSE, SKIPPING Butler Server Restart"
fi

echo "####################################################"
echo "Data Sanity and Node check after Butler Server restart"
echo "####################################################"
echo ""
data_sanity=`sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/data_sanity.escript  | awk -F[\(\)] '{print $2}'`
data_domain=`sudo /opt/butler_server/erts-9.3.3.6/bin/escript /home/gor/easy_console/maintenance/data_validation.escript  | awk -F[\(\)] '{print $2}'`
echo "Data sanity is : " $data_sanity
echo "Data validate_all_tables is : " $data_domain


echo "####################################################"
echo "Restarting Tomcat"
echo "####################################################"

sshpass -p "$PASSWORD_OF_PLATFORM_CORE" ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_CORE_IP "echo '$PASSWORD_OF_PLATFORM_CORE' | sudo -S systemctl restart tomcat"

# Sleep for 20 minutes
echo "Going for sleep for 20 minutes"
runtime="20 minute"
endtime=$(date -ud "$runtime" +%s)

while [[ $(date -u +%s) -le $endtime ]]
do
    echo -n "Time Now: `date +%H:%M:%S`"
    echo -n "  I am still Awake counting 20 minutes"
    echo ""
    sleep 10
done


echo "####################################################"
echo "Tomcat Status"
echo "####################################################"

sshpass -p "$PASSWORD_OF_PLATFORM_CORE" ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_CORE_IP "echo '$PASSWORD_OF_PLATFORM_CORE' | sudo -S systemctl status tomcat | cat"

echo ""
echo "####################################################"
echo "All Server Restart Completed"
echo "####################################################"
echo ""

echo "####################################################"
echo "Checking Disk Space for all VM"
echo "####################################################"
echo ""

echo "Interface Disk Space"
sshpass -p "$PASSWORD_OF_INTERFACE" ssh -o StrictHostKeyChecking=no -t gor@$INTERFACE_IP "df -h"
echo "Platform DB Disk Space"
sshpass -p "$PASSWORD_OF_PLATFORM_DB" ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_DB_IP "df -h"
echo "Butler Core Disk Space"
sshpass -p "$PASSWORD_OF_CORE" ssh -o StrictHostKeyChecking=no -t gor@$CORE_IP "df -h"
echo "Platform Core Disk Space"
sshpass -p "$PASSWORD_OF_PLATFORM_CORE" ssh -o StrictHostKeyChecking=no -t gor@$PLATFORM_CORE_IP "df -h"

echo ""

echo "####################################################"
echo "Checking Mnesia size (ETS Table memory and size)"
echo "####################################################"
echo ""

sudo /opt/butler_server/bin/butler_server rpcterms ets i > /home/gor/easy_console/"$DIRECTORY"_mnesia_table_raw_data.txt
awk 'BEGIN{print "id,name,type,size,mem,owner"}{print $1","$2","$3","$4","$5","$6}' /home/gor/easy_console/"$DIRECTORY"_mnesia_table_raw_data.txt > /home/gor/easy_console/"$DIRECTORY"_mnesia_table.csv

echo "Please check" "$DIRECTORY""_mnesia_table.csv in /home/gor/easy_console/"


echo "####################################################"
echo "Please run script which need to run after butler server restart (if any)"
echo "####################################################"
echo ""


echo "####################################################"
echo "Full MAINTENANCE COMPLETE at $(date)"
echo "####################################################"
