#!/bin/bash

CURR_PATH=`pwd`
OPENRESTY_VERSION="openresty-1.21.4.1"
OPENRESTY_DIR=${CURR_PATH}/${OPENRESTY_VERSION}
NGX_STREAM_VERSION="ngx_stream_lua-0.0.11"

yum install -y perl-IPC-Cmd perl-Data-Dumper zlib zlib-devel pcre pcre-devel

if [ ! -f  /usr/local/lib64/pkgconfig/openssl.pc ];then
	tar -zxvf openssl-3.0.1.tar.gz
	cd openssl-3.0.1
	./config --prefix=/usr/local -fPIC shared
	make -j4 && make install
	cd $CURR_PATH
fi

tar -zxvf ${OPENRESTY_VERSION}.tar.gz

cp config/ngx_stream_lua_request.patch ${OPENRESTY_DIR}/bundle/${NGX_STREAM_VERSION}/src
cd ${OPENRESTY_DIR}/bundle/${NGX_STREAM_VERSION}/src
patch ngx_stream_lua_request.c < ngx_stream_lua_request.patch
rm -rf ngx_stream_lua_request.patch

cd ${OPENRESTY_DIR}
./configure --prefix=/usr/local/openresty \
	--with-cc-opt="-I/usr/local/include" \
	--with-ld-opt="-L/usr/local/lib64"

gmake -j4
gmake install

cd $CURR_PATH
cp -r config/mylua /usr/local/openresty/nginx/
cp config/nginx.conf /usr/local/openresty/nginx/conf/
cp config/lib/libgocommonlib.so /usr/local/openresty/lualib/
cp config/lib/libcrypto.so.3 /usr/local/openresty/luajit/lib/
cp config/lib/libssl.so.3 /usr/local/openresty/luajit/lib/
