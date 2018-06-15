#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging
from config import config
from sqlalchemy.sql import func
from models.tables import Players, Contract
from models.base import open_session



def process_contract(contract_address, info):
    round  = info["round"]
    players = info["players"]
    winners = info["winners"]
    setting = config["one_ether"]
    with open_session() as session:
        db_players_count = session.query(Players).count()
        db_winner_count = session.query(Players).filter_by(is_winner=True).count()
        db_round = session.query(func.max(Players.round)).all() or 1
        new_players = []
        if db_players_count < len(info["players"]):
            new_players = players[db_players_count:]
        for index, address in enumerate(new_players):
            lottery_round = (db_players_count + index) // setting["required_number_players"] + 1
            new_player = Players(player_address = address, round=lottery_round, contract_address = contract_address)
            session.add(new_player)

    # update winner
    new_winners = []
    update = False
    if db_winner_count < len(info["winners"]):
        update = True
        new_winners = winners[db_winner_count:]

    for index, address in enumerate(new_winners):
        # get the winner round
        update = True
        bouners = "{:.4f}".format(setting["ante"] * setting["required_number_players"] * setting["winner_percentage"] / 100.0)
        winner_round = db_winner_count + index + 1

        with open_session() as session:
            old_player = session.query(Players).filter_by(player_address = address).filter_by(round = winner_round).first()
            old_player.is_winner = True
            old_player.bouners = bouners


    with open_session() as session:
        contract = session.query(Contract).filter_by(name=setting["name"]).first()
        if not contract:
            logging.info("add new contract")
            new_contract = Contract(address=contract_address, name=setting["name"], balance=info["balance"])
            session.add(new_contract)
        else:
            if contract.address != contract_address or contract.balance != info["balance"] or contract.current_round != info["round"]:
                contract.address = contract_address
                contract.balance = info["balance"]
                contract.current_round = info["round"]
            if update:
                logging.info("update contract")
                c = session.query(Contract).filter_by(address=contract_address).one()
                c.balance = info["balance"]
                c.current_round = info["round"]
    return update
