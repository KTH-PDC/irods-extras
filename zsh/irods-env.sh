# irods-env - a function to switch between different iRODS environments
# Author: Ilari Korhonen, KTH Royal Institute of Technology

function irods-env {
    env_name=$1

    env_file_base="$HOME/.irods/irods_environment.json"
    env_file="${env_file_base}.${env_name}"
    env_file_backup="${env_file_base}.backup"

    # check we have the requested env file
    if [ ! -f "${env_file}" ]; then
	echo "irods-env: unable to find iRODS environment '${env_name}'"
	return
    fi

    # check if we have an existing env files
    if [ -f "${env_file_base}" ]; then
	cp ${env_file_base} ${env_file_backup}
    fi

    # overwrite the env file and clean up old auth token
    cp ${env_file} ${env_file_base}
    iexit full

    # for non-kerberos auth we run iinit
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
