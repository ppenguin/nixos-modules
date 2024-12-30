#!/usr/bin/env python3

# Adapted from https://github.com/pimlie/geekworm-x-c1/blob/main/fan-rpi.py

import RPi.GPIO as IO
import time

pin_fan = 18

IO.setwarnings(False)
IO.setmode(IO.BCM)
IO.setup(pin_fan, IO.OUT)
fan = IO.PWM(pin_fan, 2000)
fan.start(0)


def get_temp():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as file:
            return float(file.read()) / 1000.0
    except (IndexError, ValueError):
        raise RuntimeError("Could not get temperature")


while 1:
    temp = get_temp()  # Get the current CPU temperature
    if temp > 70:  # Check temperature threshhold, in degrees celcius
        fan.ChangeDutyCycle(
            100
        )  # Set fan duty based on temperature, 100 is max speed and 0 is min speed or off.
    elif temp > 60:
        fan.ChangeDutyCycle(85)
    elif temp > 50:
        fan.ChangeDutyCycle(50)
    elif temp > 40:
        fan.ChangeDutyCycle(40)
    elif temp > 32:
        fan.ChangeDutyCycle(30)
    elif temp > 25:
        fan.ChangeDutyCycle(25)
    else:
        fan.ChangeDutyCycle(0)
    time.sleep(5)  # Sleep for 5 seconds
