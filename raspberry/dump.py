#!/usr/bin/env python3

import serial

try:
    port = serial.Serial("/dev/ttyAMA0", baudrate=115200, timeout=3.0, xonxoff = False)
except serial.SerialException as e:
    print("could not open serial port '{}': {}".format(com_port, e))

port.write('\rAQUIRE\r\n'.encode('ascii'))

while True:
    rcv = port.readline()
    if not rcv:
    	break
    print(rcv.decode('ascii')[:-1])
