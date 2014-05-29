#!/bin/bash

# A script to deploy a war file to AWS Elastic Beanstalk.
#
# As specified in usage below, eb-deploy
#   * reads its params from environment variables
#   * you may pass options to override or pass params
#

usage()
{
cat << EOF
usage: $0 options

Deploy a war file to AWS Elastic Beanstalk.

OPTIONS:
   -h      Show this message
   -w      \$APP_WAR                    | WAR file location
   -k      \$APP_AWS_ACCESS_KEY         | AWS Key
   -s      \$APP_AWS_SECRET_KEY         | AWS Secret

EOF
}

# Read param values from environment vars.
# Its prbably not needed but putting it in here to be
# explicit about the notion of reading from environment vars
APP_WAR=$APP_WAR
APP_AWS_ACCESS_KEY=$APP_AWS_ACCESS_KEY
APP_AWS_SECRET_KEY=$APP_AWS_SECRET_KEY
APP_EB_InstanceProfileName=$APP_EB_InstanceProfileName
APP_EB_ApplicationName=$APP_EB_ApplicationName
APP_EB_EnvironmentName=$APP_EB_EnvironmentName

# Read passed options
while getopts “hw:v:k:s:p:a:e:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         w)
             APP_WAR=$OPTARG
             ;;
         k)
             APP_AWS_ACCESS_KEY=$OPTARG
             ;;
         s)
             APP_AWS_SECRET_KEY=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

# source the properties
. environment.properties


# ensure required params have been passed
if [ -z $APP_WAR ]; then
	echo 'aborting: -w or $APP_WAR not set. It should point to the war file location relative to $DEPLOY_DIR below and be the form ./target/scala-2.10/app_2.10-0.1'
	usage
	exit 1
fi
if [ -z $APP_EB_InstanceProfileName ]; then
    echo 'aborting: -p or $APP_EB_InstanceProfileName not set'
	usage
	exit 1
fi
if [ -z $APP_EB_ApplicationName ]; then
    echo 'aborting: -a or $APP_EB_ApplicationName not set'
	usage
	exit 1
fi
if [ -z $APP_EB_EnvironmentName ]; then
    echo 'aborting: -e or $APP_EB_EnvironmentName not set'
	usage
	exit 1
fi

# optional env vars
if [ -z $APP_EB_GIT_EMAIL ]; then
    APP_EB_GIT_EMAIL="am-automation@properllerhead.co.nz"
fi
if [ -z $APP_EB_GIT_USERNAME ]; then
    APP_EB_GIT_USERNAME="am-automation"
fi
if [ -z $APP_EB_EnvironmentType ]; then
    APP_EB_EnvironmentType="LoadBalanced"
fi
if [ -z $APP_EB_RdsEnabled ]; then
    APP_EB_RdsEnabled="No"
fi
if [ -z $APP_EB_Region ]; then
    APP_EB_Region="ap-southeast-2"
fi
if [ -z $APP_EB_CLI_VERSION ]; then
    APP_EB_CLI_VERSION="2.6.0"
fi

# ensure required tools exists
command -v wget >/dev/null 2>&1 || { echo >&2 "aborting: need wget, please install it first."; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "aborting: need unzip, please install it first."; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "aborting: need git, please install it first."; exit 1; }

# Ensure war file exists
WAR=$APP_WAR
if [ ! -f $WAR ]; then
    echo "War file not found at $WAR."
    usage
    exit 1
fi

echo using war file at $WAR...

# Get Elastic Beanstalk command line tool
EB_CLI_ZIP=AWS-ElasticBeanstalk-CLI-$APP_EB_CLI_VERSION.zip
EB_CLI_URL=https://s3.amazonaws.com/elasticbeanstalk/cli/$EB_CLI_ZIP
EB_CLI_HOME=AWS-ElasticBeanstalk-CLI-$APP_EB_CLI_VERSION

rm -r $EB_CLI_ZIP
rm -rf $EB_CLI_HOME
echo fetching $EB_CLI_URL
wget $EB_CLI_URL > /dev/null
echo expanding $EB_CLI_ZIP
unzip $EB_CLI_ZIP > /dev/null

