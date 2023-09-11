#!/usr/bin/env python3

from sys import stdin

# prints the integer value of the sum of numbers on stdin

def getLines():
  lines=[]
  for line in stdin:
    lines.append(float(line.strip()))

  return lines

def main():
  lines = getLines()
  #print('{}'.format(int(sum(lines))))
  print('{}'.format(sum(lines)))

if __name__ == '__main__':
  main()

