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

    # Save current project id

    # Get new id by incrementing the last one
    last_id=`cat ~/.config/mldev/last_project_id 2> /dev/null || echo 0`
    current_id=$((last_id + 1))
    echo "$current_id" > ~/.config/mldev/last_project_id

    echo $current_id > $2/mldev.meta
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

dbStart() {
    if [ ! -f mldev.meta ]; then
        echo "You need to execute this command in the main directory of a project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi

    id=`cat mldev.meta`
    port=$((id + 3000))
    name="ml_dev_$id"

    if ! sudo docker ps -a | grep -q "$name"; then
        sudo docker run -d --add-host=host.docker.internal:host-gateway --publish 0.0.0.0:${port}:3306 --name ${name} -v ${name}:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=${name} -e MYSQL_DATABASE=${name} -e MYSQL_USER=${name} -e MYSQL_PASSWORD=${name} mysql:latest
    fi

    sudo docker start $name

    if [ ! -f mldev.plugin.meta ]; then
        mkdir -p source/Moonlight/ApiServer/storage
        dbSetup "source/Moonlight/ApiServer/storage/config.json" $name $port
    else
        mkdir -p Moonlight/Moonlight/ApiServer/storage
        dbSetup "Moonlight/Moonlight/ApiServer/storage/config.json" $name $port
    fi
}

dbStop() {
    if [ ! -f mldev.meta ]; then
        echo "You need to execute this command in the main directory of a project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi

    id=`cat mldev.meta`
    name="ml_dev_$id"

    sudo docker stop $name
}

dbRestart() {
    if [ ! -f mldev.meta ]; then
        echo "You need to execute this command in the main directory of a project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi

    id=`cat mldev.meta`
    name="ml_dev_$id"

    sudo docker restart $name
}

dbDelete() {
    if [ ! -f mldev.meta ]; then
        echo "You need to execute this command in the main directory of a project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi

    id=`cat mldev.meta`
    name="ml_dev_$id"

    sudo docker stop $name
    sudo docker container rm $name
    sudo docker volume rm $name
}

replace_json_property() {
    local json_file="$1"
    local prop_name="$2"
    local new_value="$3"

    # Read the entire JSON file
    local content=$(jq '.' "$json_file")

    # Replace the property value
    local replaced_content=$(echo "$content" | jq ".${prop_name} = $new_value")

    # Write the modified content back to the file
    echo "$replaced_content" > "$json_file"
}

dbSetup() {
    if [ ! -f $1 ]; then
        echo -e "{\n  \"Database\": {\n    \"Host\": \"dev-server\",\n    \"Port\": 3301,\n    \"Username\": \"ml_dev_1\",\n    \"Password\": \"ml_dev_1\",\n    \"Database\": \"ml_dev_1\"\n  }\n}" > $1
    fi

    replace_json_property $1 "Database.Host" "\"localhost\""
    replace_json_property $1 "Database.Port" $3
    replace_json_property $1 "Database.Username" "\"$2\""
    replace_json_property $1 "Database.Password" "\"$2\""
    replace_json_property $1 "Database.Database" "\"$2\""
}

pluginCreate() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: mldev plugin create <name> <path> (branch)"
        echo "See https://docs.moonlightpanel.xyz for all commands"
        exit 1
    fi

    if ! dotnet new list | grep -q 'moonlight.v2.plugintemplate'; then
        echo "Installing plugin template"
        rm -rf ~/.config/mldev/pluginTemplate
        git clone https://github.com/Moonlight-Panel/PluginTemplate ~/.config/mldev/pluginTemplate
        dotnet new install ~/.config/mldev/pluginTemplate
    fi

    mkdir -p $2
    mkdir -p $2/source
    mkdir -p $2/Moonlight

    if [ -z "$3" ]; then
        branch="v2"
    else
        branch=$3
    fi

    git clone -b $branch https://github.com/Moonlight-Panel/Moonlight $2/Moonlight

    # Save current project id

    # Get new id by incrementing the last one
    last_id=`cat ~/.config/mldev/last_project_id 2> /dev/null || echo 0`
    current_id=$((last_id + 1))
    echo "$current_id" > ~/.config/mldev/last_project_id

    echo $current_id > $2/mldev.meta

    # Build moonlight so binaries exist
    (cd $2/Moonlight; dotnet build)

    # Create new project
    dotnet new create moonlight.v2.plugintemplate --name $1 --output $2/source/

    # Save name
    echo $1 > $2/mldev.plugin.meta
}

