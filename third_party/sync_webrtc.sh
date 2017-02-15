#!/bin/bash -x

if [ $# -eq 0 ] ; then
	echo "Error: This script should be run with only 1 parameter which is webrtc revision/tag."
	echo "Do not use this script for development."
	exit
else 
	cd webrtc
	gclient sync -r $1
	echo "gclient sync -r $1"
fi

