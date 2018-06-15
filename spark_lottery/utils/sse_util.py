#!/usr/bin/env python
# -*- coding: utf-8 -*-
import logging
import json
from abc import ABCMeta, abstractproperty
from sse import Sse
from redis.client import PubSub
from tornado import web, gen
from tornado.options import options, define
from tornado.httpserver import HTTPServer
from tornado.ioloop import IOLoop

logger = logging.getLogger("sse")

def build_sse_msg(message, event=None, id_=None):
    sse = Sse()
    if id_:
        sse.set_event_id(id_)
    sse.add_message(event, message)
    sse_msg = "".join(sse)
    print("YYYYYYYYYYY: {}".format(sse_msg))
    return sse_msg

class SSEModule(PubSub):
    """Module PubSub class"""
    def __init__(self,
                 connection_pool,
                 shard_hint=None,
                 ignore_subscribe_messages=False):
        self.fd = None
        super(self.__class__, self).__init__(connection_pool, shard_hint, ignore_subscribe_messages)

    def on_connect(self, connection):

        super(self.__class__, self).on_connect(connection)
        self.fd = connection._sock
        io_loop = IOLoop.current()
        io_loop.add_handler(connection._sock, self.loop_callback, IOLoop.READ)
        logger.debug("add ioloop socket fileno: %s", self.fd.fileno())

    def loop_callback(self, fd, events):
        """Deail with subscribe messages"""
        self.callback()

    def set_handler(self, handler):
        """
        set the sse request handler
        """
        self.handler = handler

    def callback(self):
        # result = {"id": id, "event": xxx, message: {"a":1, "b": 2}}
        message = self.get_message()
        data = message["data"]
        if isinstance(data, int):
            return
        data = json.loads(data)
        message = data["message"]
        message = json.dumps(data["message"])
        event = data["event"]
        id_ = data.get("id")

        sse_msg = build_sse_msg(message, event, id_)

        if not self.handler.is_alive:
            logger.debug("stream closed, remove handler from ioloop")
            io_loop = IOLoop.current()
            io_loop.remove_handler(self.fd)
        else:
            logger.debug("call callback, now send message: {}".format(sse_msg))
            self.handler.send_message(sse_msg)

class SSEHandler(web.RequestHandler):
    """
    usage: just inherite the class and define the redis_pool method with `@property`
    example:
        ```
        class TestHandler(SSEHandler):
            @property
            def redis_pool(self):
                return redis_util.get_pool()
        ```
    """
    __metaclass__ = ABCMeta
    CHANNEL = "sse"

    def __init__(self, application, request, **kwargs):
        super(SSEHandler, self).__init__(application, request, **kwargs)
        self.sub_obj = None
        self.stream = request.connection.stream


    def prepare(self):
        SSE_HEADERS = (
            ('Content-Type','text/event-stream; charset=utf-8'),
            ('Cache-Control','no-cache'),
            ('Connection','keep-alive'),
            ('X-accel-Buffering', 'no'),
            ('Access-Control-Allow-Origin', '*'),
        )
        for name, value in SSE_HEADERS:
            self.set_header(name, value)

    @abstractproperty
    def redis_pool(self):
        """
        this property will be supplied by the inheriting classes individually
        """
        pass

    @property
    def is_alive(self):
        return not self.stream.closed()

    @gen.coroutine
    def get(self, *args, **kwargs):
        channels = self.get_argument("channels")
        if not channels:
            raise Exception("channels shoud in url arguments")
        channels = channels.split(",")
        sub_obj = SSEModule(self.redis_pool)
        sub_obj.set_handler(self)
        sub_obj.subscribe(*channels)
        self.sub_obj = sub_obj
        # send message when on open, when use nginx, on_open will not work in js
        msg = build_sse_msg(message="ok", event="on_open")
        self.send_message(msg)
        while self.is_alive:
            yield gen.sleep(1000)
        del sub_obj

    def send_message(self, message):
        self.write(message)
        self.flush()


    def on_connection_close(self):
        # unsubscribe when close the connection
        self.sub_obj.unsubscribe()
        self.stream.close()

class SseSender(object):
    def __init__(self, redis, channel="sse"):
        """
        redis 的发布
        channel: 要发布的频道
        """
        self.redis = redis
        self.channel = channel
        self.send_num = 0

    def send(self, event, data, id=""):
        """
        event: sse数据格式中的event
        data: 要发送的数据
        """
        data_ = {"event": event, "message": data, "id":id}
        send_num = self.redis.publish(self.channel, json.dumps(data_))
        self.send_num = send_num
        logger.info("sender channel({}), event: {}, send_num: {}, data: {}".format(self.channel, event, send_num, data))

if __name__ == "__main__":
    import redis
    html = """
    <div id="messages"></div>
    <script type="text/javascript">
        if(EventSource == "undefined") {
            alert("sse not support!");
        }
        var sse = new EventSource('/events?channels=test');
        sse.addEventListener('ping', function(e) {
            console.log(e.id, e.data);
            var div = document.getElementById("messages");
            div.innerHTML = e.data + "<br>" + div.innerHTML;
        }, false);
        sse.addEventListener('on_open', function(e) {
            console.log(e.id, e.data);
            var div = document.getElementById("messages");
            div.innerHTML = e.data + "<br>" + div.innerHTML;
        }, false);

        //  default event type is "message"
        sse.onmessage = function(e) {
            // console.log(e.id, e.data);
            var div = document.getElementById("messages");
            console.log("xxxxxxxxxxxxxxxx")
            console.log(e.id, e.data);

          if (event.id == 'CLOSE') {
            sse.close();
          }
        };

        // on open
        sse.onopen = function () {
          console.log("sse open!")
        };

        sse.onerror = function () {
          console.log("sse closed!")
        };

    </script>"""
    class THandler(SSEHandler):
        @property
        def redis_pool(self):
            pool = redis.ConnectionPool(
                host="localhost",
                port="6379",
                # password="cljslrl0620",
                db=0)
            return pool

    class MainHandler(web.RequestHandler):
        def get(self):
            self.write(html)

    define("port", default=9000, help="run on the given port", type=int)

    def run_server():
        options.parse_command_line()

        app = web.Application(
            [
                (r'/', MainHandler),
                (r'/events', THandler)
            ],
            debug=True
        )
        server = HTTPServer(app)
        server.listen(options.port)
        IOLoop.instance().start()

    run_server()
