# nextprot-scripts

Contains scripts for installation and deployment of nextprot apps and databases.

## Of releases and patches

The scripts below should be executed by humans to make new releases and hot-fixes.

Each of them will eventually merge into master, thus triggering the execution of nxs-release.sh by jenkins 
to create a new releases.

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
 
### nxs-open-hotfix.sh

```
$ nxs-open-hotfix.sh -h
usage: nxs-open-hotfix.sh [repo]
This script prepares and inits the next hotfix branch coming from master and checkout to it (after it, you can start fixing it :))
Params:
 <repo> optional maven project git repository
Options:
 -h print usage
```

[diagram](doc/open-hotfix.html)

### nxs-close-hotfix.sh

```
$ nxs-close-hotfix.sh -h
usage: /Users/fnikitin/Projects/nextprot-scripts/src/nxs-close-hotfix.sh [repo]
This script closes the next hotfix branch coming from master, push to develop (pom version kept as in develop) and to master to make a new patch release (jenkins will executes nxs-release.sh)
Params:
 <repo> optional maven project git repository
Options:
 -h print usage
```

[diagram](doc/close-hotfix.html)