pluginClone() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: mldev plugin clone <path> <repo url> (branch) (ml-branch)"
        echo "See https://docs.moonlightpanel.xyz for all commands"
        exit 1
    fi

    mkdir -p $1
    mkdir -p $1/source
    mkdir -p $1/Moonlight

    if [ -z "$3" ]; then
        branch="main"
    else
        branch=$3
    fi

    if [ -z "$4" ]; then
        mlBranch="v2"
    else
        mlBranch=$4
    fi

    git clone -b $mlBranch https://github.com/Moonlight-Panel/Moonlight $1/Moonlight

    # Save current project id

    # Get new id by incrementing the last one
    last_id=`cat ~/.config/mldev/last_project_id 2> /dev/null || echo 0`
    current_id=$((last_id + 1))
    echo "$current_id" > ~/.config/mldev/last_project_id

    echo $current_id > $1/mldev.meta

    # Build moonlight so binaries exist
    (cd $1/Moonlight; dotnet build)

    # Clone new project
    git clone -b $branch $2 $1/source/

    # Save name
    echo $2 > $1/mldev.plugin.meta
}

pluginRun() {
    if [ ! -f mldev.plugin.meta ]; then
        echo "You need to execute this command in the main directory of a plugin project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi

    name=`cat mldev.plugin.meta`

    (cd source; dotnet build)

    # Ensure plugins folders exist
    mkdir -p Moonlight/Moonlight/ApiServer/storage
    mkdir -p Moonlight/Moonlight/ApiServer/storage/plugins
    mkdir -p Moonlight/Moonlight/ApiServer/storage/clientPlugins

    # Remove old plugin files
    rm -r Moonlight/Moonlight/ApiServer/storage/plugins/*
    rm -r Moonlight/Moonlight/ApiServer/storage/clientPlugins/*

    # Copy build artifcats
    cp "source/$name.ApiServer/bin/Debug/net8.0/$name.ApiServer.dll" Moonlight/Moonlight/ApiServer/storage/plugins/
    cp "source/$name.ApiServer/bin/Debug/net8.0/$name.Shared.dll" Moonlight/Moonlight/ApiServer/storage/plugins/

    cp "source/$name.Client/bin/Debug/net8.0/$name.Client.dll" Moonlight/Moonlight/ApiServer/storage/clientPlugins/
    cp "source/$name.Client/bin/Debug/net8.0/$name.Shared.dll" Moonlight/Moonlight/ApiServer/storage/clientPlugins/

    # Copy additional artifcats

    if [ -f artifacts.server.meta ]; then
        copyItemsToDestination artifacts.server.meta "source/$name.ApiServer/bin/Debug/net8.0" Moonlight/Moonlight/ApiServer/storage/plugins/
    fi

    if [ -f artifacts.client.meta ]; then
        copyItemsToDestination artifacts.client.meta "source/$name.Client/bin/Debug/net8.0" Moonlight/Moonlight/ApiServer/storage/clientPlugins/
    fi

    (cd Moonlight; dotnet run --project Moonlight/ApiServer)
}

pluginPublish() {
    if [ ! -f mldev.plugin.meta ]; then
        echo "You need to execute this command in the main directory of a plugin project"
        echo "See https://docs.moonlightpanel.xyz/ for more details"
        exit 1
    fi

    name=`cat mldev.plugin.meta`

    (cd source; dotnet build)

    mkdir -p publish
    rm -r publish/*
    mkdir -p publish/client/
    mkdir -p publish/server/

    # Copy build artifcats
    cp "source/$name.ApiServer/bin/Debug/net8.0/$name.ApiServer.dll" publish/server/
    cp "source/$name.ApiServer/bin/Debug/net8.0/$name.Shared.dll" publish/server/

    cp "source/$name.Client/bin/Debug/net8.0/$name.Client.dll" publish/client/
    cp "source/$name.Client/bin/Debug/net8.0/$name.Shared.dll" publish/client/

    # Copy additional artifcats

    if [ -f artifacts.server.meta ]; then
        copyItemsToDestination artifacts.server.meta "source/$name.ApiServer/bin/Debug/net8.0" publish/server/
    fi

    if [ -f artifacts.client.meta ]; then
        copyItemsToDestination artifacts.client.meta "source/$name.Client/bin/Debug/net8.0" publish/client/
    fi
}

copyItemsToDestination() {
    while IFS= read -r file; do
        # Remove any leading/trailing whitespace
        file=$(echo "$file" | tr -d '[:space:]')

        # Skip empty lines
        if [ -z "$file" ]; then
            continue
        fi

        # Copy files from the folder to the destination
        cp "$2/$file" "$3"
    done < "$1"
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
    plugin)

        if [ "$command" == "create" ]; then
            pluginCreate $3 $4 $5
        elif [ "$command" == "run" ]; then
            pluginRun
        elif [ "$command" == "publish" ]; then
            pluginPublish
        elif [ "$command" == "clone" ]; then
            pluginClone $3 $4 $5 $6
        else
            echo "Unknown command '$command' in module '$module'"
        fi


        ;;
    db)

        if [ "$command" == "start" ]; then
            dbStart
        elif [ "$command" == "stop" ]; then
            dbStop
        elif [ "$command" == "restart" ]; then
            dbRestart
        elif [ "$command" == "delete" ]; then
            dbDelete
        else
            echo "Unknown command '$command' in module '$module'"
        fi

        ;;
    *)
        echo "Unknown module: '$module'"
        exit 1
        ;;
esac