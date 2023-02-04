#!/bin/bash
#
# VenusOS scheduled charge automation script (a.k.a. primitive node red bashing)
# Intended to be run by cron on a predefined time (not running as a process)
#
# This script will process ONLY if the ESS mode is set to Optimized mode without BatteryLife or to Keep batteries charged
#
#
##################################################################################
# Usage help:
##################################################################################
# Define variables
SCRIPTNAME="${0}"
SCRIPTNAME_PATH="/data/scripts/ess_opticharge"
#
# Configuration parameters:
# SOC value in [%] up to which the charge from grid to be initiated.
# If good PV production weather is expected, then pre-charge (during off peak tariff time) the battery up to this SOC threshold, only if the current SOC is <= STOP_ON_SOC_GOOD_PV.
# The value must be between [current_MIN_SOC_value - 90]. If the setting is out of this range, it is set to the edge value closer to the setting. This is done due to safety purposes.
STOP_ON_SOC_GOOD_PV="60"
# If bad PV production weather is expected, then pre-charge (during off peak tariff time) the battery up to this SOC threshold, only if the current SOC is <= STOP_ON_SOC_BAD_PV. This is generally greater than STOP_ON_SOC_GOOD_PV.
# The value must be between [current_MIN_SOC_value - 95]. If the setting is out of this range, it is set to the edge value closer to the setting. This is done due to safety purposes.
STOP_ON_SOC_BAD_PV="75"
#
# ESS Scheduled charge ID (0-4), there are 5 schedules in the ESS menu in Victron GX, if not present, the last one (t.e. 4) will be used as default
SCHED_CHARGE_ID="4"
#
# Off peak tarrif hours, typically this is the time interval that we would like the battery to be charged from grid
# Set the start and stop time in 24h format: [hh:mm]
# The GX should have clock correctly set. Calculations are done in accordance with the local time zone clock reading, that are returned back by date command
# It is important to understand that the energy taken from the grid during this period depends directly on the charge current limit (or max capability if no limits) set in the charger configuration or/and in DVCC menu.
# T.e. if you have set 10A charge current limit, you cannot expect more than 500Wh of energy to be fed into the battery (for 48V battery pack) during for one hour charging time slot, so adapt all your values accordingly.
OFF_PEAK_TIME_START="04:00"
OFF_PEAK_TIME_STOP="05:55"
#
# Whether force charging from grid is allowed (optional future functionality)
FORCE_CHARGE="0"
# 
# Weather Forecast settings:
# Location City in which (or within its region) the system is located (ex. Berlin, London, Paris)
# Timezone according to the timezone notation under /usr/share/zoneinfo (ex. 'Europe/Paris'), the full path would be (/usr/share/zoneinfo/Europe/Paris)
# It is highly advised to change the venusos localtime (system localtime, since the GUI have two time zones - UTC and the customer set one). The default system time is UTC
# This is seen as symlink in /etc/localtime. In order to change it remove the current symlink and create a new one pointing to your zimezone under /usr/share/zoneinfo/....
# ex.)
# rm -f /etc/localtime 
# ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
#
#
# The logic is as follows 
# -> if we expect the whole day to be sunny or partly sunny, then then precharge the battery up to the STOP_ON_SOC_GOOD_PV, only if the current SOC is <= STOP_ON_SOC_GOOD_PV.
# -> if the expected weather is not to be sunny enough (not expecting good pv production), then precharge the battery up to the STOP_ON_SOC_BAD_PV, only if the current SOC is <= STOP_ON_SOC_BAD_PV.
# The purpose is to have enough SOC during the early monrning hours when we are still missing PV production or until it is still low in the morning (this is in case of good PV production expectation)
# but at the same time leaving enough room for storage of the the excess PV energey during the day.
# If BAD PV production weather is expected, then we are pre-charging the battery more (up to STOP_ON_SOC_BAD_PV), so we have enough energy stored in the battery (also good in case of power outages).
# The weather forecast service used is wttr.in: https://github.com/chubin/wttr.in
LOCATION_CITY="Sofia"
TIMEZONE="Europe/Sofia"
WEATHER_FORECAST_FILE="/tmp/weather_forecast.txt"
#
#
# Example cron configuration for VenusOS crontab in: /etc/crontab
##################################################################################
# Minute   Hour   Day of Month       Month          Day of Week     user   Command    
# (0-59)  (0-23)     (1-31)    (1-12 or Jan-Dec)  (0-6 or Sun-Sat)                
#   0        2          12             *               0,6          root	 /usr/bin/find 	# This line executes the "find" command at 2AM on the 12th of every month that a Sunday or Saturday falls on.
# 	0 		 * 			* 			   * 				* 			root	 /data/scripts/ess_opticharge/ess_opticharge.sh  # run ess_opticharge.sh every 1 hour     (not practical)
#   */30 	 * 			* 			   * 				*			root	 /data/scripts/ess_opticharge/ess_opticharge.sh  # run ess_opticharge.sh every 30 minutes (not practical)
#   58 		 23 		* 			   * 				* 			root	 /data/scripts/ess_opticharge/ess_opticharge.sh  # run ess_opticharge.sh every day at 23:58 (11:58PM) (good use-case example)
#
# We can use copies of the script with different settings for example for each month throughout the year
#	1 		 0 			* 			   4 				* 		 	root	/data/scripts/ess_opticharge/ess_opticharge_april.sh  # run the custom script every day on April at 00:01 (1:01AM)
#
##################################################################################
# END of Usage help and user defined variables section
##################################################################################
# DO NOT EDIT bellow if you are not sure what you are doing!
##################################################################################
# Functions:
##################################################################################
Get_values() {
# Get ESS current mode
#ESS_CURRENT_MODE="$($(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/State GetValue)"
# Get ESS Minimum SOC (in [%]) unless grid fails current value
ESS_MIN_SOC="$($(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/MinimumSocLimit GetValue | cut -d"." -f1)"

# Get Battery pack current SOC value in [%]
# Check for smart serial battery pack
#DBUS_BATT_PATH="$($(which dbus) -y | egrep -wo "com.victronenergy.battery.tty.*$")"
DBUS_BATT_PATH="$($(which dbus) -y com.victronenergy.system /Dc/Battery/BatteryService GetValue | tr -d "'")"
if [ ! -z "${DBUS_BATT_PATH}" ]; then
	BATT_CURRENT_SOC="$($(which dbus) -y ${DBUS_BATT_PATH} /Soc GetValue | cut -d"." -f1)"
else
	BATT_CURRENT_SOC="$($(which dbus) -y com.victronenergy.system /Dc/Battery/Soc GetValue | cut -d"." -f1)"
fi

# Get the current time and convert it to drift in seconds from midnight (00:00)
CURRENT_TIME="$(TZ=${TIMEZONE} date +%H:%M)"
CURRENT_TIME_SECONDS="$(echo "${CURRENT_TIME}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')"
OFF_PEAK_TIME_START_SECONDS="$(echo "${OFF_PEAK_TIME_START}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')"
OFF_PEAK_TIME_STOP_SECONDS="$(echo "${OFF_PEAK_TIME_STOP}" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')"
SCHED_CHARGE_DURATION="$(( ${OFF_PEAK_TIME_STOP_SECONDS}-${OFF_PEAK_TIME_START_SECONDS} ))"

logger -t ${SCRIPTNAME} -s "Current system battery SOC: ${BATT_CURRENT_SOC}%"
logger -t ${SCRIPTNAME} -s "Current ESS MIN SOC: ${ESS_MIN_SOC}%"
}