# create deployment dir and switch to it.
echo 'prepping deployment dir...'
DEPLOY_DIR=./target-deployment
rm -rf $DEPLOY_DIR
mkdir $DEPLOY_DIR
cd $DEPLOY_DIR

# since $DEPLOY_DIR is going to be our working dir we need paths relative to $DEPLOY_DIR
SCRIPTDIR=../$EB_CLI_HOME/AWSDevTools/Linux
PATH=$PATH:../$EB_CLI_HOME/eb/linux/python2.7/

# prep .elasticbeanstalk
mkdir .elasticbeanstalk
# set .elasticbeanstalk/aws_credential_file
cat > .elasticbeanstalk/aws_credential_file <<EOL
AWSAccessKeyId=$APP_AWS_ACCESS_KEY
AWSSecretKey=$APP_AWS_SECRET_KEY

EOL

# set .elasticbeanstalk/config
cat > .elasticbeanstalk/config <<EOL
[global]
AwsCredentialFile=.elasticbeanstalk/aws_credential_file
EnvironmentTier=WebServer::Standard::1.0
ServiceEndpoint=https://elasticbeanstalk.$APP_EB_Region.amazonaws.com
SolutionStack=64bit Amazon Linux 2013.09 running Tomcat 7 Java 7
DevToolsEndpoint=git.elasticbeanstalk.$APP_EB_Region.amazonaws.com

EnvironmentType=$APP_EB_EnvironmentType
RdsEnabled=$APP_EB_RdsEnabled
Region=$APP_EB_Region
InstanceProfileName=$APP_EB_InstanceProfileName
ApplicationName=$APP_EB_ApplicationName
EnvironmentName=$APP_EB_EnvironmentName

EOL

# copy elastic beanstalk creds to home
cp -r .elasticbeanstalk $HOME

# init git
git init .

git config --global user.email $APP_EB_GIT_EMAIL
git config --global user.name $APP_EB_GIT_USERNAME

# setup eb
cp -r $SCRIPTDIR/scripts .git/AWSDevTools

git config alias.aws.elasticbeanstalk.remote "!.git/AWSDevTools/aws.elasticbeanstalk.push --remote-url"
git config aws.endpoint.us-east-1 git.elasticbeanstalk.us-east-1.amazonaws.com
git config aws.endpoint.ap-northeast-1 git.elasticbeanstalk.ap-northeast-1.amazonaws.com
git config aws.endpoint.eu-west-1 git.elasticbeanstalk.eu-west-1.amazonaws.com
git config aws.endpoint.us-west-1 git.elasticbeanstalk.us-west-1.amazonaws.com
git config aws.endpoint.us-west-2 git.elasticbeanstalk.us-west-2.amazonaws.com
git config aws.endpoint.ap-southeast-1 git.elasticbeanstalk.ap-southeast-1.amazonaws.com
git config aws.endpoint.ap-southeast-2 git.elasticbeanstalk.ap-southeast-2.amazonaws.com
git config aws.endpoint.sa-east-1 git.elasticbeanstalk.sa-east-1.amazonaws.com
git config alias.aws.elasticbeanstalk.push "!.git/AWSDevTools/aws.elasticbeanstalk.push"
git config alias.aws.push '!git aws.elasticbeanstalk.push'
git config alias.aws.elasticbeanstalk.config "!.git/AWSDevTools/aws.elasticbeanstalk.config"
git config alias.aws.config '!git aws.elasticbeanstalk.config'

# ensure eb is connected
echo 'Attemping to connect to eb...'
export PATH=$PATH:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin
python -V
eb status --verbose

# unzip the war file and commit it to eb local index
echo 'Preparing Deployment Package...'
unzip -o $WAR >/dev/null
git add -f *
git commit -m "Deployed new version" >/dev/null

echo 'Deploying. This may take a bit; please standby...'
# deploy
git aws.push

cd ..
rm -rf $DEPLOY_DIR
rm -r $EB_CLI_ZIP
rm -rf $EB_CLI_HOME
echo
echo '... thats all folks!'
echo
