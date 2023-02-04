# ess_opticharge
VenusOS scheduled charge automation script used to interact with Victron Energy system

Intended to be run by cron on a predefined time (not running as a process)
This script will process ONLY if the ESS mode is set to Optimized mode without BatteryLife or to Keep batteries charged.

Inline script comments in the variables section act as a help guidance and use-case examples.
You can alter them according to yout own needs.


Here is a real case result.

![Battery_SOC_precharge_offpeak_before_PV_start_AC_input](https://user-images.githubusercontent.com/16059420/216772655-13a97026-dcbf-4ae9-8631-ab109e076152.png)
![Battery_SOC_precharge_offpeak_before_PV_start_whole_day_cycle](https://user-images.githubusercontent.com/16059420/216772658-2d77a2b8-593f-4d85-aba1-012999a40124.png)
