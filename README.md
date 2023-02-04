# ess_opticharge
VenusOS scheduled charge automation script used to interact with Victron Energy system

Intended to be run by cron on a predefined time (not running as a process)
This script will process ONLY if the ESS mode is set to Optimized mode without BatteryLife or to Keep batteries charged.

Inline script comments in the variables section act as a help guidance and use-case examples. Please, read them carefully.
You can alter them according to yout own needs.


Here is a real case result doing a battery pre-charge between 04:30 - 05:50. In this case the charge current has been set to 10A.

![Battery_SOC_precharge_offpeak_before_PV_start_AC_input](https://user-images.githubusercontent.com/16059420/216772655-13a97026-dcbf-4ae9-8631-ab109e076152.png)
![Battery_SOC_precharge_offpeak_before_PV_start_whole_day_cycle](https://user-images.githubusercontent.com/16059420/216772658-2d77a2b8-593f-4d85-aba1-012999a40124.png)

Installation hints:
Clone the script either locally on your PC or directly on your GX device. If downloaded locally on a PC you will need to upload the script file to your GX, either with scp or a usd flash drive or an alternative method.

Bellow example is for GX device.
Login to your GX device with SSH and issue:
```
mkdir /data/scripts/
git clone https://github.com/dir2cas/ess_opticharge.git
cd ess_opticharge
chmod +x ess_opticharge.sh
```
Sample outputs:
```
[root@gx:~]# /data/scripts/ess_opticharge/ess_opticharge.sh 
/data/scripts/ess_opticharge/ess_opticharge.sh: Starting /data/scripts/ess_opticharge/ess_opticharge.sh, with current ESS mode = 10
/data/scripts/ess_opticharge/ess_opticharge.sh: Current system battery SOC: 85%
/data/scripts/ess_opticharge/ess_opticharge.sh: Current ESS MIN SOC: 50%
/data/scripts/ess_opticharge/ess_opticharge.sh: Precharge (Stop on SOC) value: 75%
/data/scripts/ess_opticharge/ess_opticharge.sh: No change in ESS Scheduled Charging ID 4 mode, left to disabled
/data/scripts/ess_opticharge/ess_opticharge.sh: Execution completed successfully
```
Another example usage, this time the ESS scheduled charge is altered. 
```
[root@gx:~]# /data/scripts/ess_opticharge/ess_opticharge.sh
/data/scripts/ess_opticharge/ess_opticharge.sh: Starting /data/scripts/ess_opticharge/ess_opticharge.sh, with current ESS mode = 10
/data/scripts/ess_opticharge/ess_opticharge.sh: Current system battery SOC: 55%
/data/scripts/ess_opticharge/ess_opticharge.sh: Current ESS MIN SOC: 50%
/data/scripts/ess_opticharge/ess_opticharge.sh: Bad PV production weather is expected
/data/scripts/ess_opticharge/ess_opticharge.sh: Precharge (Stop on SOC) value: 75%
/data/scripts/ess_opticharge/ess_opticharge.sh: Setting ESS Scheduled Charging ID 4 with the following configuration
/data/scripts/ess_opticharge/ess_opticharge.sh: Time slot: 04:00 - 05:55 local time (Europe/Sofia), Duration: 6900 seconds
/data/scripts/ess_opticharge/ess_opticharge.sh: Stop charging when reaching 75% SOC, NO discharge is allowed during this period
/data/scripts/ess_opticharge/ess_opticharge.sh: Execution completed successfully
```
