#!/usr/bin/env python
# -*- coding: utf-8 -*-

import web3
from solc import compile_source
from web3 import Web3

def test():
    url = "http://localhost:8545"
    key = "f3010fc3e5facd2c1e2efde85c0ab0c46c1d6712b4df47b1703bac351fb801b6"
    sol_path = "./contract/lottery.sol"
    w3 = Web3(web3.HTTPProvider(url))
    acct = w3.eth.account.privateKeyToAccount(key)


    with open(sol_path) as f:
        contract_source_code = f.read()
    compiled_sol = compile_source(contract_source_code) # Compiled source code
    contract_interface = compiled_sol['<stdin>:Lottery']
    contract_ = w3.eth.contract( abi=contract_interface['abi'], bytecode=contract_interface['bin'])
    construct_txn = contract_.constructor().buildTransaction({
        'from': acct.address,
        'nonce': w3.eth.getTransactionCount(acct.address),
        'gas': 1728712,
        'gasPrice': w3.toWei('21', 'gwei')})

    signed = acct.signTransaction(construct_txn)

    tx_hash = w3.eth.sendRawTransaction(signed.rawTransaction)

    tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)
    contract_address = tx_receipt.contractAddress
    w3.eth.defaultAccount = acct.address
    contract = w3.eth.contract(
        address= contract_address,
        abi=contract_interface['abi'],
    )
    print(contract)

test()
