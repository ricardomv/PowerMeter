#!/usr/bin/env python

from oled.device import ssd1306, const
from oled.render import canvas
from PIL import ImageDraw, ImageFont
from datetime import datetime
import psutil
import time, sys
import signal

device = ssd1306(port=1, address=0x3C)

def signal_handler(signal, frame):
    device.command(const.DISPLAYOFF)
    sys.exit(0)

signal.signal(signal.SIGTERM, signal_handler)

while True:
    with canvas(device) as draw:
        font = ImageFont.truetype('Roboto-Regular.ttf', 14)
        now = datetime.now()
        draw.text((0, 0), now.strftime("%A"), font=font, fill=1)
        draw.text((0, 17), now.strftime("%d %b %Y"), font=font, fill=1)
        font = ImageFont.truetype('DejaVuSans.ttf', 29)
        draw.text((0, 34), now.strftime("%H:%M:%S"), font=font, fill=1)
        
        #percent = psutil.cpu_percent(interval=1)
        #draw.rectangle((0, 20, 10, 63), outline=255, fill=0)
        #draw.rectangle((0, 63-int(percent*0.44), 10, 63), outline=255, fill=1)
        time.sleep(0.1)
