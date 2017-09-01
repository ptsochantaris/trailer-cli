#!/bin/sh
echo "*** Cleaning"
swift package reset
echo "*** Building"
swift build -c release --static-swift-stdlib
if [ $? -eq 0 ]; then
	SRC="$(swift build -c release --show-bin-path)/trailer"
	echo "*** Installing 'trailer' to /usr/local/bin, please enter your sudo password if needed"
	sudo install $SRC /usr/local/bin/trailer
	echo "*** Done"
else
	echo
	echo "*** Build failed, ensure you are using Swift 4.x on the command line"
fi
