#!/usr/bin/python -E

from __future__ import print_function

import sys

lineNo = 0
current = None
body = None
macros = {}

def err(text, lineNum):
    print('#', lineNum, ' ', text, sep='', file=sys.stderr)
    exit(1)

for line in sys.stdin:
    lineNo += 1
    line = line.lstrip()
    
    if line.startswith('//{{ '):
        name = line[5:].strip()
        if current:
            err(' '.join('starting template', name, 'while', current, 'is active'))
        else:
            current = name
            body = ''
    elif line.startswith('//}}'):
        if not current:
            err('template end without begin')
        else:
            macros[current] = body
            current = None
    else:
        if line.startswith('//== '):
            name, _, tail = line[5:].partition(' ')
            if name not in macros:
                err(' '.join('template', name, 'not defined'))
            body = macros[name]
            args = map(str.strip, tail.split(','))
            for arg in args:
                key, value = map(str.strip, arg.split('='))
                body = body.replace(key, value)
                line = body        

        if current:
            body += line
        else:
            print(line,end='')
