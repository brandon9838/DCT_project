import numpy as np
import random

open('random.txt', 'w').close()

f = open("random.txt", "a")

for i in range(128):
  f.writelines('{0:08b}'.format(random.randint(0, 255)))
  if i!=127:
    f.writelines('\n')
  
f.close()
