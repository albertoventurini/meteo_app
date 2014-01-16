#!/bin/bash

# Base URL of GFS file server
BASE_URL="http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod"

# Environment variables for EC2 API tools
export JAVA_HOME=/usr
export EC2_HOME=/home/alberto/ec2-api-tools/ec2-api-tools-1.6.9.0
export PATH=$PATH:$EC2_HOME/bin
export AWS_ACCESS_KEY=
export AWS_SECRET_KEY=
export EC2_URL=

EC2_INSTANCE_ID=




###############################################################################################
# Check if a forecast exists on the GFS file server
#
# Input:
#   $1 = date
#   $2 = model cycle (00 | 06 | 12 | 18)
#
# Return value
#   check_result = 1  ==> the forecast exists
#   check_result = 0  ==> the forecast doesn't exist
#
# Since we only want to download 4 days of forecast, we check if file 99 exists.
# We check 99 instead of 96, so that we are sure that both grib2 and idx files for hour 96 have completely been written,
# because idx files might be written before grib2 files.
#

check()
{
	check_result=1
	
	wget $BASE_URL/gfs.${1}${2}/gfs.t${2}z.pgrb2f99.idx &>/dev/null
	if [ -e gfs.t${2}z.pgrb2f99.idx ]
	then
		rm -f gfs.t${2}z.pgrb2f99.idx
	else
		check_result=0
	fi
}



###############################################################################################
# Find the latest forecast available on the GFS file server, which needs to be downloaded
#
# Return value:
#    date = the date of the latest forecast
#    time = the time (model cycle) of the latest forecast
#

find_latest()
{
	TODAY=`date +%Y%m%d`
	YESTERDAY=`date -d '1 day ago' +%Y%m%d`
		
	for CYCLE in 18 12 06 00; do
		check $TODAY $CYCLE
		if [ $check_result -eq 1 ]; then
			date=$TODAY
			time=$CYCLE
			return 1
		fi
	done

	for CYCLE in 18 12 06 00; do
		check $YESTERDAY $CYCLE
		if [ $check_result -eq 1 ]; then
			date=$YESTERDAY
			time=$CYCLE
			return 1
		fi
	done
	
	return 0
}




start_ec2()
{
	ec2-start-instances $EC2_INSTANCE_ID &>/dev/null

	i=0
	while [ `ec2-describe-instances $EC2_INSTANCE_ID | grep INSTANCE | cut -f 6` != "running" ]; do
		sleep 5
		((i+=1))
		if [ $i -gt 15 ]; then
			echo Error attempting to start EC2 instance $EC2_INSTANCE_ID. Aborting...
			exit 1
		fi
	done
}


stop_ec2()
{
	echo Stopping EC2 instance $EC2_INSTANCE_ID...
	ec2-stop-instances $EC2_INSTANCE_ID &>/dev/null
}




run_ec2_app()
{
        echo Checking status of instance $EC2_INSTANCE_ID...
        ec2_status=`ec2-describe-instances $EC2_INSTANCE_ID | grep INSTANCE | cut -f 6`

        if [ $ec2_status = "running" ]; then
                echo Instance already running

        else
                echo Instance stopped, starting up...
		start_ec2
	fi

	EC2_IP_ADDRESS=`ec2-describe-instances $EC2_INSTANCE_ID | grep NICASSOCIATION | cut -f 2`

	i=0
	while true; do
		ssh -o StrictHostKeyChecking=no alberto@$EC2_IP_ADDRESS '/home/alberto/meteo_app/go_wrapper.sh'
		if [ $? -ne 255 ]; then break; fi

		sleep 5
		
		((i+1))
		if [ $i -eq 5 ]; then
			echo Failed to connect to EC2 via SSH. Aborting...
			exit 1
		fi		
	done

	scp -o StrictHostKeyChecking=no alberto@$EC2_IP_ADDRESS:/home/alberto/meteo_app/maps.tar .


	if [ $ec2_status = "running" ]; then
		echo Instance was already running, so we won\'t stop it
	else
		stop_ec2
	fi


	# Clean up ~/.ssh/known_hosts to remove the fingerprint of the EC2 instance, because the IP address changes every time
	ssh-keygen -R $EC2_IP_ADDRESS
	
}




###############################################################################################
#
# Main
#



echo `date +"%Y%m%d %H:%M:%S"` - Go!

echo Checking latest forecast available...
find_latest
echo The latest forecast is $date-$time.


if [ -e $date-$time ]; then
	echo This forecast has already been downloaded. Nothing to do.
	exit 0
fi

touch $date-$time

run_ec2_app

echo Extracting maps...
tar -xf maps.tar
cp maps/* /var/www/html/meteo/
rm -rf maps/ maps.tar
