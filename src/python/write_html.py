#!/usr/bin/env python
"""
Write output HTML file from list of images and text 

@author Neva Durand (c) 2021
"""
import argparse
import base64
import io
import os.path

def main(image_file_list, log_file_list):
    with open(image_file_list) as fname:
        images = fname.read().splitlines() 
    html = '<br>'
    for image in images:
        data = open(image, 'rb').read() # read bytes from file
        data_base64 = base64.b64encode(data)  # encode to base64 (bytes)
        data_base64 = data_base64.decode('utf-8')    # convert bytes to string
        html = html + '<img src="data:image/png;base64,' + data_base64 + '"><br>' # embed in html
    f = io.open('output.html', 'a+', encoding='utf8')
    f.write(html)

    f.write('<pre>')
    with open(log_file_list) as fname:
        logs = fname.read().splitlines()
    for log in logs:
        f.write('<h3>')
        f.write(os.path.basename(log))
        f.write('</h3>')
        f.write('<pre>')
        with io.open(log, 'r', encoding='utf8') as f1:
           text = f1.read()
        f.write(text)
        f.write('</pre>')
    f.write('</body></html>')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=__doc__.split('\n\n\n')[0])
    group = parser.add_argument_group()
    group.add_argument('image_file_list', 
                       help='file containing list of image files to paste in HTML file')
    group.add_argument('log_file_list',
                       help='file containing list of text log files to append to end of HTML file')
    args = parser.parse_args()
    main(args.image_file_list, args.log_file_list)

