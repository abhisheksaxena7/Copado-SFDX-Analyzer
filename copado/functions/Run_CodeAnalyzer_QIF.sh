#!/bin/bash
set -euo pipefail

########## Get Source and Destination Branch names and Checkout Repository #############
copado -p "Reading parameters..."
originBranch=$(jq -r '.originBranch' <<< $branchesAndFileIdJson)
BRANCH="$originBranch"
destinationBranch=$(jq -r '.destinationBranch' <<< $branchesAndFileIdJson)

echo "param originBranch = $originBranch"
echo "param destinationBranch = $destinationBranch"

copado -p "Cloning repo..."
copado-git-get $destinationBranch
copado-git-get $BRANCH

########### Create delta packages for new, modified or deleted metadata  ############
copado -p "Generating Diff between the Source and Destination branches..."
mkdir changed-sources
sfdx sgd:source:delta --to "HEAD" --from "origin/$destinationBranch" --output changed-sources/ --generate-delta --source .
echo "Here's the files that have been changes in this US"
cat changed-sources/package/package.xml

################ Run SFDX Scanner only on Changed Metadata  ###############
#TODO change html format with sarif, once the sarif viewer is generic enough
copado -p "Running sfdx scanner..."
exitCode=0
sfdx scanner:run --format json --target "./changed-sources/**/*.*" --engine $engine --severity-threshold $severityThreshold --outfile ./output.json || exitCode=$?

############ Attach Results to the Function results record  ####################
copado -p "Uploading results..."
if [ -f "output.json" ]; then
    copado -u output.json
fi

echo "Sfdx scanner scan completed. exit code: $exitCode"
exit $exitCode
