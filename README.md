# Command-line Trailer
Copyright (c) 2017 Paul Tsochantaris. Released under the terms of the MIT licence, see the file LICENCE for details.

## Warning: Work In Progress
This source is very much a work-in-progress at the moment. There is almost no documentation, and you should expect weirdness, force-pushes, code to break, and no release binaries.

This will change quite soon but, for the moment, please do not rely on this code for anything apart from experimenting.

## What is it?
A version of [Trailer](http://ptsochantaris.github.io/trailer/) that runs on the macOS & Linux command-line, can integrate into scripts, be used on remote servers, or simply used because consoles are cool. This version does not aim for feature parity with the mainstream Trailer project although it shares common ideas and concepts.

## What's different from GUI Trailer?
- The GUI version's main objective is to give you a current view at a glance. This tool is better suited to fetching and displaying itemised lists of what's new, what's been commented, what's been reviewed, and so on, since the last sync. GUI Trailer is "glance at what's happening". CLI Trailer is "list what's changed since I last checked".
- Trailer-CLI can display a full detail view of PRs and Issues, including full bodies of the item, as well as its reviews and comments, with their associated reactions, just like the list you get on a PR or Issue GitHub page. Ideal for archiving PRs or Issues.
- It stores data in JSON files instead of a database. This way it can act like a sync-only engine for other projects that can read the simple JSON format from `~/.trailer` - and use the info in whatever way they like.
- It can run on Linux as well as macOS (and hopefully under Windows when Swift 4.0 shows up there).
- It can be used remotely via SSH, or in command-line scripts.
- It uses the new GitHub GraphQL-based v4 API, making syncs very quick. Additionally it allows trimming down both the data that is synced (for instance, skipping comments or issues for a certain sync)
- It's *way* geekier.

## Building & Installing
**Note: Requires Swift 4.x.** Use the simple *(and perhaps not suitable for all setups)* script `install.sh` to place a built binary in /usr/local/bin, or you can manually build the project by entering `swift build -c release --static-swift-stdlib` and move the binary from the `.build` subdirectory to wherever you like.

## Usage
Run Trailer without any arguments for some help text. To get started:

- Create an API access token from the GitHub API (from [here](https://github.com/settings/tokens)). The token you create on GitHub should contain all the `repo` permissions as well as the `read:org` permission. Tell Trailer about it:

```
trailer -token <API access token>
```

- Update your local data cache anytime to get notifications of activity, etc.

```
trailer update all -v
```

- Don't overdo it though, especially if you watch or are a member of many repos, as the API is quite strict on rate limits and may temporarily block you if you update too often.
- If all goes well, you can then use the `trailer list` command or `trailer show` command to browse and view items, as well as the `trailer config` command to restrict PRs/Issues to specific repositories and reduce clutter, noise, and API usage when updating.
- See below for some examples of common commands.

## Examples

```
trailer 
```
Get help on the available commands and filters. Highly recommended. You can type `help` after each command, such as `trailer list help` to get more info about that command.

```
trailer update all
```
Update the local data from the server. `-v` will give more info, or `-V` will provide *very* verbose debug output on the queries performed.

```
trailer list items -r swift -a bob
```
List all items in repositories containing the letters "swift" and authored by users whose GitHub handle contains the letters "bob"

```
trailer show issue 5 -body -comments
```
Show issue #5. If there are more than one issues with the number #5 in different repositories, trailer will list them. You can then narrow the search down using `-r` or `-a` to specify which repo or author's issue you want to examine. The `-body` command will cause the Issue's main text to be displayed in addition to its details. The `-comments` command will also verbosely display all the comments/reviews in that issue.

## Multiple Servers

```
trailer -s local.server.my.net -token <enterprise token>
trailer -s local.server.my.net update
trailer -s local.server.my.net list items
```

The `-s` command switches the context of trailer to another server. For instance, a local GitHub Enterprise server. All commands work identically, but will apply to this context. You can have as many parallel `-s` contexts as you like.