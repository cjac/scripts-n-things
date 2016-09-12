#!/bin/bash

NEXUSPROXY=nexus.fd.io

SETTINGSFILE=/tmp/test-settings.xml
LOGFILE=/tmp/test-deploy.log

function usage {
  echo "$0 <subproject>"
  exit 0
}

if [ -z $1 ]
then
    usage
fi

SUBPROJECT=$1
ARTIFACTID=testfile
VERSION=1.16.9-37.noarch
JAVA_VERSION=1.16.9-37-SNAPSHOT
GROUPID=io.fd.${SUBPROJECT}
GROUPPATH=$(echo $GROUPID|sed -e 's:\.:/:g')

USERNAME="deployment-${SUBPROJECT}"
echo -n "Password: "
read -s PASSWORD
echo ""

REPO_LIST="fd.io.snapshot site"

for SECTION in centos7 ubuntu.trusty.main ubuntu.xenial.main
do
    for RELEASE in master stable.test stable.1609
    do
        REPO_LIST="$REPO_LIST fd.io.${RELEASE}.${SECTION}"
    done
done

#
# Write settings XML file
#
CRED_EL="<username>${USERNAME}</username><password>${PASSWORD}</password>"
echo "<settings><servers>" > ${SETTINGSFILE}
for REPO_ID in ${REPO_LIST}
do
  echo "<server><id>${REPO_ID}</id>${CRED_EL}</server>" >> ${SETTINGSFILE}
done
echo "</servers></settings>" >> ${SETTINGSFILE}

echo "=== $(date) ===" >> ${LOGFILE}

#
# Test uploading
#
DEB_RX="(ubuntu|debian)"
RPM_RX="(centos|redhat)"
for REPO_ID in ${REPO_LIST}
do

  DVERSION="-Dversion=${VERSION}"
  if [[ ${REPO_ID} =~ ${DEB_RX} ]]
  then
      EXTENSION='deb'
  elif [[ ${REPO_ID} =~ ${RPM_RX} ]]
  then
      EXTENSION='rpm'
  elif [ ${REPO_ID} == 'site' ]
  then
      EXTENSION='txt'
  elif [ ${REPO_ID} == 'fd.io.snapshot' ]
  then
      EXTENSION='jar'
      DVERSION="-Dversion=${JAVA_VERSION}"
  fi

  FILENAME="${ARTIFACTID}-${VERSION}.${EXTENSION}"

  dd if=/dev/zero bs=1k count=1 of=${FILENAME} > /dev/null 2>&1

  echo mvn -X org.apache.maven.plugins:maven-deploy-plugin:deploy-file \
      -Dfile=${FILENAME} \
      -DrepositoryId=${REPO_ID} \
      -Durl=https://${NEXUSPROXY}/content/repositories/${REPO_ID} \
      -DgroupId=${GROUPID} \
      ${DVERSION} \
      -DartifactId=${ARTIFACTID} \
      -Dtype=${EXTENSION} \
      -Dclassifier=${EXTENSION} \
      -s ${SETTINGSFILE} >> ${LOGFILE} 2>&1

  if [ $? -eq 0 ]
  then
     echo "Test of deployment to repo ${REPO_ID} successful"
  else
     echo "Test of deployment to repo ${REPO_ID} failed"
  fi

  # Remove artifact
  curl -u "${USERNAME}:${PASSWORD}" -X DELETE \
       "https://${NEXUSPROXY}/service/local/repositories/${REPO_ID}/content/${GROUPPATH}/${ARTIFACTID}/${VERSION}/${ARTIFACTID}-${VERSION}-${EXTENSION}.${EXTENSION}"

  if [ $? -eq 0 ]
  then
     echo "Artifact clean-up on ${REPO_ID} successful"
  else
     echo "Artifact clean-up on ${REPO_ID} failed"
  fi


  # Rebuild metadata
  curl -u "${USERNAME}:${PASSWORD}" -X DELETE "https://${NEXUSPROXY}/service/local/metadata/repositories/${REPO_ID}/content"

  if [ $? -eq 0 ]
  then
     echo "Metadata clean-up on ${REPO_ID} successful"
  else
     echo "Metadata clean-up on ${REPO_ID} failed"
  fi

done
