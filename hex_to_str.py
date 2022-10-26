#!/bin/env python

import fileinput
import re
import binascii

for line in fileinput.input(inplace = 1):
    if re.search('X\'([a-fA-F0-9]+)\'', line) is not None:
        unhexed_string = binascii.unhexlify(re.search('X\'([a-fA-F0-9]+)\'', line).group(1)).decode("UTF-8")
        unhexed_string = unhexed_string.replace("'", "''")
        line = line.replace(re.search('X\'([a-fA-F0-9]+)\'', line).group(1),unhexed_string)
        print(line)
    else:
        print(line)

for line in fileinput.input(inplace = 1):
    if re.search(',X\'', line) is not None:
        print(line.replace(re.search(',X\'', line).group(0),',\''))
    else:
        print(line)
