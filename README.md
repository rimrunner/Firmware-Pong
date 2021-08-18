# Firmware-Pong
ARM64 Assembly exercise

While not having any good ideas, I started to write a Pong game as an ARM64 exercise. It is supposed to run on Raspberry Pi 3 without kernel, using only firmware (this is often called "baremetal" which is misleading). However, I never managed to boot it on an actual RPi3 (the program was developed with QEMU running on RPi4) so I couldn't start to develop controls for the game (which would have required buttons used via GPIO). So if Pong itself is boring, this is yet ten times more boring. Also proper testing and adjustment of FPS speed couldn't be done and some ball algorithms may remain awkward.

But as an ARM64 Assembly exercise this project served its purpose. The use of bitwise operations, floats and vector registers added to the diversity of the code. The game draws the ball and walls as a bitmap and operates on it. Boilerplate parts are largely based on "baremetal tutorials" by bzt and others, translated from C to assembly by hand.
