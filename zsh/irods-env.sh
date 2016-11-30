# irods-env - a function to switch between different iRODS environments
# Author: Ilari Korhonen, KTH Royal Institute of Technology

function irods-env {
    env_name=$@
    env_file="$HOME/.irods/irods_environment.json.$env_name"

    if [ ! -f "$env_file" ]; then
	echo "irods-env: unable to find iRODS environment '$env_name'"
	return
    fi

    mv $HOME/.irods/irods_environment.json $HOME/.irods/irods_environment.json.backup
    cp $HOME/.irods/irods_environment.json."$@" $HOME/.irods/irods_environment.json
    iexit full

    auth_scheme=`python -c "import os,json,sys; print json.load(open(os.path.join(os.getenv('HOME'), '.irods', 'irods_environment.json')))['irods_authentication_scheme']"`

    if [ $auth_scheme = "KRB" ]; then
	imiscsvrinfo
    else
	iinit; imiscsvrinfo
    fi

    if [ $? -ne "0" ]; then
	printf "\nirods-env: unable to initialize iRODS environment '$@', reverting back!\n"
	cp $HOME/.irods/irods_environment.json.backup $HOME/.irods/irods_environment.json
	iinit
    fi
}
