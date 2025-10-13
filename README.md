# OSS_Apps
The OSS Applications for app1 (Main application) and app0 (Essential Configuration)

Rev-K pcb hardware features an io-expander at i2c address 0x44.
This code changes gpio ports to adjust the voltage of that converter
The default voltage is 5v and it can be raised to 12v or 24v.
The hardware method of this is by activating the gates of a couple mosfets.
These mosfets lower the resistance of a feedback path to the regulator.

Also the io expander can turn on or off the VMOD converter, but backwards compatibility is preserved.
-David Pottinger
