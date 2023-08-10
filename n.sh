#!/usr/bin/env bash
#NVM_DIR=~/.nvm
#. ~/.nvm/nvm.sh

help() {
  local usage=" Explorer builder autoscript -h\n
	 Please try select any of these cmd - testnet,dx1\n

	 example\n

	 	testnet: sh build.sh testnet\n
	 production: sh build.sh dx1\n

	 skip upload: sh build.sh testnet -test\n
	 skip upload: sh build.sh dx1  -test\n
	 	try to help it out
	 "
  echo $usage
}

abort_program() {
  cd $BUILD_DIR
  rm -f $FILE
  exit
}
from_camalcase_to_underscore() {
  local valuable=$1
  local _c=$(
    cat <<EOF
import re
REG = r"(.+?)([A-Z])"
def snake(match):
  return match.group(1).lower() + "_" + match.group(2).lower()
print(re.sub(REG, snake, "$valuable", 0))
EOF
  )
  echo $(python3 -c "$_c")
}
rename_pyc_to_regular() {
  local path=$1
  local build="pycbuild"

  python3 -c "$_c"
}
#1: the full path
#2: the target location in the remote server
upload_file() {
  local file_size_kb=$(du -k "$1" | cut -f1)

  if [[ $file_size_kb -eq 0 ]]; then
    echo "⛔️ file is zero bytes..."
    abort_program
  fi

  scp $1 root@$LOCAL:$2

  if [ $? -eq 0 ]; then
    echo "✅ ==== upload successfully"
  # else
  #echo "⛔️ Error from uploading... $1"
  # abort_program
  fi

}

remotecmd() {
  local remote_cmd=$2
  ssh -t root@$LOCAL "cd $TARGET_LOC; bash; $remote_cmd"
}

directcmd() {
  ssh -t root@$LOCAL "cd $TARGET_LOC; ./build.sh"
}

mod_setting() {
  param_hk="$1 = \"$2\""
  #echo "$param_hk"
  cat $EXPLORER_SETTINGS | jq "$param_hk" -c $EXPLORER_SETTINGS | sponge $EXPLORER_SETTINGS
}

env_segment() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "mainnet"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    echo "testlocal"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
    echo "testlocal"
    # POSIX compatibility layer and Linux environment emulation for Windows
  elif [[ "$OSTYPE" == "msys" ]]; then
    # Windows
    echo "testlocal"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # ...
    echo "testlocal"
  fi
}

env_setting_file() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "settings_centos.json"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    echo "settings_local.json"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
    echo "settings_local.json"
    # POSIX compatibility layer and Linux environment emulation for Windows
  elif [[ "$OSTYPE" == "msys" ]]; then
    # Windows
    echo "settings_local.json"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # ...
    echo "settings_local.json"
  fi
}
linuxtools() {
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  #https://snapcraft.io/install/solc/centos
  sudo yum install rsync
}

writeremotesolc() {

  cat <<EOF >remotesolc
#!/bin/bash
if [[ ! -f $TARGET_LOC ]]; then
    mkdir -p $TARGET_LOC/vault
fi
if [[ ! -f $TARGET_LOC/build ]]; then
    mkdir -p $TARGET_LOC/build
fi
#chown -R www $TARGET_LOC/vault
cd $TARGET_LOC
echo "🍜 changed permission to root"
SOLC_VERSION=$SOLVER solc --version


echo "🍯 make compile trc20 coin"
SOLC_VERSION=$SOLVER solc --allow-paths $SOLCPATH -o build --bin --bin-runtime --abi --optimize --metadata --overwrite $COMPILE_COIN
echo "=> 🍺🍺🍺 TRC20 coin"


cd $TARGET_LOC/build && tar -czf $COMPRESSED_NAME *.*
mv $COMPRESSED_NAME $TARGET_LOC
rm -rf $TARGET_LOC/vault
rm -rf $TARGET_LOC/build
exit
EOF
}

#--combined-json abi,asm,ast,bin,bin-runtime,compact-format,devdoc,hashes,interface,metadata,opcodes,srcmap,srcmap-runtime,userdoc
mactools() {
  if ! command -v rsync &>/dev/null; then
    echo "rsync could not be found"
    brew install rsync
  fi
  if ! command -v abi-gen-uni &>/dev/null; then
    echo "abi-gen-uni could not be found"
    cnpm i -g easy-abi-gen
  fi
  if ! command -v cnpm &>/dev/null; then
    echo "abi-gen-uni could not be found"
    npm i -g cnpm
  fi
  if ! command -v abigen &>/dev/null; then
    echo "golang abigen could not be found"
    exit
  fi
  #NVM_VERSION=$(echo "$(node -v)" | grep -o -E '[0-9]{2}.')
  local NVM_VERSION=$(echo "$(node -v)" | cut -d. -f1)
  echo "==> 🈯️ all modules needed are completed."

  if [[ ${NVM_VERSION} == "v10" ]]; then
    echo "node version is on the right version : v10"
  else
    echo "please use the below command to switch to the right version of node"
    echo "nvm use 10"
    exit
  fi
  python3 -m compileall .
}
testline() {
  cat remotesolc | ssh root@$LOCAL /bin/bash
  echo "==> 🧃 solc compile checking process. solc version=${SOLVER}"
  rm remotesolc
}
endline() {
  cat remotesolc | ssh root@$LOCAL /bin/bash
  echo "==> 🈯️ download file from remote $TARGET_LOC"
  if [[ ! -f $BUILDPATH/build ]]; then
    mkdir -p $BUILDPATH/build
  fi
  cd $BUILDPATH
  rsync -avzhe ssh root@$LOCAL:$TARGET_LOC/$COMPRESSED_NAME $BUILDPATH
  rm remotesolc
  mv $BUILDPATH/$COMPRESSED_NAME $BUILDPATH/build
  cd "$BUILDPATH/build"
  tar -xvf $COMPRESSED_NAME
  rm $COMPRESSED_NAME
  echo "==> 🛃 solc process completed."
}

