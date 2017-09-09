# Command-line Trailer

A version of [Trailer](http://ptsochantaris.github.io/trailer/) that runs on the macOS & Linux command-line, can integrate into scripts, be used on remote servers, or simply used because consoles are cool. This version does not aim for feature parity with the mainstream Trailer project although it shares common ideas and concepts.

## What's different from GUI Trailer?
- The GUI version's main objective is to give you a current view at a glance. This tool is better suited to fetching and displaying itemised lists of what's new, what's been commented, what's been reviewed, and so on, since the last sync. GUI Trailer is "glance at what's happening". CLI Trailer is "list what's changed since I last checked".
- Trailer-CLI can display a full detail view of PRs and Issues, including full bodies of the item, as well as its reviews and comments, with their associated reactions, just like the list you get on a PR or Issue GitHub page. Ideal for archiving PRs or Issues.
- It stores data in JSON files instead of a database. This way it can act like a sync-only engine for other projects that can read the simple JSON format from `~/.trailer` - and use the info in whatever way they like.
- It can run on Linux as well as macOS (and hopefully under Windows when Swift 4.0 shows up there).
- It can be used remotely via SSH, or in command-line scripts.
- It uses the new GitHub GraphQL-based v4 API, making syncs very quick. Additionally it allows trimming down both the data that is synced (for instance, skipping comments or issues for a certain sync)
- It's *way* geekier.

## Warning: Work In Progress
Trailer-CLI is quite useable, but it is also new and code/features may be in flux for a while, and may contain potential bugs.

Please refer to the "cookbook" section below for an introduction to its features. There are no binaries (yet) but the project can be easily built on the command line on macOS (see right below).

## Building & Installing
**Note: Requires Swift 4.x.** Use the simple *(and perhaps not suitable for all setups)* script `install.sh` to place a built binary in /usr/local/bin, or you can manually build the project by entering `swift build -c release --static-swift-stdlib` and move the binary from the `.build` subdirectory to wherever you like.

## Quickstart
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

## Cookbook

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
trailer list items -mine -participated -mentioned
```
List items that are either `mine` (items created or assigned to me), `participated` (i.e. commented on by me) or items where I've been `mentioned` (either in the body or reviews/comments). You can combine these options like above, or use each one by itself. Or for instance, add `-r reponame` to limit this query to repositories whose names match `reponame`, or use `-t` to filter for a certain title, `-a` for an author, and so forth. Check the `help` option for a full list of options.

```
trailer list issues -c "needs update"
```
List only issues that have comments (or reviews) which include the next "needs update". Also, you can use the `-b` option to search for items whose body includes this text instead.

```
trailer list prs -red
```
List all PRs that have at least one red non-passing CI status. (Or use `-green` to list items that have all-green CI statuses.)

```
trailer list prs -conflict
```
List all PRs that cannot be merged because of conflicts. (Or use `-mergeable` to only list PRs which are mergeable.)

```
trailer list issues -before 1000
```
List all issues which have not been updated in the last 1000 days. Alternatively `-within 7` would, for example, list all issues updated within the past 7 days.

```
trailer show issue 5 -body -comments
```
Show issue #5. If there are more than one issues with the number #5 in different repositories, trailer will list them. You can then narrow the search down using `-r` or `-a` to specify which repo or author's issue you want to examine. The `-body` command will cause the Issue's main text to be displayed in addition to its details. The `-comments` command will also verbosely display all the comments/reviews in that issue.

```
trailer open issue 5 -r myrepo
```

Like `show` above, but instead opens the relevant GitHub web page. This, for example, would open issue #5 from "MyRepo" in the default system browser (macOS only for now)

```
trailer list labels -r myrepo
```
List all the labels that are in use currently in repository "MyRepo" (or use `-o` to list them for a specific org)

```
trailer list items -l bug
```
List all items that have a label containing the text "bug".

## Multiple Servers

```
trailer -s local.server.my.net -token <enterprise token>
trailer -s local.server.my.net update
trailer -s local.server.my.net list items
```

The `-s` command switches the context of trailer to another server. For instance, a local GitHub Enterprise server. All commands work identically, but will apply to this context. You can have as many parallel `-s` contexts as you like.

---
*Copyright (c) 2017 Paul Tsochantaris. Released under the terms of the MIT licence, see the file LICENCE for details.*