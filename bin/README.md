# About
Gathering plugin version information is not something you can always count on, since plugin version info is
not required to be publically readable. However, any plugin that has static assets, you can fingerprint 
those assets history and compare the fingerprint of the assets on the site to the history and infer
the plugin versions.

The `fp_build_data.sh` script downloads every version of a specified plugin and creates a "fake git history" from which
you build a dictionary of the files that are changed at a specific version.

To start building a public db, doing this for every (top-1000?) plugin would be straight-forward. To slim the data down, you could limit to pulling plugins & versions listed on `wpvulndb`.

## Steps
- $x site has `events-manager` installed and you cannot id what version it's running with `wpscan`
- You can build the static assets fingerprints with `./fp_build_data.sh events-manager` which generates `events-manager.vspec` & `events-manager.list`
- Then scan site plugin with `./fp_check_site_plugin.sh $x events-manager` (depends on data from last step)
- Currently you have to manually compare found hashes vs the hashes in `events-manager.vspec`

## Todo
- Script matching up found fingerprints with dictionary to give a version range
