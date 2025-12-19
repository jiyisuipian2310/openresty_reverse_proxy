# openresty_reverse_proxy

```C++
反向代理说明：
1. 在stream模块的preread阶段读取自定义的代理数据，获取其中的目标ip和端口，然后通过ngx.balancer模块中的set_current_peer方法和后端建立连接
    
2. 自定义的代理数据格式如下：
    proxy + 2个字节的长度 + json字符串， 其中 2个字节的长度 表示的是json字符串的长度，不包含长度本身
    
3. json字符串 可以是明文的也可以是AES加密的，不同的监听端口对应json字符串的明文数据和密文数据
    
4. 通过打补丁的方式，在 ngx_stream_lua-0.0.11 模块的 ngx_stream_lua_request.c 文件中添加了如下函数：
void ngx_stream_lua_remove_bytes(ngx_stream_lua_request_t *r, int length, int flag)
{
    ngx_connection_t *c;
    c = r->connection;
    if(c->buffer == NULL) {
        if(flag) {
            ngx_log_error(NGX_LOG_INFO, r->connection->log, 0, "ngx_stream_lua_remove_bytes c->buffer == NULL");
        }
    }
    else {
        if(flag) {
            ngx_log_error(NGX_LOG_INFO, r->connection->log, 0, "ngx_stream_lua_remove_bytes, proxyData: %*s", length, c->buffer->pos);
        }
        c->buffer->pos += length;
    }
}
```

```C++
源码编译说明
源码编译 openresty, 需要依赖于 openssl; openresty 将 openssl 嵌入到程序中有两种方式：

1. build-with-lib.sh 
   先将 openssl 编译成动态库， 然后编译 openresty 时依赖于动态库，
   这样编译出来的 nginx 比较小

2. build-with-source.sh 
   编译 openresty 时，添加 --with-openssl=../openssl-3.0.1 选项,
   直接以源码的方式使用openssl库，这样编译出来的 nginx 比较大
```

```C++
补丁文件说明：
生成 patch(补丁) 文件
	diff ngx_stream_lua_request.c ngx_stream_lua_request_modify.c > ngx_stream_lua_request.patch
	
将 ngx_stream_lua_request.patch 文件拷贝到 ngx_stream_lua_request.c 文件所在的目录
	
打补丁， 进入到 ngx_stream_lua_request.c 文件所在的目录：
	patch ngx_stream_lua_request.c < ngx_stream_lua_request.patch

```

