#!/bin/sh
while getopts :f:g: option
do
 case "${option}" in
 f) KUBEDIFF_REPO_URL=${OPTARG};;
 g) GITOPS_SSH_URL=${OPTARG};; 
 esac
done
 
KUBEDIFF_NAMESPACE="kubediff"
REPO_DIR="kubediff"

rm -rf $REPO_DIR
echo "Cloning Kubediff $KUBEDIFF_REPO_URL"
if ! git clone $KUBEDIFF_REPO_URL $REPO_DIR; then
    echo "ERROR: failed to clone $KUBEDIFF_REPO_URL"
    exit 1
fi

cd $REPO_DIR/k8s

re="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/(.+).git$"
if [[ $GITOPS_URL =~ $re ]]; then
    user=${BASH_REMATCH[4]}
    repo=${BASH_REMATCH[5]}

    # kubediff does not include a helm chart, replace the config repo with 
    # gitops url
    if ! sed -i -e "s|<your config repo>|$user/$repo|g" ./kubediff-rc.yaml; then
        echo "ERROR: failed to update with gitops url $GITOPS_URL"
        exit 1
    fi

    if ! sed -i -e "s|<location in your repo of yaml files>||g" ./kubediff-rc.yaml; then
        echo "ERROR: failed to update location in your repo of yaml files"
        exit 1
    fi
fi

echo "Updated with gitops url $GITOPS_URL"
sed '23q;d' ./kubediff-rc.yaml

cd ../../ 

echo "creating kubernetes namespace $KUBEDIFF_NAMESPACE if needed"
if ! kubectl describe namespace $KUBEDIFF_NAMESPACE > /dev/null 2>&1; then  
    if ! kubectl create namespace $KUBEDIFF_NAMESPACE; then  
        echo "ERROR: failed to create kubernetes namespace $KUBEDIFF_NAMESPACE"  
        exit 1  
    fi   
fi

echo "Applying kubediff deployment"
if ! kubectl create -f  $REPO_DIR/k8s/ -n $KUBEDIFF_NAMESPACE; then
    echo "ERROR: failed to apply kubediff deployment"
    exit 1
fi
 
echo "kubediff deployment complete"
