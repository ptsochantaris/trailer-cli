#!/bin/sh

echo "*** Cleaning"
swift package reset

echo "*** Building"
swift build -c release \
    -Xswiftc -O \
    -Xswiftc -Ounchecked \
    -Xswiftc -whole-module-optimization

SRC="$(swift build -c release --show-bin-path)/trailer"

if [ $? -eq 0 ]; then
	echo "*** Stripping symbols"
	strip $SRC
	echo "*** Installing 'trailer' to /usr/local/bin, please enter your sudo password if needed"
	sudo install $SRC /usr/local/bin/trailer
	echo "*** Cleaning Up"
	swift package reset
	echo "*** Done"
else
	echo
	echo "*** Build failed, ensure you are using Swift 6.4 or later on the command line"
fi
