import json
import os
import logging

from eth_abi import encode
from sha3 import keccak_256
from web3 import Web3

from .decentral_elect_contract import DecentralElectContract
from .linkable_ring_signature import LinkableRingSignature
from .utils import bytes_to_int

class PartitionDecentralElectContract(DecentralElectContract):
    def __init__(self, web3: Web3, address='', abi:str = './abi/ParitionDecentralElect.abi', bin:str = './bin/ParitionDecentralElect.bin'):
        self.web3 = web3
        current_dir = os.path.dirname(__file__)

        with open(os.path.join(current_dir, abi)) as abi_file:
            self.abi = json.load(abi_file)

        if address:
            self.contract = web3.eth.contract(address=address, abi=self.abi)
        else:
            with open(os.path.join(current_dir, bin)) as bytecode_file:
                bytecode = bytecode_file.read()
            self.contract = web3.eth.contract(abi=self.abi, bytecode=bytecode)

        os.makedirs('./log/', exist_ok=True)
        logging.basicConfig(filename='./log/ParitionDecentralElect.log', level=logging.INFO)
        self.logger = logging.getLogger()
        self.STATUS_MAPPING = {
        0: "Unopened",
        1: "Registration",
        2: "Cluster",
        3: "Vote",
        4: "Verification",
        5: "Declaration"
        }
        self.manager_gas_spend = 0
        self.voter_gas_spend = 0

    def get_constituency(self, identifier:int, pub_x:int, **kwargs):
        try:
            tx_rcpt = self.contract.functions.get_constituency(identifier, pub_x).call()
            self.logger.info('Election {} :Success Get Constituency'.format(identifier))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {} :Unable to Get Constituency: {}'.format(identifier, e))

    def get_registered_pkeys(self, identifier:int, constituency:int, **kwargs):
        try:
            tx_rcpt = self.contract.functions.get_registered_pkeys(identifier, constituency).call()
            self.logger.info('Election {}-{} :Success Get Public keys'.format(identifier, constituency))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {}-{} :Unable to Get Public keys'.format(identifier, constituency, e))

    def vote(self, identifier: str, constituency:int, signature: LinkableRingSignature, **kwargs):
        try:
            tag_array = [signature.tag[0].n, signature.tag[1].n]
            vote = signature.message
            tx_hash = self.contract.functions.vote(identifier, constituency, tag_array, signature.ring, signature.seed, vote).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Election {}-{}: Gas: {:0>8}:Success vote'.format(identifier, constituency, tx_rcpt.gasUsed))
            self._use_gas(tx_rcpt.gasUsed, voter=True)

            return tx_hash
        except Exception as e:
            self.logger.error('Election {}-{}: Unable to Vote: {}'.format(identifier, constituency, e))

    def cluser_voters(self, identifier:int, **kwargs):
        try:
            tx_hash = self.contract.functions.cluser_voters(identifier).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Election {}: Gas: {:0>8}:Clustering Success'.format(identifier, tx_rcpt.gasUsed))
            self._use_gas(tx_rcpt.gasUsed)

            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {} :Unable to Cluster: {}'.format(identifier, e))

    def get_cluster_progress(self, identifier:int, **kwargs):
        try:
            tx_rcpt = self.contract.functions.get_cluster_progress(identifier).call()
            self.logger.info('Election {}:Success Get cluster progress'.format(identifier))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {}:Unable to Get cluster progress'.format(identifier))

    def deploy(self, identity_manager:int, constituency_size = None):
        try:
            if (constituency_size):
                tx_hash = self.contract.constructor(constituency_size).transact({
                    "gas": 5000000,
                    "gasPrice": Web3.to_wei(10000000000, 'wei')
                })
            else:
                tx_hash = self.contract.constructor().transact({
                    "gas": 5000000,
                    "gasPrice": Web3.to_wei(10000000000, 'wei')
                })

            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.contract = self.web3.eth.contract(address=tx_rcpt.contractAddress, abi=self.abi)
            self.identity_manager = identity_manager
            self.owner_address = self.web3.eth.default_account

            self.logger = logging.getLogger(name=tx_rcpt.contractAddress)
            self.logger.info('Gas: {:0>8}:Success Create DecentralElect Contract'.format(tx_rcpt.gasUsed))
            self._use_gas(tx_rcpt.gasUsed)

            return tx_rcpt
        
        except Exception as e:
            self.logger.error('Unable to Deploy Contract: ', e)
        