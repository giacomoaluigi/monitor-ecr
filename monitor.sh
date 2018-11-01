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
#  install kubectl
#############################################################
bash install_musthave.sh


#############################################################
#  handle develop cd
#############################################################

#
# get last version pushed to ecr registry
#
LAST_VER_UNSTABLE=$(aws ecr describe-images --repository-name hello-node --output text --query 'sort_by(imageDetails,& imagePushedAt)[*].imageTags[*]' | tr '\t' '\n' | grep unstable | tail -1)


#
# get current unstable running
#
if [ ! -f running_ver_unstable ]
then
  touch running_ver_unstable
fi
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
    template=$(cat "./recipes/development.yml.template" | sed "s/{{DOCKERIMAGE}}/$NEWIMAGE/g")

    if [ ! -f ./recipes/development.yml ]
    then
        touch ./recipes/development.yml
        echo "$template" > ./recipes/development.yml
    fi
    
    kubectl apply -f ./recipes/development.yml

    # update running ver
    echo $LAST_VER_UNSTABLE > ./running_ver_unstable

else 
    echo "nothing to do... maybe..."
    echo ""
fi

#############################################################
#  handle live cd
#############################################################

# check stable images
LAST_VER_STABLE=$(aws ecr describe-images --repository-name hello-node --output text --query 'sort_by(imageDetails,& imagePushedAt)[*].imageTags[*]' | tr '\t' '\n' | grep -- -stable | tail -1)

#
# get current unstable running
#
if [ ! -f running_ver_stable ]
then
  touch running_ver_stable
fi
RUNNING_VER_STABLE=$(cat running_ver_stable)


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
    echo "devo lanciare kubectl su live"
    # 1 - switch kubectl context to develop
    kubectl config use-context giacomo-k8s-live.giacomoaluigi.com

    # 2 - prepare yml file
    NEWIMAGE="016772326329.dkr.ecr.eu-west-1.amazonaws.com\/hello-node:"$LAST_VER_STABLE
    echo $NEWIMAGE
    echo ""
    # read the yml template from a file and substitute the string 
    # {{DOCKERIMAGE}} with the value of the MYVARVALUE variable
    template=$(cat "./recipes/production.yml.template" | sed "s/{{DOCKERIMAGE}}/$NEWIMAGE/g")

    if [ ! -f ./recipes/production.yml ]
    then
        touch ./recipes/production.yml
        echo "$template" > ./recipes/production.yml
    fi
    
    kubectl apply -f ./recipes/production.yml

    # update running ver
    echo $LAST_VER_STABLE > ./running_ver_stable

else 
    echo "nothing to do... maybe..."
    echo ""
fi

echo "" >> $LOGFILE
echo ">>> END  "$(date +"%Y-%m-%d %H:%M:%S") >> $LOGFILE
echo "" >> $LOGFILE