#!/usr/bin/env python
# -*- coding: utf-8 -*-


import time
from web3 import Web3, HTTPProvider

class Test():
    url = "http://47.94.242.18:8545"

    @classmethod
    def send_ether_to_contract(cls, amount_in_ether, wallet_key, contract_address):
        w3 = Web3(HTTPProvider(cls.url))
        acct = w3.eth.account.privateKeyToAccount(wallet_key)
        wallet_address = acct.address
        amount_in_wei = amount_in_ether * 1000000000000000000;
        nonce = w3.eth.getTransactionCount(wallet_address)
        txn_dict = {
                'to': contract_address,
                'value': amount_in_wei,
                'gas': 2000000,
                'gasPrice': w3.toWei('40', 'gwei'),
                'nonce': nonce,
                'chainId': 3
        }
        signed_txn = w3.eth.account.signTransaction(txn_dict, wallet_key)
        txn_hash = w3.eth.sendRawTransaction(signed_txn.rawTransaction)
        txn_receipt = None
        count = 0
        print("waiting", end="", flush=True)
        while txn_receipt is None and (count < 300):
            txn_receipt = w3.eth.getTransactionReceipt(txn_hash)
            print(".", end="", flush=True)
            time.sleep(1)

        if txn_receipt is None:
            print("  timeout")
        else:
            print("  success")


if __name__ == "__main__":
    keys = [
        "1d68fa6b50b876b4d9518265b5d69db77cf9e821f7032537b168a2b12bbfbaa7",
        "3638ab8c56d3fd4224e5ea19a270376e09f505f44f7268500903c0bf33978a8f",
        "2b9be2b765e73b5989210c74bf5bb98af3cb910427156f94fdef7b977ae5f6b4",
        "487074139da134ca85f849a2db09e94cefa7c70ec1f9b7be9c09597b0d3542b8",
        "aa0c24228743f438830a3bee0269eb1ef6e35abbda35361d55300ebe7892c3d3",
        "1f23c7c5070db6fa8c77a77a7eba851025194ccf58effdeacb83ae10e8bd15be",
        "a37387ffa866c97ae228f3497478ad5b5159e560f74312b4fa0b683ba7185168",
    ]
    contract_addr = "0xd7a00caBF7402017FD535347A1e9E9F883632E21"
    t = Test()
    # t.url = "xxx"
    for key in keys:
        t.send_ether_to_contract(1, key, contract_addr)
