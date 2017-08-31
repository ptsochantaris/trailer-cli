# Command-line Trailer
Copyright (c) 2017 Paul Tsochantaris. Released under the terms of the MIT licence, see the file LICENCE for details.

## Warning: Work In Progress
This source is very much a work-in-progress at the moment. There is almost no documentation, and you should expect weirdness, force-pushes, code to break, and no release binaries.

This will change quite soon but, for the moment, please do not rely on this code for anything apart from experimenting.

## What is it?
A version of [Trailer](https://github.com/ptsochantaris/trailer) that runs in macOS & Linux command-line, can integrate into scripts, be used on remote servers, or simply used because consoles are cool. This version does not aim for feature parity with the mainstream Trailer project although it shared the common ideas and concepts.

## Building & Installing
**Note: Requires Swift 4.x.** Use the simple *(and perhaps not suitable for all setups)* script `install.sh`  to place a built binary in /usr/local/bin, or you can manually build the project by entering `swift build -c release --static-swift-stdlib` and move the binary from the `.build` subdirectory to wherever you like.

## Usage
Run Trailer without any arguments for some help text.
In short, to use Trailer you need to (a) create and specify an API access token for the GitHub API, and (b) regularly update your local data cache to keep things current (and get notifications of activity, etc)

Quickstart (to be expanded):
```
./trailer -token <API access token>
./trailer update all
```

If all goes well, you can then use the `./trailer list` command or `./trailer show` command to browse and view items, as well as the `./trailer config` command to restrict PRs/Issues to specific repositories and reduce clutter, noise, and API usage when updating.
