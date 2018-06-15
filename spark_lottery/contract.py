#!/usr/bin/env python
# -*- coding: utf-8 -*-
import traceback
import threading
import json
import web3
import time
import contract_process

from utils.sse_util import SseSender
from utils.redis_util import r_client
from config import config
from models.tables import Players, Contract as DBContract
from models.base import g_session
from web3 import Web3
from solc import compile_source


class Contract(threading.Thread):
    def __init__(self, sol_path, account_key=None, contract_address = None):
        super(self.__class__, self).__init__()
        self.sol_path = sol_path
        self.account_key = account_key
        self.contract = None
        self.w3 = None
        self.contract_address = contract_address
        self.watching = False
        self.sender = SseSender(redis=r_client, channel="one_ether")
        self.get_contract()

    def get_contract(self):
        with open(self.sol_path) as f:
            contract_source_code = f.read()
        compiled_sol = compile_source(contract_source_code) # Compiled source code
        contract_interface = compiled_sol['<stdin>:Lottery']
        w3 = Web3(web3.HTTPProvider(config["url"]))
        self.w3 = w3
        # set pre-funded account as sender
        acct = None
        if not self.account_key:
            if config["one_ether"].get("account"):
                w3.eth.defaultAccount = account.address
            else:
                w3.eth.defaultAccount = w3.eth.accounts[0]
                print("use the default accounts[0]")
        else:
            acct = w3.eth.account.privateKeyToAccount(self.account_key)
            w3.eth.defaultAccount = acct.address
        # Instantiate and deploy contract
        compiled = w3.eth.contract(abi=contract_interface['abi'], bytecode=contract_interface['bin'])

        # deploy contract
        if not self.contract_address:
            if not acct:
                raise Exception("account key should be set when there is no contract!")
            contract_ = w3.eth.contract( abi=contract_interface['abi'], bytecode=contract_interface['bin'])
            construct_txn = contract_.constructor().buildTransaction({
                'from': acct.address,
                'nonce': w3.eth.getTransactionCount(acct.address),
                'gasPrice': self.w3.eth.gasPrice
                })


            signed = acct.signTransaction(construct_txn)

            tx_hash = w3.eth.sendRawTransaction(signed.rawTransaction)
            print("waiting for contract receipted", end="", flush=True)
            count = 0
            tx_receipt = None
            while not tx_receipt and (count < 300):
                time.sleep(1)
                tx_receipt = w3.eth.getTransactionReceipt(tx_hash)
                print(".", end="", flush=True)
            print()
            if not tx_receipt:
                raise Exception("timeout for contract receipted!")
            self.contract_address = tx_receipt.contractAddress

        # Create the contract instance with the newly-deployed address
        self.contract = w3.eth.contract(
            address= self.contract_address,
            abi=contract_interface['abi'],
        )
        print("contract address: {}".format(self.contract_address))


    def active(self):
        # nonce = self.w3.eth.getTransactionCount(wallet_address)
        acct = self.w3.eth.account.privateKeyToAccount(self.account_key)
        account = self.w3.eth.account.privateKeyToAccount(self.account_key)
        nonce = self.w3.eth.getTransactionCount(acct.address)
        txn_dict = self.contract.functions.start().buildTransaction({
            'chainId': None,
            'gasPrice': self.w3.eth.gasPrice,
            'nonce': nonce,
        })

        signed_txn = self.w3.eth.account.signTransaction(txn_dict, private_key=self.account_key)
        result = self.w3.eth.sendRawTransaction(signed_txn.rawTransaction)
        tx_receipt = self.w3.eth.getTransactionReceipt(result)

        count = 0
        print("wait for request receipted", end="", flush=True)
        while tx_receipt is None and (count < 300):
            time.sleep(1)
            tx_receipt = self.w3.eth.getTransactionReceipt(result)
            print(".", end="", flush=True)
        print()

        if tx_receipt is None:
            return {'status': 'failed', 'error': 'timeout'}
        else:
            return {'status': 'success', 'error': None}


    def stop(self):
        self.contract.functions.stop().transact()
        # self.w3.eth.waitForTransactionReceipt(tx_hash)

    def destory(self):
        self.contract.functions.destory().transact()
        # self.w3.eth.waitForTransactionReceipt(tx_hash)

    def get_active(self):
        return self.contract.functions.getActive().call()

    def get_players(self):
        return self.contract.functions.getPlayers().call()

    def get_balance(self):
        return self.contract.functions.getBalance().call()

    def get_round(self):
        return self.contract.functions.getRound().call()

    def get_winners(self):
        return self.contract.functions.getWinners().call()

    def watch(self):
        # tx_filter = self.w3.eth.filter({"fromBlock": 1, "toBlock": "latest", "address": self.contract_address})
        log_filter = self.contract.events.Log.createFilter(fromBlock=0)
        winner_filter = self.contract.events.AnnounceWinner.createFilter(fromBlock=0)
        while True:
            log_events = log_filter.get_new_entries()
            winner_events = winner_filter.get_new_entries()
            if not log_events or not winner_events:
                time.sleep(3)
                continue
            for event in log_events:
                self.process_log_event(event)
            for event in winner_events:
                self.process_winner_event(event)
            time.sleep(1)

    def process_log_event(self, event):
        pass

    def process_winner_event(self, event):
        pass

    def run(self):
        if self.watching:
            return
        try:
            self.watching = True
            while True:
                info = {
                    "active": self.get_active(),
                    "players": self.get_players(),
                    "balance": self.get_balance(),
                    "winners": self.get_winners(),
                    "round": self.get_round(),
                }
                # print("contract info: {}".format(info))
                # store in db
                update = contract_process.process_contract(self.contract_address, info)
                if update:
                    round_info = self.get_round_info(info["round"])
                    lottery_info = {
                        "title": config["one_ether"]["name"],
                        "amount": len(round_info),
                        "leftover": config["one_ether"]["required_number_players"] - len(round_info),
                        "address": self.contract_address
                    }
                    result = {
                        "gamblers": round_info,
                        "lottery_info": lottery_info,
                    }

                    self.sender.send("update", result)
                time.sleep(0.5)
        except Exception as e:
            traceback.print_exc()
            print("error: {}".format(e))
            self.watching = False

    def get_round_info(self, lottery_round):
        players = g_session.query(Players) .filter(Players.round == lottery_round).all()
        result = []
        for p in players:
            info = {
                "id": p.id,
                "address": p.player_address,
                "amount": "{}".format(config["one_ether"]["ante"])
            }
            result.append(info)
        return sorted(result, key = lambda x: x["id"], reverse=True)
        self.sender.send(result)

# 1. 使用配置文件中的 contract_addr
# 2. 使用数据库中的 contract_addr
# 3. 使用 account_key 创建 contract
def get_contract():
    account_key = config["one_ether"].get("account_key")
    contract_address = config["one_ether"].get("contract_address")
    if not contract_address:
        c = g_session.query(DBContract).filter_by(name=config["one_ether"]["name"]).first()
        contract_address = None
        if c:
            contract_address = c.address
            print("found contract address: {}".format(c.address))
        elif not account_key:
            raise Exception("contract_address or account_key should be provided!")
        else:
            print("create a new contract")
    sol_path = config["one_ether"]["contract_path"]
    return Contract(sol_path, account_key, contract_address)

contract = get_contract()

def start_contract():
    contract.start()
    return contract


if __name__ == "__main__":
    c = get_contract()
    c.active()

