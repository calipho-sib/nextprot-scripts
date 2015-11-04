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

![diagram](doc/export/fire-and-prepare-next-release.png)

## Preparing new patches

The scripts below should be executed by humans to publish hot-fixes.

Like `nxs-fire-and-prepare-next-release.sh` the second one will eventually merges branch into develop and master thus
triggering the execution of `nxs-release.sh` by jenkins to create a new patch releases.

This delicate operation should be handled partly by scripts (first and last steps):

### Step 1: Creating and initializing a new `hotfix` branch

The script `nxs-checkout-hotfix-branch.sh` executes the following instructions:

1. it creates a branch named `hotfix-x.y.z+1` from branch master version x.y.z
2. it updates the patch version in all pom.xml files
3. it commits and pushes those changes in the hotfix branch

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

![diagram](doc/export/checkout-hotfix-branch.png)

### Step 2: Fixing the bug...

This step should be handled by the programmer responsible of fixing the bug.

### Step 3: Finalizing and publishing the hot fix

Once the fix is done, `nxs-fire-patch-release.sh` automatically merges the proper hotfix branch back to master and to develop branches:

1. it fetches the last hotfix version `x.y.z+1` from master (version x.y.z)
2. it merges and push hotfix branch back to master
3. it merges hotfix branch to develop without pushing to origin/develop

```
$ nxs-fire-patch-release.sh -h
usage: nxs-fire-patch-release.sh [-h][repo]
This script makes a new patch release.
It merges the hotfix branch back to master, merges to develop with pom.xml versions kept as in develop.
Once it is pushed to origin/master jenkins will publish the new patch with script 'nxs-release.sh'
Params:
 <repo> optional maven project git repository
Options:
 -h print usage
```

Note that there are multiple check points where user is asked to validate some git actions.

If everything goes ok, the terminal points to the develop branch with a git status output
notifying that "Your branch is ahead of 'origin/develop' by n commits."

Then the programmer has to check that everything is ok before pushing to origin/develop manually.

![diagram](doc/export/fire-patch-release.png)
