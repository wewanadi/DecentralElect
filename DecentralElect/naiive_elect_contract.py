import json
import os
import logging

from web3 import Web3

from .decentral_elect_contract import DecentralElectContract

class NaiiveElectContract(DecentralElectContract):
    def __init__(self, web3: Web3, address=''):
        self.web3 = web3
        current_dir = os.path.dirname(__file__)

        with open(os.path.join(current_dir, './abi/NaiiveElect.abi')) as abi_file:
            self.abi = json.load(abi_file)

        if address:
            self.contract = web3.eth.contract(address=address, abi=self.abi)
        else:
            with open(os.path.join(current_dir, './bin/NaiiveElect.bin')) as bytecode_file:
                bytecode = bytecode_file.read()
            self.contract = web3.eth.contract(abi=self.abi, bytecode=bytecode)

        os.makedirs('./log/', exist_ok=True)
        logging.basicConfig(filename='./log/NaiiveElect.log', level=logging.INFO)
        self.logger = logging.getLogger()
        self.STATUS_MAPPING = {
        0: "Unopened",
        1: "Registration",
        2: "Vote",
        3: "Verification",
        4: "Declaration"
        }
        self.manager_gas_spend = 0
        self.voter_gas_spend = 0

    def vote(self, identifier: str, public_key, bullot_hash: int, signature: tuple[int], **kwargs):
        try:
            tx_hash = self.contract.functions.vote(identifier, ((int)(public_key[0]), (int)(public_key[1])), bullot_hash, ((int)(signature[0]), (int)(signature[1]))).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Election {}: Gas: {:0>8}:Success vote'.format(identifier, tx_rcpt.gasUsed))
            self._use_gas(tx_rcpt.gasUsed, voter=True)

            return tx_hash
        except Exception as e:
            self.logger.error('Election {}: Unable to Vote: {}'.format(identifier, e))

    def check_if_voted(self, identifier: int, public_key, **kwargs):
        return super().check_if_voted(identifier, (int)(public_key[0]), **kwargs)
