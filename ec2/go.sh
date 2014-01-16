#!/bin/bash

# Base URL of GFS file server
BASE_URL="http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod"

# We download forecasts between 03h and 72h (i.e. 3 days)
FORECAST_HOURS="03 06 09 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72"
#FORECAST_HOURS="03 06 09 12 15 18 21 24"

# We download only the variables below (see download() for partial download logic)
VARIABLES="APCP:surface\|TCDC:entire"

export NCARG_ROOT=/home/alberto/meteo_app/ncl_ncarg


##############################################################################################
# download grib2 files from NCEP website
# This function supports partial http downloads through the get_inv.pl and get_grib.pl scripts
#
# $1 = date
# $2 = time (model cycle)
#

download()
{
		if [ ! -e grib ]; then
			mkdir grib
		fi
		
        for FTIME in $FORECAST_HOURS; do
                echo $FTIME
                URL=$BASE_URL/gfs.${1}${2}/gfs.t${2}z.pgrb2f${FTIME}
                ./get_inv.pl $URL.idx | grep $VARIABLES | ./get_grib.pl $URL grib/forecast.${FTIME}.grib2 &>/dev/null
        done
}




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



###############################################################################################
#
# Main
#


echo `date +"%Y%m%d %H:%M:%S"` - Go!

echo Checking latest forecast available...
find_latest
echo The latest forecast is $date-$time.

echo Downloading forecast...	
download $date $time

echo Creating maps...
$NCARG_ROOT/bin/ncl precip_and_cloud.ncl
tar cf maps.tar maps/

echo Done!

