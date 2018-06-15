#!/usr/bin/env python
# -*- coding: utf-8 -*-
import logging
import json
from contract import contract
from tornado import gen
from utils import redis_util
from utils.sse_util import *
from config import config
from handlers import ApiHandler
from models.base import g_session
from models.tables import Players, Contract

class SseHandler(SSEHandler):
    @property
    def redis_pool(self):
        """
        获取 sse 连接
        :return:
        """
        logging.info('redis_pool')
        return redis_util.get_pool()

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
        # msg = build_sse_msg(message="ok", event="on_open")
        # self.send_message(msg)

        # send info
        data = self.get_current_round_info()
        msg = build_sse_msg(message=json.dumps(data), event="one_ether_gamblers")
        logging.info("sse message: {}".format(data))
        self.send_message(msg)
        while self.is_alive:
            yield gen.sleep(1000)
        del sub_obj

    def get_current_round_info(self):
        address = contract.contract_address
        c = g_session.query(Contract).filter_by(address=address).one()
        round_info = contract.get_round_info(c.current_round)
        lottery_info = {
            "title": config["one_ether"]["name"],
            "amount": len(round_info),
            "leftover": config["one_ether"]["required_number_players"] - len(round_info),
            "address": c.address
        }
        result = {
            "gamblers": round_info,
            "lottery_info": lottery_info,
        }
        return result


class PlayerHandler(ApiHandler):
    def get(self):
        # send message when on open, when use nginx, on_open will not work in js
        # msg = build_sse_msg(message="ok", event="on_open")
        # self.send_message(msg)

        # send info
        round = self.get_data().get("round") or "1"
        round = int(round)
        result = self.get_round_info(round)
        self.success_response(result)

    def get_round_info(self, round):
        address = contract.contract_address
        c = g_session.query(Contract).filter_by(address=address).one()
        round_info = contract.get_round_info(round)
        lottery_info = {
            "title": config["one_ether"]["name"],
            "amount": len(round_info),
            "leftover": config["one_ether"]["required_number_players"] - len(round_info),
            "address": c.address,
        }
        result = {
            "gamblers": round_info,
            "lottery_info": lottery_info,
        }
        return result