deploy_contract_wrapper_typescript() {
  echo "==> 🚸 compile abi to typescript"
  local outputfolder=$1
  local target_abi=$2
  if [[ ! -f $outputfolder ]]; then
    mkdir -p $outputfolder
  fi
  abi-gen-uni --abibins "$target_abi" --out "$outputfolder" \
    --partials "$BUILDPATH/abi_templates/TypeScriptTron/partials/*.handlebars" \
    --template "$BUILDPATH/abi_templates/TypeScriptTron/contract.handlebars" \
    --backend "webtron" \
    --language "TypeScript"
  echo "==> compile abi to typescript 🚸✅"
}

deploy_contract_wrapper_python() {
  local outputfolder=$1
  local target_abi=$2

  if [[ ! -f $outputfolder ]]; then
    mkdir -p $outputfolder
  fi

  echo "==> 🚸 compile abi to python: $target_abi / $outputfolder"
  abi-gen-uni --abibins $target_abi --out "$outputfolder" \
    --partials "$BUILDPATH/abi_templates/PythonTron/partials/*.handlebars" \
    --template "$BUILDPATH/abi_templates/PythonTron/contract.handlebars" \
    --language "Python"
  echo "==> compile abi to python 🚸✅"
}

deploy_contract_wrapper_go() {
  echo "==> 🚸 compile abi to golang"
  local SOL=$1
  local CLASSNAME=$2
  local GO_CONTRACT_SRC_PATH=$3
  if [[ ! -f $GO_CONTRACT_SRC_PATH/$CLASSNAME ]]; then
    mkdir -p "$GO_CONTRACT_SRC_PATH/$CLASSNAME"
  fi
  abigen --abi "$BUILDPATH/build/$CLASSNAME.abi" --pkg $CLASSNAME --out "$GO_CONTRACT_SRC_PATH/$CLASSNAME/init.go"
  echo "==> compile abi to golang 🚸✅"
}

deploy_codebase_wrapper() {
  local CLASSNAME=$1
  deploy_contract_wrapper_python "$BUILDPATH/codec/gen_py" "$BUILDPATH/build/$CLASSNAME.abi"
  #deploy_contract_wrapper_typescript "$BUILDPATH/codec/gen_ts" "$BUILDPATH/build/$CLASSNAME.abi"
  #deploy_contract_wrapper_go "$BUILDPATH/vault/fendix/$CLASSNAME.sol" $CLASSNAME "$BUILDPATH/codec/gen_go"
}
deploy_py_backend() {
  python3 -m compileall .
  local pycfolder="$PWD/__pycache__"
  #rename_pyc_to_regular $pycfolder
}
# Accepts a version string and prints it incremented by one.
# Usage: increment_version <version> [<position>] [<leftmost>]
increment_version() {
  declare -a part=(${1//\./ })
  declare new
  declare -i carry=1

  for ((CNTR = ${#part[@]} - 1; CNTR >= 0; CNTR -= 1)); do
    len=${#part[CNTR]}
    new=$((part[CNTR] + carry))
    [ ${#new} -gt $len ] && carry=1 || carry=0
    [ $CNTR -gt 0 ] && part[CNTR]=${new: -len} || part[CNTR]=${new}
  done
  new="${part[*]}"
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${new// /.}"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "${new// /.}"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
    echo "not correct system - cygwin detected"
    exit
  fi

}
preinstall() {
  npm install -g dts-gen
  npm install typescript --save-dev
  pip3 install git+git://github.com/psf/black
}
mod_package_json() {
  param_chan=$(echo "$1 = \"$2\"")
  echo "$param_chan"
  cat $NODEPFILE | jq "$param_chan" $NODEPFILE | sponge $NODEPFILE
}
auto_install_nvm() {
  # shellcheck disable=SC2077
  if [[ $auto_install == 1 ]]; then
    $CMD_FINAL
  fi
}
gitconnectiontest() {
  ssh -Tvvv git@gitlab.com
  ssh -T git@gitlab.com
}
fixmessedupgit() {
  git rm -r --cached .
  git add .
  git commit -am 'git cache cleared'
  git push
}
gitpush() {
  local gitcheck=$(git diff --shortstat)
  git add .
  #git remote add origin ${GIT_LOC}.git
  git commit -m "check point! ${gitcheck}"
  git push
  echo "♻️ You can open ${GIT_LOC} or git clone ${GIT_LOC}.git to copy to the local"
}

backup_deploy() {
  cd $BUILDPATH
  declare folder_name="deploy_history/v$(cat version)"
  declare folder_build="deploy_history/v$(cat version)/build"
  declare folder_vault="deploy_history/v$(cat version)/vault"
  #this is awesome and already to go now
  if [[ ! -f $folder_name ]]; then
    mkdir -p "$folder_name"
    mkdir -p "$folder_build"
    mkdir -p "$folder_vault"
  fi
  cp deploy_results/*.* $folder_name
  cp build/*.* $folder_build
  cp -R vault $folder_vault
}
# the file
wrapcodebase() {
  deploy_codebase_wrapper "BSend"
}

# the files to compile
COMPILE_COIN="vault/multisend/BSend.sol"
SOLVER=0.5.15
#
# LOCAL MACHINE ONLY the default path
BUILDPATH=$HOME/Documents/b95/trc20
BUILD_DIR=$HOME/Documents/b95/trc20/build
