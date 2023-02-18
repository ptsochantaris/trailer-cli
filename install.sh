#!/bin/sh

echo "*** Cleaning"
swift package reset

echo "*** Building"
if [ "$(uname)" == "Darwin" ]; then
	swift build -c release --arch arm64 --arch x86_64 -Xswiftc -O -Xswiftc -Ounchecked -Xswiftc -whole-module-optimization -Xswiftc -enforce-exclusivity=unchecked
	SRC="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/trailer"
else
	swift build -c release                            -Xswiftc -O -Xswiftc -Ounchecked -Xswiftc -whole-module-optimization -Xswiftc -enforce-exclusivity=unchecked
	SRC="$(swift build -c release --show-bin-path)/trailer"
fi

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
	echo "*** Build failed, ensure you are using Swift 5.x on the command line"
fi
