
# Install packages

install_packages () {
    mkdir -p /tmp/setup
    while [ "$1" != '' ]; do
        package="$1"
        ${package_status} $package | grep -q "installed"
        if [ $? -ne 0 ]; then
            echo "Installing $package"
            ${package_install} $package 1> /tmp/setup/install.$package 2> /tmp/setup/install.${package}.err || \
                die "Failed to install $package"
        else
            echo "Already installed $package"
        fi
        shift
    done
}

remote_install_packages () {
    mkdir -p /tmp/setup
    while [ "$1" != '' ]; do
        package="$1"
        $SSH "${package_status} $package" | grep -q "installed"
        if [ $? -ne 0 ]; then
            echo "Installing $package"
            $SSH "${package_install} $package" 1> /tmp/setup/install.$package 2> /tmp/setup/install.${package}.err || \
                die "Failed to install $package"
        else
            echo "Already installed $package"
        fi
        shift
    done
}

# Check model and version
check_model () {
    if [ -f /etc/openwrt_release ]; then
        ubus call system board | grep model | grep -q "$MODEL"
        result=$?
        cat /etc/openwrt_release > /tmp/openwrt_release
    else
        $SSH ubus call system board | grep model | grep -q "$MODEL"
        result=$?
        $SSH cat /etc/openwrt_release > /tmp/openwrt_release
    fi
    [ $result -ne 0 ] && die "This does not appear to be a $MODEL"
    source /tmp/openwrt_release
    fw="openwrt-${DISTRIB_RELEASE}-qualcommax-ipq807x-linksys_$model-squashfs-factory.bin"
    echo "$MODEL detected."
    echo "OpenWRT version ${DISTRIB_RELEASE}"
    echo
}



check_model

source /tmp/openwrt_release

MAJOR_VERSION="${DISTRIB_RELEASE%%.*}"

case $MAJOR_VERSION in
    '24')
        echo "Detected OpenWRT $DISTRIB_RELEASE"
        package_update='opkg update'
        package_install='opkg install'
        package_status='opkg status'
        ;;
    '25')
        echo "Detected OpenWRT $DISTRIB_RELEASE"
        package_update='apk update'
        package_install='apk add'
        package_status='apk list'
        ;;
    *)
        die "Could not detect OpenWRT version"
        exit 1
        ;;
esac

