#!/usr/bin/env python3

import serial
import time

try:
    port = serial.Serial("/dev/ttyAMA0", baudrate=9600, timeout=3.0)
except serial.SerialException as e:
    print("could not open serial port '{}': {}".format(com_port, e))

while True:
    port.write('DEBUG\r\n'.encode('ascii'))
    rcv = port.readline()
    print("Recieved: " + rcv.decode('ascii'))
