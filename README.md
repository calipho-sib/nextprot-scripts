# nextprot-scripts

Contains scripts for installation and deployment of nextprot apps and databases.

## Preparing new releases

The script below should be executed by a human to make a new release.

It will eventually merge into master, thus triggering the execution of `nxs-release.sh` by jenkins to create a new release.

### nxs-fire-and-prepare-next-release.sh

```
$ nxs-fire-and-prepare-next-release.sh -h
usage: nxs-fire-and-prepare-next-release.sh <next-snapshot-version> [repo]
This script fires indirectly a new production release (through jenkins) and prepares next development release with the given version (-SNAPSHOT is added automatically)
Params:
 <next-snapshot-version> next snapshot version (MAJOR.MINOR.PATCH)
 <repo> optional maven project git repository
Options:
 -h print usage
```

[diagram](doc/fire-and-prepare-next-release.html)

## Preparing new patches

The scripts below should be executed by humans to publish hot-fixes.

Like `nxs-fire-and-prepare-next-release.sh` the second one will eventually merges branch into develop and master thus
triggering the execution of `nxs-release.sh` by jenkins to create a new patch releases.

This delicate operation should be handled partly by scripts (first and last steps):

### Step 1: Creating and initializing a new `hotfix` branch

The script `nxs-checkout-hotfix-branch.sh` is dedicated for this task and should be executed.

It creates a branch named `hotfix-x.y.z+1` from branch master.
Then it checkout to this branch, updates pom.xml file(s) version to `x.y.z+1`, commits and pushes to the hotfix branch.

Here is the usage:

```
$ nxs-checkout-hotfix-branch.sh -h
usage: nxs-checkout-hotfix-branch.sh [repo]
This script prepares and inits the next hotfix branch coming from master and checkout to it (after it, you can start fixing it :))
Params:
 <repo> optional maven project git repository
Options:
 -h print usage
```

See also the [diagram](doc/checkout-hotfix-branch.html) for a graphic view of the tasks.

### Step 2: Fixing the bug...

This step should be handled by the programmer responsible of fixing the bug.

### Step 3: Finalizing the hot fix

Once the fix is done, another script automatically merges the proper hotfix branch back to develop and to master branches:

```
$ nxs-fire-patch-release.sh -h
usage: nxs-fire-patch-release.sh [repo]
This script closes the next hotfix branch coming from master, push to develop (pom version kept as in develop) and to master to make a new patch release (jenkins will executes nxs-release.sh)
Params:
 <repo> optional maven project git repository
Options:
 -h print usage
```

Note that there are multiple check points where user is asked to validate some git actions.

If everything goes ok, the terminal points to the develop branch with a git status output
notifying that "Your branch is ahead of 'origin/develop' by n commits."

The last step is to check that everything is ok and push to origin develop manually.

See also the [diagram](doc/fire-patch-release.html) for a graphic view of the tasks.
