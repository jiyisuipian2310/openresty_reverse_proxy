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
    ngx_connection_t *c = r->connection;
    if(c->buffer == NULL || c->buffer->pos >= c->buffer->last) {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0, "ngx_stream_lua_remove_bytes, c->buffer == NULL or c->buffer->pos >= c->buffer->last");
        return;
    }

    if(flag > 0) {
        ngx_log_error(NGX_LOG_INFO, r->connection->log, 0, "ngx_stream_lua_remove_bytes, proxyData: %*s, remove length: %d",
            c->buffer->last - c->buffer->pos,
            c->buffer->pos,
            length);
    }
    c->buffer->pos += length;
}

void ngx_stream_lua_add_custom_message(ngx_stream_lua_request_t *r, const unsigned char *custom_msg, size_t custom_msg_len, int flag)
{
    ngx_connection_t *c = r->connection;
    if (c->buffer == NULL || c->buffer->pos >= c->buffer->last) {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0, "ngx_stream_lua_add_custom_message, c->buffer == NULL or c->buffer->pos >= c->buffer->last");
        return;
    }

    //获取原始数据
    u_char *orig_data = c->buffer->pos;
    size_t orig_len = c->buffer->last - c->buffer->pos;

    //创建新缓冲区
    ngx_buf_t *new_buf = ngx_create_temp_buf(r->pool, custom_msg_len + orig_len);
    if (new_buf == NULL) {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0, "ngx_stream_lua_add_custom_message, ngx_create_temp_buf failed");
        return;
    }

    //构建新数据
    u_char *p = new_buf->pos;
    p = ngx_copy(p, custom_msg, custom_msg_len);
    p = ngx_copy(p, orig_data, orig_len);
    new_buf->last = p;

    //重要：更新连接中的缓冲区
    c->buffer = new_buf;
    if(flag > 0) {
        ngx_log_error(NGX_LOG_INFO, r->connection->log, 0, "ngx_stream_lua_add_custom_message, new message: %*s",
            c->buffer->last - c->buffer->pos, c->buffer->pos);
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

