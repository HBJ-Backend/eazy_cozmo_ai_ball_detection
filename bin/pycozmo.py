#!/usr/bin/python3
import os
import sys
import string
import subprocess



if __name__ == "__main__":
    f = open(sys.argv[1])
    mypath=os.path.dirname(__file__)
    f2 = open("{path}/script_template.py".format(path=mypath))
    f3 = open("{path}/tmp.py".format(path=mypath), 'w')
    for line2 in f2.readlines():
        if 'CODE' in line2:
            for line in f.readlines():
                linetmp = line2.replace('CODE', line,1)
                f3.write(linetmp)
        else:
            f3.write(line2)
    f3.close()
    # sys.executable, not "python": a bare "python" gets looked up on PATH and
    # can land on a different install that has none of the dependencies.
    subprocess.call([sys.executable, "{path}/reindent.py".format(path=mypath),
                     "{path}/tmp.py".format(path=mypath)])
    subprocess.call([sys.executable, "{path}/tmp.py".format(path=mypath)])
