#!/usr/bin/env python3

import serial
import time, json

DATA_PATH = "/srv/http"
NSAMPLES = 128

try:
    port = serial.Serial("/dev/ttyAMA0", baudrate=115000, timeout=3.0)
except serial.SerialException as e:
    print("could not open serial port '{}': {}".format(com_port, e))

port.xonxoff = False

port.write('\rAQUIRE\r\n'.encode('ascii'))

rcv = port.readline()
line = rcv.decode('ascii')
voltages = []
while "ADC_VOLTAGES" not in line:
    line = port.readline().decode('ascii')
for i in range(NSAMPLES):
    voltages.append(port.readline().decode('ascii')[0:-2])
currents = []

while "ADC_CURRENTS" not in line:
    line = port.readline().decode('ascii')
for i in range(NSAMPLES):
    currents.append(port.readline().decode('ascii')[0:-2])

while "voltage_rms" not in line:
    line = port.readline().decode('ascii')

voltage_rms = float(line[12:])

while "current_rms" not in line:
    line = port.readline().decode('ascii')

current_rms = float(line[12:])

output_file = open(DATA_PATH + '/sensor_data.json', 'w+')
output_file.write(json.dumps({"voltage": voltages, "current": currents, "voltage_rms": voltage_rms, "current_rms": current_rms, "date": time.asctime()}, indent=4))
output_file.close()

power_fd = open(DATA_PATH + "/rms_values.csv", 'a+')
power_fd.write(str(voltage_rms) + ", " + str(current_rms) + "\n")
power_fd.close()

