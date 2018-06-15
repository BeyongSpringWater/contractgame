#!/usr/bin/env python
# -*- coding: utf-8 -*-

import contract
import logging
from config import config
from models.tables import Contract, Players
from handlers import ApiHandler
from sqlalchemy import desc

class LotteryTypeHandler(ApiHandler):
    def get(self):
        """
        获取彩票类型
        """
        c = contract.contract
        logging.info("cccccccc contract address: {}".format(c.contract.address))
        obj = self.session.query(Contract).filter_by(address = c.contract_address).one()
        players = self.session.query(Players).filter_by(contract_address = obj.address).filter_by(round=obj.current_round).all()
        info = {
                "id": 1,
                "title": config["one_ether"]["name"],
                "desciption": "xxx",
                "amount": len(players),
                "round": obj.current_round,
                "leftover": config["one_ether"]["required_number_players"] - len(players)
        }
        self.success_response([info])


class WinnerHandler(ApiHandler):
    def get(self):
        limit = self.get_data().get("limit") or "5"
        limit = int(limit)
        players = self.session.query(Players).filter_by(is_winner=True).order_by(desc(Players.round)).all()
        result = []
        for p in players:
            info = {
                    "lottery_name": "{} #{}".format(config["one_ether"]["name"], p.round),
                    "address": p.player_address,
                    "amount": p.bouners,
            }
            result.append(info)
        self.success_response(result)
