#!/bin/bash

set -e

source scripts/backoff.sh

# make sure this script is run by rootlesskit
if [ -z "${ROOTLESSKIT_PARENT_EUID:-}" ]; then
    echo "This script must be run by rootlesskit"
    exit 1
fi

ROCKS_CONFIG=$(mktemp)
echo "
rocks_trees = {
   { name = [[system]], root = [[/tmp/build/usr/local]] }
}
" > $ROCKS_CONFIG

rm -rf /usr/local || true
cp -Rf /tmp/build/usr/local/* /usr/local || true

export LUAROCKS_CONFIG=$ROCKS_CONFIG
export LUA_PATH="/usr/local/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;;"
export PATH=$PATH:/usr/local/openresty/luajit/bin

/usr/local/bin/luarocks --version
/usr/local/kong/bin/openssl version || true
ldd /usr/local/openresty/nginx/sbin/nginx || true
strings /usr/local/openresty/nginx/sbin/nginx | grep rpath || true
strings /usr/local/openresty/bin/openresty | grep rpath || true
find /usr/local/kong/lib/ || true
/usr/local/openresty/bin/openresty -V || true

ROCKSPEC_VERSION=`basename kong-*.rockspec` \
&& ROCKSPEC_VERSION=${ROCKSPEC_VERSION%.*} \
&& ROCKSPEC_VERSION=${ROCKSPEC_VERSION#"kong-"}

mkdir -p /tmp/plugin

if [ "$SSL_PROVIDER" = "boringssl" ]; then
    sed -i 's/fips = off/fips = on/g' kong/templates/kong_defaults.lua
fi

with_backoff /usr/local/bin/luarocks make kong-${ROCKSPEC_VERSION}.rockspec \
CRYPTO_DIR=/usr/local/kong \
OPENSSL_DIR=/usr/local/kong \
YAML_LIBDIR=/tmp/build/usr/local/kong/lib \
YAML_INCDIR=/tmp/yaml \
EXPAT_DIR=/usr/local/kong \
LIBXML2_DIR=/usr/local/kong \
CFLAGS="-L/tmp/build/usr/local/kong/lib -Wl,-rpath,/usr/local/kong/lib -O2 -std=gnu99 -fPIC"

mkdir -p /tmp/build/etc/kong
cp -Lf kong.conf.default /tmp/build/usr/local/lib/luarocks/rock*/kong/$ROCKSPEC_VERSION/
cp -Lf kong.conf.default /tmp/build/etc/kong/kong.conf.default

# /usr/local/kong/include is usually created by other C libraries, like openssl
# call mkdir here to make sure it's created
if [ -e "kong/include" ]; then
    mkdir -p /tmp/build/usr/local/kong/include
    cp -Lrf kong/include/* /tmp/build/usr/local/kong/include/
fi

# circular dependency of CI: remove after https://github.com/Kong/kong-distributions/pull/791 is merged
if [ -e "kong/pluginsocket.proto" ]; then
    cp -Lf kong/pluginsocket.proto /tmp/build/usr/local/kong/include/kong
fi

with_backoff curl -fsSLo /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.19.0/protoc-3.19.0-linux-x86_64.zip
unzip -o /tmp/protoc.zip -d /tmp/protoc 'include/*'
cp -rf /tmp/protoc/include/google /tmp/build/usr/local/kong/include/

cp COPYRIGHT /tmp/build/usr/local/kong/
cp bin/kong /tmp/build/usr/local/bin/kong
sed -i 's/resty/\/usr\/local\/openresty\/bin\/resty/' /tmp/build/usr/local/bin/kong
sed -i 's/\/tmp\/build//g' /tmp/build/usr/local/bin/openapi2kong || true
grep -l -I -r '\/tmp\/build' /tmp/build/
sed -i 's/\/tmp\/build//' `grep -l -I -r '\/tmp\/build' /tmp/build/`

# chown -R 1000:1000 /tmp/build/*

# bytecompile if script is present (as with ee)
if test -f "/distribution/post-bytecompile.sh"; then
  distribution/post-bytecompile.sh
fi

# add copyright manifests if script is present (as with ee)
if test -f "/distribution/post-copyright-manifests.sh"; then
  distribution/post-copyright-manifests.sh
fi
