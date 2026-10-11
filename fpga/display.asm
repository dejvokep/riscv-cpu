# mapped IO: sw0:   least significant bit at 0x0
#            sseg:  least significant 7 bits at 0x4, format ...gfedcba (1 == off, 0 == on)

start:
lw t0, 0(x0) 		# load the switch value
beq t0, x0, one 	# sw0 is zero => logical 1 (pullup)

addi t0, x0, 64 	# encode zero (only G off => 1000000)
beq x0, x0, apply

one:
addi t0, x0, 121	# encode one (ADEFG off => 1111001)

apply:
sw t0, 4(x0)		# store sseg control bits
beq x0, x0, start