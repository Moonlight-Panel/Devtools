#! /bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    echo "Moonlight Development CLI"
    echo ""
    echo "Usage: mldev <module> <command>"
    echo "See https://docs.moonlightpanel.xyz for all commands"
    exit 1
fi

module=$1
command=$2

# Contribution commands
contributionSetup() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: mldev contribution setup <link to own fork on github>"
        echo "See https://docs.moonlightpanel.xyz for all commands"
        exit 1
    fi
    
    mkdir -p ~/.config/mldev/
    echo $1 > ~/.config/mldev/contribution-url
}

contributionCreate() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: mldev contribution create <name> <path> (branch)"
        echo "See https://docs.moonlightpanel.xyz for all commands"
        exit 1
    fi
    
    if [ -z "$3" ]; then
        branch="v2"
    else
        branch=$3
    fi
    
    mkdir -p $2
    mkdir -p $2/source
    repo_url=`cat ~/.config/mldev/contribution-url`
    git clone -b $branch $repo_url $2/source
    (cd $2/source; git checkout -b $1)
    
    touch $2/mldev.meta
}

contributionCommit() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: mldev contribution commit <description>"
        echo "See https://docs.moonlightpanel.xyz for all commands"
        exit 1
    fi
    
    if [ ! -f mldev.meta ]; then
        echo "You need to execute this command in the main directory of a project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi
    
    (cd source; git add .; git commit -m $1)
}

contributionPush() {
    if [ ! -f mldev.meta ]; then
        echo "You need to execute this command in the main directory of a project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi
    
    (cd source; git push || git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD))
}

# Handle commands

case $module in
    contribution)
        
        if [ "$command" == "setup" ]; then
            contributionSetup $3
        elif [ "$command" == "create" ]; then
           contributionCreate $3 $4 $5
        elif [ "$command" == "commit" ]; then
           contributionCommit $3
        elif [ "$command" == "push" ]; then
           contributionPush $3
        else
            echo "Unknown command '$command' in module '$module'"
        fi

        ;;
    *)
        echo "Unknown module: '$module'"
        exit 1
        ;;
esac