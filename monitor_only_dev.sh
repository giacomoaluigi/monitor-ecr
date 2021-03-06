#!/bin/sh

#
# compare two semver
#
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}


#############################################################
#  handle develop cdci
#############################################################

#
# get last version pushed to ecr registry
#
LAST_VER_UNSTABLE=$(aws ecr describe-images --repository-name hello-node --output text --query 'sort_by(imageDetails,& imagePushedAt)[*].imageTags[*]' | tr '\t' '\n' | grep unstable | tail -1)


#
# get current unstable running
#
RUNNING_VER_UNSTABLE=$(cat running_ver_unstable)


#
# compare versions
#
# vercomp return
# 0 if =
# 1 if <
# 2 if >
vercomp ${LAST_VER_UNSTABLE:0:5} ${RUNNING_VER_UNSTABLE:0:5}
if [[ $? -eq 1 ]]
then
    echo "devo lanciare kubectl su develop"
    # 1 - switch kubectl context to develop
    kubectl config use-context giacomo-k8s-develop.giacomoaluigi.com

    # 2 - prepare yml file
    NEWIMAGE="016772326329.dkr.ecr.eu-west-1.amazonaws.com\/hello-node:"$LAST_VER_UNSTABLE
    echo $NEWIMAGE
    echo ""
    # read the yml template from a file and substitute the string 
    # {{DOCKERIMAGE}} with the value of the MYVARVALUE variable
    template=$(cat "../recipes/development.yml.template" | sed "s/{{DOCKERIMAGE}}/$NEWIMAGE/g")

    echo "$template" > ../recipes/development.yml
    
    kubectl apply -f ../recipes/development.yml

    # update running ver
    echo $LAST_VER_UNSTABLE > ./running_ver_unstable

fi
