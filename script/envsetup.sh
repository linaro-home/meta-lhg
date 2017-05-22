#!/bin/bash -
_BUILDDIR=build
_FORCE_MACHINE_CHOICE=0


######################################################
# FUNCTION / ALIAS
# --
#

######################################################
# Envsetup help
lofoe_help() {
    cat <<EOF

    Usage: [MACHINE=<MACHINE>] source $BASH_SOURCE [--change] [BUILDDIR]
    If no MACHINE is set, list all possible machines, and ask user to choose.

EOF
    echo "=================================================="
    echo "List of action available:"
    echo "  --change : allow user to update configuration files"
    echo "  --help   : display this help"
    echo "  BUILDDIR : provide specific build folder (default is 'build')"
    echo ""
    echo "LOF OE Utilities"
    echo "  oe_list_images        : list all images available"
    echo "  oe_list_tasks <pack>  : list all tasks"
    echo ""
    echo "=================================================="
    echo "List of environment variables available:"
    echo "  LOF_OE_ROOT_DIR          = $LOF_OE_ROOT_DIR"
    echo "  LOF_OE_BUILD_DIR         = $LOF_OE_BUILD_DIR"
    echo "  LOF_OE_DL_DIR            = $LOF_OE_DL_DIR"
    echo ""
}

######################################################
# alias function: set all environment variables
#
lofoe_set_env() {
    export LOF_OE_ROOT_DIR=$(readlink -f -- "$PWD/")
    export LOF_OE_BUILD_DIR=$LOF_OE_ROOT_DIR/$_BUILDDIR
    export LOF_OE_DL_DIR=$HOME/Public/oe-downloads
}

######################################################
# extract description for images provided
_lofoe_list_images_descr() {
    for l in $1;
    do
        local image=`echo $l | sed -e 's#^.*/\([^/]*\).bb$#\1#'`
        if [ ! -z "$(grep "^SUMMARY[ \t]*=" $l)" ]
        then
            local descr=`grep "^SUMMARY[ \t]*=" $l | sed -e 's/^.*"\(.*\)["\]$/\1/'`
        else
            local descr=`grep "^DESCRIPTION[ \t]*=" $l | sed -e 's/^.*"\(.*\)["\]$/\1/'`
        fi
        if [ -z "$descr" ] && [ "$2" == "ERR" ]
        then
            echo ""
            echo "ERROR: No description available for image: $image"
            echo "$l"
            echo ""
            return 1
        else
            printf "    %-33s  -   $descr\n" $image
        fi
    done
}

######################################################
# list_image for meta-linaro
_lofoe_list_images_linaro() {
    if [[ -d $LOF_OE_ROOT_DIR/meta-linaro ]]; then
        local LIST=`find $LOF_OE_ROOT_DIR/meta-linaro -wholename "*/images/*.bb" | sort`
        echo ""
        echo "=================================================="
        echo "Linaro targets are:"
        echo ""
        _lofoe_list_images_descr "$LIST"
    fi
}

######################################################
# list_image for openembedded-core
_lofoe_list_images_openembedded() {
    if [[ -d $LOF_OE_ROOT_DIR/openembedded-core ]]; then
        local LIST=`find $LOF_OE_ROOT_DIR/openembedded-core -wholename "*/images/*.bb" | grep -v meta-skeleton | sort`
        echo ""
        echo "=================================================="
        echo "Openembedded targets are:"
        echo ""
        _lofoe_list_images_descr "$LIST"
    fi
}

######################################################
# list_image for meta-st
_lofoe_list_images_meta_lof() {
    if [ -e "$LOF_OE_ROOT_DIR/meta-lhg" ];
    then
        local LIST=`find $LOF_OE_ROOT_DIR/meta-lhg/* -wholename "*/images/*.bb" | sort`
        echo ""
        echo "=================================================="
        echo "LOF images for machine \"$MACHINE\" are:"
        echo ""
        _lofoe_list_images_descr "$LIST" "ERR"
    fi
}

######################################################
# alias function: list all images available
#
lofoe_list_images() {
#    _lofoe_list_images_linaro
    _lofoe_list_images_openembedded
    _lofoe_list_images_meta_lof
    if [ $? == "0" ]
    then
        echo ""
        echo "You can now run 'bitbake <image>'"
        echo ""
    fi
}

