To test the RTC ds1307 on the Raspberry Pi 2 run the following commands:

 - Check if the RTC is detected on the i2c bus:
```
# i2cdetect -y 1
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- -- 
70: -- -- -- -- -- -- -- --
```
 - Setup RTC as an hwclock:
```
echo "ds1307 0x68" > /sys/class/i2c-adapter/i2c-1/new_device
```
 - Sync local time to RTC, `$ hwclock -s`
 - Check if dates are correct:
```
$ timedatectl
      Local time: Wed 2015-12-09 03:09:37 UTC
  Universal time: Wed 2015-12-09 03:09:37 UTC
        RTC time: Wed 2015-12-09 03:09:37
       Time zone: UTC (UTC, +0000)
 Network time on: yes
NTP synchronized: no
 RTC in local TZ: no
```

 - To detect the RTC on boot paste this in `/etc/udev/rules.d/99-i2c-rtc.rules`
```
ACTION=="add", SUBSYSTEM=="i2c", ATTR{name}=="<contents of file /sys/class/i2c-adapter/i2c-1/name>", ATTR{new_device}="ds1307 0x68"
```
