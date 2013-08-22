Requirements:

Edit the uEnv.txt of the beaglebone to be
`optargs=quiet capemgr.disable_partno=BB-BONELT-HDMI,BB-BONELT-HDMIN`
Since the HDMI framer interferes with pins this code requires, and since trying to remove
it at runtime causes bad things to happen.

Build the device tree fragment using `make dts`.
Place the resulting binary in /lib/firmware, and then one can load it by invoking:
`echo cape-jtag-pru > /sys/devices/bone_capemgr.9/slots`

Probably no other specific steps needed to get this working.
Just run `make` in the parent directory and find the binary in ../bin
(note you must execute from the bin directory, since the program is searching
for the *.bin file in whatever diretory you execute from.
