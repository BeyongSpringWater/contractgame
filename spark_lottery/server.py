#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging
import os
import tornado.web
import tornado.httpserver
import tornado.ioloop
import tornado.options
from config import config
from contract import start_contract
from tornado.options import options, define

from urls import handlers


define("port", default=8080, help="run on the given port", type=int)
define("debug", default=True, help="start debug mode", type=bool)


class Application(tornado.web.Application):
    def __init__(self):
        settings = dict(
            debug=options.debug,
        )
        super(Application, self).__init__(handlers, **settings)


def main():
    start_contract()
    tornado.options.parse_command_line()
    app = Application()
    http_server = tornado.httpserver.HTTPServer(app)
    http_server.listen(options.port)
    logging.info("Server start on %s", options.port)
    tornado.ioloop.IOLoop.current().start()


if __name__ == "__main__":
    main()
