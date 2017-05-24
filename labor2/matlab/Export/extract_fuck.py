time = list()
voltage = list()
rpm = list()
for line in open('export_20170503111058125.csv'):
    t, r, d, d, v = line.split(',')[:5]
    time.append(t)
    voltage.append(v)
    rpm.append(r)

with open('out.txt', 'w') as f:
    f.write('time = [{}]'.format(', '.join(str(x) for x in time)) + ';\n')
    f.write('voltage = [{}]'.format(', '.join(str(x) for x in voltage)) + ';\n')
    f.write('rpm = [{}]'.format(', '.join(str(x) for x in rpm)) + ';\n')

	