######################################################
# alias function: list task of specific package via bitbake
#
lofoe_list_tasks() {
    if [ $# -eq 1 ];
    then
        _PACKAGE=$1
        echo "List of Task for $1:"
        bitbake -c listtasks $_PACKAGE | grep "^do" | sed -e "s/do_/  /"
    else
        echo "[ERROR]: bad number of argument"
        echo "[USAGE]: oe_list_tasks <package>"

    fi
}

######################################################
# Check if need to reset previous config files
#
_lofoe_update_conf() {
    # List all possible machines, and ask user
    echo -n "Do you want to remove actual config files ? [y/N]  "
    read answer

    if [ -z "$answer" ];
    then
        answer='N'
    fi

    if [ "$answer" == "y" ] || [ "$answer" == "Y" ];
    then
        echo ""
        echo "Removing current config in $LOF_OE_ROOT_DIR/$_BUILDDIR/conf ..."
        rm -fv $LOF_OE_ROOT_DIR/$_BUILDDIR/conf/*.conf
        echo ""
    elif [ "$answer" == "n" ]  || [ "$answer" == "N" ];
    then
        echo ""
        echo "Keeping current config in $LOF_OE_BUILD_DIR/conf ..."
        echo ""
    else
        echo "Invalid choice" $answer
        return 1
    fi
    unset answer
}

######################################################
# Check if script is sourced as expected
#
_verify_env() {
    local  __resultvar=$1
    if [ "$0" = "$BASH_SOURCE" ]; then
        echo "###################################"
        echo "ERROR: YOU MUST SOURCE the script"
        echo "###################################"
        if [[ "$__resultvar" ]]; then
            eval $__resultvar="ERROR_SOURCE"
        fi
        return
    fi
    # check that we are not root!
    if [ "$(whoami)" = "root" ]; then
        echo -e "\nERROR: do not use the BSP as root. Exiting..."
        if [[ "$__resultvar" ]]; then
            eval $__resultvar="ERROR_ROOT"
        fi
        return
    fi

    # check that we are where we think we are!
    oe_tmp_pwd=`pwd`
    oe_tmp_open=$oe_tmp_pwd/openembedded-core
    if [ ! -d $oe_tmp_open ];
    then
        echo "PLEASE launch the envsetup script at root tree of your oe sdk"
        echo ""
        oe_tmp_root=$oe_tmp_pwd
        while [ 1 ];
        do
            oe_tmp_root=`dirname $oe_tmp_root`
            if [ "$oe_tmp_root" == "/" ];
            then
                echo "[WARNING]: you try to launch the script outside oe sdk tree"
                break;
            fi
            if [ -d $oe_tmp_root/openembedded-core ];
            then
                echo "Normally at this location: $oe_tmp_root"
                break;
            fi
        done
        if [[ "$__resultvar" ]]; then
            eval $__resultvar="ERROR_OE"
        fi
        return
    fi
    if [[ "$__resultvar" ]]; then
        eval $__resultvar="NOERROR"
    fi
}

######################################################
# Apply configuration to local.conf file
#
conf_localconf()
{
    _NCPU=$(grep '^processor' /proc/cpuinfo 2>/dev/null | wc -l)
    # Sanity check that we have a valid number, if not then fallback to a safe default
    [ "$_NCPU" -ge 1 ] 2>/dev/null || _NCPU=2

    #change DL_DIR
    sed -e "s;##DL_DIR##;$LOF_OE_DL_DIR;g" -i conf/local.conf

    #change CPU number
    sed -e "s/##CPU##/$_NCPU/g" -i conf/local.conf

    #change machine
    sed -e "s/##MACHINE##/$MACHINE/g" -i conf/local.conf

}
######################################################
# Apply configuration to bblayer.conf file
#
conf_bblayerconf()
{
    local machine_path=`find $LOF_OE_ROOT_DIR/meta-* -name "$MACHINE.conf" | sed "s#/conf/machine/$MACHINE.conf##" | sed "s#$LOF_OE_ROOT_DIR/##"`
    local specific_machine=$(grep '$machine_path' conf/bblayers.conf)
    if [ -z $specific_machine ];
    then
    cat >> conf/bblayers.conf <<EOF

# specific to machine
BBLAYERS =+ "\${OEROOT}/$machine_path"

EOF
    fi
}

######################################################
# select MACHINE
#
select_machine() {
    # List all possible machines, and ask user
    echo "[Machine configuration]"
    local options=$(find $LOF_OE_ROOT_DIR/ -print | grep "conf/machine/[^\/]*\.conf" | grep -v scripts | grep -v openembedded-core | grep -v meta-linaro | sed -e 's/\.conf//g' | awk -F'/' '{print $NF "(" $2 ")"}' | sort | uniq)
    local len_options=$(echo "$options" | wc -l)
    if [ $len_options -eq 1 ];
    then
        MACHINE="$(echo $options | cut -d'(' -f1) $(echo $ITEM | cut -d'(' -f2 | cut -d')' -f1)"
    else
        PS3="Please enter your choice of machine (1-$len_options): "
        #change separator from 'space' to 'end of line' for 'select' command
        old_IFS=$IFS
        IFS=$'\n'
        select opt in $options
        do
            if [ -z "$opt" ]; then
                echo "Invalid choice"
            else
                #MACHINE=$(echo $opt | cut -d' ' -f1)
                MACHINE="$(echo $options | cut -d'(' -f1) $(echo $ITEM | cut -d'(' -f2 | cut -d')' -f1)"
                break;
            fi
        done
        IFS=$old_IFS
        unset PS3
    fi
    echo ""
    MACHINE=$(echo -n $MACHINE | sed 's/ //')
}

######################################################
# toolchain
TOOLCHAIN_NAME=gcc-linaro-arm-linux-gnueabihf-4.8-2014.04_linux
verify_toolchain() {
    if [ -d $LOF_OE_ROOT_DIR/toolchain/$TOOLCHAIN_NAME/ ];
    then
        echo "Secondary toolchain already installed."
    else
        mkdir -p $LOF_OE_ROOT_DIR/toolchain/
        wget https://releases.linaro.org/14.04/components/toolchain/binaries/$TOOLCHAIN_NAME.tar.bz2 -O $LOF_OE_ROOT_DIR/toolchain/$TOOLCHAIN_NAME.tar.bz2
        tar xf $LOF_OE_ROOT_DIR/toolchain/$TOOLCHAIN_NAME.tar.bz2 -C $LOF_OE_ROOT_DIR/toolchain/
    fi
    export PATH=$LOF_OE_ROOT_DIR/toolchain/$TOOLCHAIN_NAME/bin/:$PATH
}

######################################################
# Main
# --
#

_verify_env ret
case $ret in
    ERROR_OE | ERROR_ROOT | ERROR_SOURCE)
        if [ "$0" != "$BASH_SOURCE" ]; then
            return 1
        else
            exit 1
        fi
        ;;
    *)
        ;;
esac

#----------------------------------------------
# parsing options
#
while test $# != 0
do
    case "$1" in
    --help)
        lofoe_help
        if [ "$0" != "$BASH_SOURCE" ]; then
            return 1
        else
            exit 1
        fi
        ;;
    --change)
        _FORCE_MACHINE_CHOICE=1
        ;;
    *)
        #change buildir directory
        _BUILDDIR=$1
        ;;
    esac
    shift
done

lofoe_set_env

verify_toolchain

if [ -d "$LOF_OE_ROOT_DIR/$_BUILDDIR" ]; then
    # check if this build-$MACHINE folder was already configured
    if [ -f ${_BUILDDIR}/conf/local.conf ] && \
        [ -f ${_BUILDDIR}/conf/bblayers.conf ]; then
        _CONFIGS_FOUND="yes"
    fi
fi

#echo "[DEBUG] _CONFIGS_FOUND=$_CONFIGS_FOUND"
#echo "[DEBUG] MACHINE=$MACHINE"
#echo "[DEBUG] _FORCE_MACHINE_CHOICE=$_FORCE_MACHINE_CHOICE"
#echo "[DEBUG] _BUILDDIR=$_BUILDDIR"

if [ "$_CONFIGS_FOUND" ]; then
    echo -e "\nConfig files already exist in folder ${_BUILDDIR}/conf/ "
    echo ""
    if [ $_FORCE_MACHINE_CHOICE -eq 1 ];
    then
        _lofoe_update_conf
    fi
fi

if [ ! -f $LOF_OE_ROOT_DIR/$_BUILDDIR/conf/local.conf ];
then
    if [ -z $MACHINE ];
    then
        select_machine
        test "$?" == "1" && return
    fi
    echo "[source openembedded-core/oe-init-build-env][from nothing]"
    echo ""
    #there is no config present: make a basic init
    TEMPLATECONF=$LOF_OE_ROOT_DIR/meta-lhg/conf source $LOF_OE_ROOT_DIR/openembedded-core/oe-init-build-env ${_BUILDDIR} > /dev/null 2> /dev/null

    #change local.conf
    conf_localconf
    conf_bblayerconf
else
    echo "[source openembedded-core/oe-init-build-env][with previous config]"
    echo ""
    TEMPLATECONF=$LOF_OE_ROOT_DIR/meta-lhg/conf source $LOF_OE_ROOT_DIR/openembedded-core/oe-init-build-env ${_BUILDDIR} > /dev/null 2> /dev/null

    if [ $_FORCE_MACHINE_CHOICE -eq 1 ];
    then
        if [ -z $MACHINE ];
        then
            select_machine
            test "$?" == "1" && return
        fi
        sed -e 's;^MACHINE = .*$;MACHINE = \"##MACHINE##\";g' -i conf/local.conf
        conf_localconf
        conf_bblayerconf
    else
        MACHINE=$(grep ^MACHINE conf/local.conf | sed -e 's/MACHINE[ \t]*=[ \t]*"\([^"]*\)"/\1/')
        _NCPU=$(grep ^BB_NUMBER_THREADS conf/local.conf | sed -e 's/BB_NUMBER_THREADS[ \t?]*=[ \t]*"\([^"]*\)"/\1/')
    fi
fi

DISTRO=$(grep "DISTRO" conf/local.conf | sed -e 's/DISTRO ?= //' | sed -e 's/"//' | sed -e 's/"//')

echo "=================================================="
cat <<EOF
Configuration files have been created for the following configuration:

    DISTRO            : $DISTRO
    MACHINE           : $MACHINE

EOF

# List images
lofoe_list_images

# Since this script is sourced, be careful not to pollute caller's environment with temp variables
unset -f usage
unset _BUILDDIR _CONFIGS_FOUND  MACHINE _NCPU  PS3 _FORCE_MACHINE_CHOICE
#set +x
