#!/bin/bash
for f in `echo "list volume" | bconsole | cut -d ' ' -f6`; do 
	echo "delete volume=Vol-$f yes" | bconsole;
	rm -rf /mnt/bacula/default/$f;
done