Check_values() {
# Check for correct Scheduled Charging ID usage:
#if (( ${SCHED_CHARGE_ID} >= 0 && ${SCHED_CHARGE_ID} <= 4 )); then
if [[ ( "${SCHED_CHARGE_ID}" -lt "0" ) || ( "${SCHED_CHARGE_ID}" -gt "4" ) ]]; then
	# Set the ID to be the latest - Scheduled Charging 5, t.e. ID=4
	SCHED_CHARGE_ID="4"
fi
#
# Checking stop on soc variables for valid values, and correct them if needed
# STOP_ON_SOC_GOOD_PV - valid values between [ESS_MIN_SOC - 90]
if [[ "${STOP_ON_SOC_GOOD_PV}" -lt "${ESS_MIN_SOC}" ]]; then
	STOP_ON_SOC_GOOD_PV="${ESS_MIN_SOC}"
elif [[ "${STOP_ON_SOC_GOOD_PV}" -ge "90" ]]; then
	STOP_ON_SOC_GOOD_PV="90"
fi
# STOP_ON_SOC_BAD_PV - valid values between [ESS_MIN_SOC - 95]
if [[ "${STOP_ON_SOC_BAD_PV}" -lt "${ESS_MIN_SOC}" ]]; then
	STOP_ON_SOC_BAD_PV="${ESS_MIN_SOC}"
elif [[ "${STOP_ON_SOC_BAD_PV}" -ge "95" ]]; then
	STOP_ON_SOC_BAD_PV="95"
fi
}

