#!/usr/bin/env python
# -*- coding: utf-8 -*-

from tornado import web
from tornado.web import URLSpec as U
from handlers.lottery import LotteryTypeHandler, WinnerHandler
from handlers.sse import SseHandler, PlayerHandler


handlers = [
    U(r"/lottery_type", LotteryTypeHandler),
    U(r"/event", SseHandler),
    U(r"/winners", WinnerHandler),
    U(r"/players", PlayerHandler),
]
