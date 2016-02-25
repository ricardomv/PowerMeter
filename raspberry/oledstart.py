#!/usr/bin/env python

from oled.device import ssd1306, const
from oled.render import canvas
from PIL import ImageDraw, ImageFont
from datetime import datetime
import psutil
import time, sys, socket
import signal, json

device = ssd1306(port=1, address=0x3C)

def signal_handler(signal, frame):
    device.command(const.DISPLAYOFF)
    sys.exit(0)

signal.signal(signal.SIGTERM, signal_handler)

local_ip = socket.gethostbyname(socket.gethostname())


roboto = ImageFont.truetype('Roboto-Regular.ttf', 14)
large = ImageFont.truetype('DejaVuSans.ttf', 19)
frames = 0
while True:
    frames += 1
    with canvas(device) as draw:
        draw.text((0, 0), socket.gethostbyname("alarmpi") + "    " + str(frames), font=roboto, fill=1)
        data_fd = open("/srv/http/sensor_data.json", "r+")
        data = json.load(data_fd)
        draw.text((0, 17),"V=" + str(data["voltage_rms"]), font=large, fill=1)
        draw.text((0, 37),"I=" + str(data["current_rms"]), font=large, fill=1)
        
        #percent = psutil.cpu_percent(interval=1)
        #draw.rectangle((0, 20, 10, 63), outline=255, fill=0)
        #draw.rectangle((0, 63-int(percent*0.44), 10, 63), outline=255, fill=1)
        time.sleep(10)
