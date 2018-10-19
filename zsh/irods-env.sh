# irods-env - a function to switch between different iRODS environments
# Author: Ilari Korhonen, KTH Royal Institute of Technology

function irods-env {
    env_name=$1
    env_file="$HOME/.irods/irods_environment.json.$env_name"

    if [ ! -f "$env_file" ]; then
	echo "irods-env: unable to find iRODS environment '$env_name'"
	return
    fi

    cp $HOME/.irods/irods_environment.json $HOME/.irods/irods_environment.json.backup
    cp $HOME/.irods/irods_environment.json."$@" $HOME/.irods/irods_environment.json
    iexit full

    auth_scheme=`python -c "import os,json,sys; print json.load(open(os.path.join(os.getenv('HOME'), '.irods', 'irods_environment.json')))['irods_authentication_scheme']"`

    if [ $auth_scheme != "KRB" ]; then
	iinit
    fi

    # test iRODS login
    iuserinfo >/dev/null

    if [ $? -ne "0" ]; then
	printf "irods-env: iRODS login failed - unable to initialize iRODS environment '${env_name}' and thus reverting back!\n"
	cp $HOME/.irods/irods_environment.json.backup $HOME/.irods/irods_environment.json
    else
	printf "iRODS login successful - command line user environment '${env_name}' activated!\n"
    fi
}
