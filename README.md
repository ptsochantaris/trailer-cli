# Command-line Trailer

A version of [Trailer](http://ptsochantaris.github.io/trailer/) that runs on the macOS & Linux command-line, can integrate into scripts, be used on remote servers, or simply used because consoles are cool. This version does not aim for feature parity with the mainstream Trailer project although it shares common ideas and concepts.

![Screenshot](/trailer-cli-screenshot.jpeg?raw=true)

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

Please refer to the "cookbook" section below for an introduction to various features. There are no binaries for Linux (yet) but the project can be easily built from source (see right below).

## Building & Installing
**Note: Requires Swift 4.x.** Use the simple *(and perhaps not suitable for all setups)* script `install.sh` to place a built binary in /usr/local/bin, or you can manually build the project by entering `swift build -c release --static-swift-stdlib` and move the `trailer` binary from the `.build` subdirectory to wherever you like.

## Quickstart
Run Trailer without any arguments for some help. To get started:

- Create an API access token for the GitHub API (from [here](https://github.com/settings/tokens)) and tell Trailer about it. **The token you create on GitHub must contain all the `repo` permissions as well as the `read:org` permission**.

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

### Fetching info

```
trailer 
```
Get help on the available commands and filters. Highly recommended. You can type `help` after each command, such as `trailer list help` to get more info about that command.

```
trailer update all
```
Update the local data from the server. `-v` will give more info, or `-debug` will provide *very* verbose debug output on the GraphQL queries performed.

### Listing and filtering

#### Repositories
```
trailer list repos -h
```
Display the list of repositories. Repositories that are active (see below) will be highlighted in bold. `-h` means hide repos with no PRs or Issues. 

#### PRs and Issues
```
trailer list items -r swift -a bob
```
List all items in repositories (`-r`) containing the letters "swift" and (`-a`) authored by users whose handle contains the letters "bob".

#### Relevance
```
trailer list items -mine -participated -mentioned
```
List items that are either `-mine` (items created or assigned to me), `-participated` (i.e. commented on by me) or items where I've been `-mentioned` (either in the body or reviews/comments). You can combine these options like above, or use each one by itself. Or for instance, add `-r reponame` to limit this query to repositories whose names match `reponame`, or use `-t` to filter for a certain title, `-a` for an author, and so forth. Check the `help` option for a full list of options.

#### Text search
```
trailer list issues -c "needs update"
```
List only issues that have comments (or reviews) which (`-c`) include the text "needs update". You can also use `-b "needs update"` to search for items whose body includes this text.

#### Status
```
trailer list prs -red
```
List all PRs that have at least one `-red` non-passing CI status. (Or use `-green` to list items that have all-green CI statuses.)

#### Mergeability
```
trailer list prs -conflict
```
List all PRs that cannot be merged because of conflicts. (Or use `-mergeable` to only list PRs which are mergeable.)

#### Date
```
trailer list issues -within 7
```
List all issues which been updated `-within` the last 7 days. Alternatively `-before 7` would, for example, list all issues updated before the past 7 days.

#### Labels
```
trailer list labels -r myrepo
```
List all the labels that (`-r`) are in use currently in repository "MyRepo" (or use `-o` to filter for a specific org)

```
trailer list items -l bug
```
List all items that have a label containing the text "bug".

#### Milestones
```
trailer list milestones -r myrepo
```
List all the milestones available in (`-r`) repository "MyRepo".

```
trailer list items -m 2.0
```
List all items that have a milestone containing the text "2.0".

#### Reviews
```
trailer list prs -blocked
```
List all PRs on which (at lest) one reviewer has requested changes. You can also use `-unreviewed` to list items that have pending review requests or `-approved` for items where all reviewers approve.

#### Stats
```
trailer stats
```
List totals of items currently in the local cache.

### Viewing items

```
trailer show issue 5 -body -comments
```
Show issue #5. If there are more than one issues with the number #5 in different repositories, trailer will list them. You can then narrow the search down using `-r` or `-a` to specify which repo or author's issue you want to examine. The `-body` command will cause the Issue's main text to be displayed in addition to its details. The `-comments` command will also verbosely display all the comments/reviews in that issue.

```
trailer open issue 5 -r myrepo
```
Like `show` above, but instead opens the relevant GitHub web page. This, for example, would open issue #5 from "MyRepo" in the default system browser (macOS only for now)

```
trailer show pr 123 -comments -refresh
```
Show PR number 123 and its comments, but first quickly fetch any newer data related to it from GitHub. (If `-comments` is omitted then new comments will not be fetched.)

### Activating / Deactivating Repositories

Trailer will sync everything in your watchlist and the orgs you belong to, by default. This can be a lot of data that you don't need. You can limit the amount of things that get synced on each update in two ways. The recommended way is to limit the repositories from which you want to load info in the first place. Disabling repositories with many items can greatly improve your API usage and sync speed.

```
trailer config view -r myrepo
```
View the activation status of "MyRepo". Bold text means that all items are synced from it. Plain text means the repo is disabled and trailer will not fetch items related to it.

```
trailer config deactivate -r myrepo
```
Deactivates item syncing from "MyRepo". The opposite command, `activate` activates syncing from it.

**(Note: not specifying a filter with `-r` means that ALL repos will be activated/deactivated, so take care when using this command)**

```
trailer config deactivate
trailer config activate -r myrepo
```

Deactivate all repos, and enable only repos whose name matches "myrepo". You can also set certain repos to sync only PRs or issues using the `only-prs` or `only-issues` command.

### Advanced: Shorter Updates

Updates, if you have many items, can take a while and repeated updates with many items can cause the GitHub server to temporarily block you to avoid overload. However, you can reduce the number of things that get synced on a specific update by providing different parameters to the `update` command.

This way you can refresh subsets of things more often, and stay up to date, while refreshing everything using the `all` parameter less often.

*Tip: The `-v` parameter will also provide you with info on how much API usage you have used on GitHub for the current hourly window.*

```
trailer update repos
```
Only update the repository list

```
trailer update prs
```
Only update and check for new PRs.

```
trailer update issues comments
```
Only update and check for new issues, and also sync comments related to them.

```
trailer update prs issues
```

Update and check for new prs and issues, but not repos or comments.

*It's useful to remember that you can also use the filtering parameters (that you use when listing items) to also filter items for updates. This will affect only existing items though, and **not** scan for new ones. For example:*

```
trailer update prs comments -number 3 -r myrepo -n
```
Only update PR #3 from "MyRepo" and its related comments. `-number` can also be a comma-separated list of numbers. `-n` also lists new comments or reviews.

```
trailer update prs comments -t WIP -r swift
``` 

Update existing PRs whose titles include "WIP" (`-t`) and who belong to repository "Swift" (`-r`). Update comments for them too.

```
trailer update prs -red
``` 

Update only existing PRs which have at least one red CI status.

```
trailer update prs -fresh
```

The `-fresh` update flag will delete anything not explicitly specified in the list of types to sync. In this case: Update PRs but don't keep other items, like issues or comments.

### Advanced: Multiple Servers

```
trailer -s local.server.my.net -token <enterprise token>
trailer -s local.server.my.net update
trailer -s local.server.my.net list items
```

The `-s` command switches the context of trailer to another server. For instance, a local GitHub Enterprise server. All commands work identically, but will apply to this context. You can have as many parallel `-s` contexts as you like.

---
*Copyright (c) 2017 Paul Tsochantaris. Released under the terms of the MIT licence, see the file LICENCE for details.*