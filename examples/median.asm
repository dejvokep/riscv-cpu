# uses  a0 = pointer to the currently processed element
#       a3 = size of the array,
#       a4 = local use, just for comparison
lw a3, 4(x0) # size
lw a0, 8(x0) # pointer

addi a4, x0, 3
blt a3, a4, done # less than 3 elements

addi a0, a0, 4 # to the 2nd element
addi a3, a3, -2 # reduce

for:
  beq a3, x0, done
  jal x1, median
  sw a1, 0(a0)
  addi a3, a3, -1
  addi a0, a0, 4
  beq x0, x0, for

done:
  beq x0, x0, done

median: # a0 - pointer, a1 - median, x1 - jal, uses t0,t1,t2
  lw t0, -4(a0)
  lw t1, 0(a0)
  lw t2, 4(a0)
  
  blt t0, t1, m1
  # HERE: t0 >= t1
  blt t2, t0, m2
  # HERE: t0 >= t1 AND t2 >= t0
  beq x0, x0, median_t0
  

m1: # t0 < t1
  blt t2, t0, median_t0
  # HERE: t0 < t1 AND t2 >= t0 (t0 is the smallest)
  blt t1, t2, median_t1
  # HERE: t1 >= t2
  beq x0, x0, median_t2

m2: # t0 >= t1 AND t2 < t0 (t0 is the greatest)
  blt t1, t2, median_t2
  # HERE: t1 >= t2
  beq x0, x0, median_t1

median_t0:
  addi a1, t0, 0
  jalr x0, 0(x1)
median_t1:
  addi a1, t1, 0
  jalr x0, 0(x1)
median_t2:
  addi a1, t2, 0
  jalr x0, 0(x1)