AC_Input() {
# Checks whether Grid is present
# 1 - grid is present; 240 - Inverting (grid is not present in ESS); 0 - error (configured as not present, while it is)
local AC_INPUT_STATE="$($(which dbus) -y com.victronenergy.system /Ac/ActiveIn/Source GetValue)"
# Returning 1 if Grid is present and 0 if it is NOT present
if [ "${AC_INPUT_STATE}" == "1" ]; then
	return "1"
else 
	return "0"
fi
}

ESS_Set_KeepBattCharged() {
# Change ESS mode to Keep batteries charged unless already set
local CURRENT_MODE="${@}"
# 
if [ "${CURRENT_MODE}" != "9" ]; then
	# Set ESS mode to Keep batteries charged and force charging
	#$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/Hub4Mode SetValue 1
	$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/State SetValue 9  
fi
}

ESS_Set_Optimised_NoBattLife() {
# Change ESS mode to Optimized mode without BatteryLife unless already set
local CURRENT_MODE="${@}"
#
if [[ (( "${CURRENT_MODE}" != "10" ) && ( "${CURRENT_MODE}" != "11" ) && ( "${CURRENT_MODE}" != "12" )) ]]; then
	# Set ESS mode to Optimized mode without BatteryLife
	#$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/Hub4Mode SetValue 1
	$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/State SetValue 10 >&- 2>&-
fi
}

ESS_SchedCharge_trigger() {
# Enable or Disable the predefined id scheduled charge entry
local CMD="${@}"
local SCHED_CHARGE_CURR_STATE="$($(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/${SCHED_CHARGE_ID}/Day GetValue)"
if [ "${CMD}" == "enable" ]; then
	if [ "${SCHED_CHARGE_CURR_STATE}" == "-7" ]; then
		logger -t ${SCRIPTNAME} -s "Enabling ESS Scheduled Charging ID ${SCHED_CHARGE_ID}";
		$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/${SCHED_CHARGE_ID}/Day SetValue 7 >&- 2>&-
	fi
fi
if [ "${CMD}" == "disable" ]; then
	if [ "${SCHED_CHARGE_CURR_STATE}" == "7" ]; then
		logger -t ${SCRIPTNAME} -s "Disabling ESS Scheduled Charging ID ${SCHED_CHARGE_ID}";
		$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/${SCHED_CHARGE_ID}/Day SetDefault >&- 2>&-
	else
		logger -t ${SCRIPTNAME} -s "No change in ESS Scheduled Charging ID ${SCHED_CHARGE_ID} mode, left to disabled";
	fi
fi
}

