#!/bin/sh

LOGFILE="./logs"
LOGFILE="./logs"

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

echo ">>> START  "$(date +"%Y-%m-%d %H:%M:%S") >> $LOGFILE
echo "" >> $LOGFILE

#############################################################
#  install kubectl and other things to have
#############################################################
echo ">>> MUSTHAVE" >> $LOGFILE
echo "" >> $LOGFILE
bash install_musthave.sh >> $LOGFILE
echo "" >> $LOGFILE


#############################################################
#  handle develop cd
#############################################################

echo ">>> UNSTABLE" >> $LOGFILE
echo "" >> $LOGFILE

#
# get last version pushed to ecr registry
#
LAST_VER_UNSTABLE=$(aws ecr describe-images --repository-name hello-node --output text --query 'sort_by(imageDetails,& imagePushedAt)[*].imageTags[*]' | tr '\t' '\n' | grep unstable | tail -1)
echo "last ver: "$LAST_VER_UNSTABLE >> $LOGFILE
echo "" >> $LOGFILE

#
# get current unstable running
#
if [ ! -f running_ver_unstable ]
then
  touch running_ver_unstable
fi
RUNNING_VER_UNSTABLE=$(cat running_ver_unstable)
echo "running ver: "$RUNNING_VER_UNSTABLE >> $LOGFILE
echo "" >> $LOGFILE


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

    # 1 - switch kubectl context to develop
    kubectl config use-context giacomo-k8s-develop.giacomoaluigi.com

    # 2 - prepare yml file
    NEWIMAGE="016772326329.dkr.ecr.eu-west-1.amazonaws.com\/hello-node:"$LAST_VER_UNSTABLE
    echo "new image: "$NEWIMAGE >> $LOGFILE
    echo "" >> $LOGFILE

    # read the yml template from a file and substitute the string 
    # {{DOCKERIMAGE}} with the value of the MYVARVALUE variable
    template=$(cat "./recipes/development.yml.template" | sed "s/{{DOCKERIMAGE}}/$NEWIMAGE/g")

    if [ ! -f ./recipes/development.yml ]
    then
        touch ./recipes/development.yml
    fi
    echo "$template" > ./recipes/development.yml
    
    kubectl apply -f ./recipes/development.yml
    if [ $? -eq 0 ]
    then
        echo "kubectl ok " >> $LOGFILE
        echo "" >> $LOGFILE
    fi

    # update running ver
    echo $LAST_VER_UNSTABLE > ./running_ver_unstable
    echo "updating running version with:  "$LAST_VER_UNSTABLE >> $LOGFILE
    echo "" >> $LOGFILE

else 
    echo "ustable - nothing to do... maybe..." >> $LOGFILE
    echo "" >> $LOGFILE
fi

#############################################################
#  handle live cd
#############################################################

echo ">>> STABLE" >> $LOGFILE
echo "" >> $LOGFILE

# check stable images
LAST_VER_STABLE=$(aws ecr describe-images --repository-name hello-node --output text --query 'sort_by(imageDetails,& imagePushedAt)[*].imageTags[*]' | tr '\t' '\n' | grep -- -stable | tail -1)
echo "last ver: "$LAST_VER_STABLE >> $LOGFILE
echo "" >> $LOGFILE

#
# get current stable running
#
if [ ! -f running_ver_stable ]
then
  touch running_ver_stable
fi
RUNNING_VER_STABLE=$(cat running_ver_stable)
echo "running ver: "$RUNNING_VER_STABLE >> $LOGFILE
echo "" >> $LOGFILE


#
# compare versions
#
# vercomp return
# 0 if =
# 1 if <
# 2 if >
vercomp ${LAST_VER_STABLE:0:5} ${RUNNING_VER_STABLE:0:5}
if [[ $? -eq 1 ]]
then
    
    # 1 - switch kubectl context to live
    kubectl config use-context giacomo-k8s-live.giacomoaluigi.com

    # 2 - prepare yml file
    NEWIMAGE="016772326329.dkr.ecr.eu-west-1.amazonaws.com\/hello-node:"$LAST_VER_STABLE
    echo "new image: "$NEWIMAGE >> $LOGFILE
    echo "" >> $LOGFILE

    # read the yml template from a file and substitute the string 
    # {{DOCKERIMAGE}} with the value of the MYVARVALUE variable
    template=$(cat "./recipes/production.yml.template" | sed "s/{{DOCKERIMAGE}}/$NEWIMAGE/g")

    if [ ! -f ./recipes/production.yml ]
    then
        touch ./recipes/production.yml
    fi
    echo "$template" > ./recipes/production.yml
    
    kubectl apply -f ./recipes/production.yml
    if [ $? -eq 0 ]
    then
        echo "kubectl ok " >> $LOGFILE
        echo "" >> $LOGFILE
    fi

    # update running ver
    echo $LAST_VER_STABLE > ./running_ver_stable
    echo "updating running stable version with:  "$LAST_VER_STABLE >> $LOGFILE
    echo "" >> $LOGFILE

else 
    echo "stable - nothing to do... maybe..." >> $LOGFILE
    echo "" >> $LOGFILE
fi