ESS_SchedCharge_config() {
# Configure the scheduled charge entry (defined in SCHED_CHARGE_ID) in the ESS menu according to the script logic
# Set the Stop on SOC value for the scheduled charge entry:
$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/${SCHED_CHARGE_ID}/Soc SetValue -- ${STOP_ON_SOC} >&- 2>&-
# Set the start time of the scheduled charge time slot:
$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/${SCHED_CHARGE_ID}/Start SetValue -- ${OFF_PEAK_TIME_START_SECONDS} >&- 2>&-
# Set the duration of the scheduled charge time slot:
$(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/${SCHED_CHARGE_ID}/Duration SetValue -- ${SCHED_CHARGE_DURATION} >&- 2>&-
}

Get_Weather_Forecast() {
# This function will set the STOP_ON_SOC variable according to the weather forecast for the incoming day
#
# Initiate a dns lookup
nslookup wttr.in >&- 2>&-; sleep 1;
ping -q -c 2 wttr.in >&- 2>&-; sleep 1;
#
# Take the weather forecast for the next day
$(which curl) -fGsS "wttr.in/${LOCATION_CITY}?lang=us&m&2&q&F&T" > ${WEATHER_FORECAST_FILE}; sleep 1;
TOMORROW_MORNING_STATE=$($(which cat) ${WEATHER_FORECAST_FILE} | tail -n 6 | head -n 1 | awk -F'│' '{ print $2 }' | egrep -o "([[:alpha:]]{1,}[ ]{0,}){1,}")
TOMORROW_NOON_STATE=$($(which cat)    ${WEATHER_FORECAST_FILE} | tail -n 6 | head -n 1 | awk -F'│' '{ print $3 }' | egrep -o "([[:alpha:]]{1,}[ ]{0,}){1,}")
# Looking for "Sunny" OR "Partly sunny"
#if [[ ( "${TOMORROW_MORNING_STATE}" == "Sunny" || "${TOMORROW_MORNING_STATE}" == "Partly sunny" ) && ( "${TOMORROW_NOON_STATE}" == "Sunny" || "${TOMORROW_NOON_STATE}" == "Partly sunny" ) ]]; then
if [[ ( "$(echo ${TOMORROW_MORNING_STATE})" == "Sunny" || "$(echo ${TOMORROW_MORNING_STATE})" == "Partly sunny" ) && ( "$(echo ${TOMORROW_NOON_STATE})" == "Sunny" || "$(echo ${TOMORROW_NOON_STATE})" == "Partly sunny" ) ]]; then
	# Expecting sunny day, no need to sched charge
	logger -t ${SCRIPTNAME} -s "Good PV production weather is expected"
	STOP_ON_SOC="${STOP_ON_SOC_GOOD_PV}"
else
	logger -t ${SCRIPTNAME} -s "Bad PV production weather is expected"
	STOP_ON_SOC="${STOP_ON_SOC_BAD_PV}"
fi
logger -t ${SCRIPTNAME} -s "Precharge (Stop on SOC) value: ${STOP_ON_SOC}%"
}

##################################################################################
# MAIN
##################################################################################
# Get ESS current mode
ESS_CURRENT_MODE="$($(which dbus) -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/State GetValue)"
# Get system mode
SYSTEM_TYPE="$($(which dbus) -y com.victronenergy.system /SystemType GetValue | tr -d "'")"
#
# Exit if ESS is running and whether the ESS mode is Optimized mode without BatteryLife OR Keep batteries charged
if [[ (( "${ESS_CURRENT_MODE}" == "9" ) || ( "${ESS_CURRENT_MODE}" == "10" ) || ( "${ESS_CURRENT_MODE}" == "11" ) || ( "${ESS_CURRENT_MODE}" == "12" )) && ( "${SYSTEM_TYPE}" == "ESS" ) ]]; then
	# States that we consider as valid means:
	# Keep batteries charged mode:
	# 9: 'Keep batteries charged' mode enabled
	# Optimized mode without BatteryLife:
	# 10: Self consumption, SoC at or above minimum SoC
	# 11: Self consumption, SoC is below minimum SoC
	# 12: Recharge, SOC dropped 5% or more below minimum SoC
	# If none of them is present and the system is not ESS, we are exiting!
	logger -t ${SCRIPTNAME} -s "Starting ${SCRIPTNAME}, with current ESS mode = ${ESS_CURRENT_MODE}"
else
	logger -t ${SCRIPTNAME} -s "ESS mode not supported, exiting..."
	exit 1
fi
# Get the needed values like: ESS_MIN_SOC, BATT_CURRENT_SOC, etc.
Get_values
# Check whther the values and variables are correct and if not, fix them if possible
Check_values
# Get the weather forecast for the incoming day and decide whether and how to pre-charge:
Get_Weather_Forecast
# Decide whether to precharge. This will happen when the Battery current SOC is <= STOP on SOC value defined depending on the weather forecast
if [ "${BATT_CURRENT_SOC}" -le "${STOP_ON_SOC}" ]; then
	# Precharge is needed, so enabling the scheduled charging
	ESS_SchedCharge_config
	ESS_SchedCharge_trigger enable
	logger -t ${SCRIPTNAME} -s "Setting ESS Scheduled Charging ID ${SCHED_CHARGE_ID} with the following configuration"
	logger -t ${SCRIPTNAME} -s "Time slot: ${OFF_PEAK_TIME_START} - ${OFF_PEAK_TIME_STOP} local time (${TIMEZONE}), Duration: ${SCHED_CHARGE_DURATION} seconds"
	logger -t ${SCRIPTNAME} -s "Stop charging when reaching ${STOP_ON_SOC}% SOC, NO discharge is allowed during this period"
	SCHED_CHARGE_FLAG="1"  # future use
else
	# No need to precharge the battery, disable scheduled charging if it has been previously enabled
	ESS_SchedCharge_trigger disable
fi

logger -t ${SCRIPTNAME} -s "Execution completed successfully"

exit 0
