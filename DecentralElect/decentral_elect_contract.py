import json
import os
import logging

from eth_abi import encode
from web3 import Web3
from sha3 import keccak_256

from .linkable_ring_signature import LinkableRingSignature
from .utils import bytes_to_int

class DecentralElectContract:
    def __init__(self, web3: Web3, address=''):
        self.web3 = web3
        current_dir = os.path.dirname(__file__)

        with open(os.path.join(current_dir, './abi/DecentralElect.abi')) as abi_file:
            self.abi = json.load(abi_file)

        if address:
            self.contract = web3.eth.contract(address=address, abi=self.abi)
        else:
            with open(os.path.join(current_dir, './bin/DecentralElect.bin')) as bytecode_file:
                bytecode = bytecode_file.read()
            self.contract = web3.eth.contract(abi=self.abi, bytecode=bytecode)

        os.makedirs('./log/', exist_ok=True)
        logging.basicConfig(filename='./log/DecentralElect.log', level=logging.INFO)
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
        

    def _use_gas(self, gas:int, voter:bool = False):
        if (voter):
            self.voter_gas_spend += gas
        else:
            self.manager_gas_spend += gas

    def deploy(self, identity_manager:int):
        try:
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
        

    def create_election(self, identifier:int, subject: str, **kwargs):
        try:
            tx_hash = self.contract.functions.create_election(identifier, subject).transact({
                "gas": 5000000,
                "gasPrice": Web3.to_wei(10000000000, 'wei')
            })
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Gas: {:0>8}:Success Create Election {}: {}'.format( tx_rcpt.gasUsed, identifier, subject))
            self._use_gas(tx_rcpt.gasUsed)

            return tx_rcpt
        except Exception as e:
            self.logger.error('Unable to Create Vote {} {}: {}'.format(identifier, subject, e))

    def get_status(self, identifier: int):
        try:
            tx_rcpt = self.contract.functions.get_status(identifier).call()
            self.logger.info('Success Get Status of Election {}'.format(identifier))
            return self.STATUS_MAPPING.get(tx_rcpt, "Unknown")
        except Exception as e:
            self.logger.error('Unable to Get Status of Election {}: {}'.format(identifier, e))

    
    def set_candidate(self, identifier:int, name:str, description: str, **kwargs):
        try:
            tx_hash = self.contract.functions.set_candidate(identifier, name, description).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Gas: {:0>8}:Success Set Election {} Candidate {}'.format(tx_rcpt.gasUsed, identifier, name))
            self._use_gas(tx_rcpt.gasUsed)
            
            return tx_rcpt
        except Exception as e:
            self.logger.error('Unable to Set Candidate {} {}: {}'.format(identifier, name, e))
    
    def get_candidates(self, identifier: int):
        try:
            tx_rcpt = self.contract.functions.get_candidates(identifier).call()
            self.logger.info('Success Get Candidates of Election {}'.format(identifier))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Unable to Get Candidates of Election {}: {}'.format(identifier, e))

    def register_voter(self, identifier:int, pub_x:int, pub_y:int, **kwargs):
        try:
            tx_hash = self.contract.functions.register_voter(identifier, pub_x, pub_y).transact({
                "gas": 5000000,
                "gasPrice": Web3.to_wei(10000000000, 'wei')
            })
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Gas: {:0>8}:Success Registered {}'.format( tx_rcpt.gasUsed, pub_x))
            self._use_gas(tx_rcpt.gasUsed)

            return tx_rcpt
        except Exception as e:
            self.logger.error('Unable to Registered {}: {}'.format(pub_x, e))
    
    def check_if_registered(self, identifier:int, pub_x:int, **kwargs):
        try:
            tx_rcpt = self.contract.functions.check_if_registered(identifier, pub_x).call()
            self.logger.info('Election {} :Success Check If Registered'.format(identifier))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {} :Unable to Check If Registered: {}'.format(identifier, e))

    def check_if_voted(self, identifier:int, pub_x:int, **kwargs):
        try:
            tx_rcpt = self.contract.functions.check_if_voted(identifier, pub_x).call()
            self.logger.info('Election {} :Success Check If Voted'.format(identifier))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {} :Unable to Check If Voted: {}'.format(identifier, e))

    def get_registered_pkeys(self, identifier:int, **kwargs):
        try:
            tx_rcpt = self.contract.functions.get_registered_pkeys(identifier).call()
            self.logger.info('Success Get Register Voters of Election {}'.format(identifier))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Unable to Get Register Voters of Election {}: {}'.format(identifier, e))

    def start_vote(self, identifier:int, **kwargs):
        try:
            tx_hash = self.contract.functions.start_vote(identifier).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Gas: {:0>8}:Success Start the voting Phase of Election {}'.format( tx_rcpt.gasUsed, identifier))
            return tx_rcpt
            self._use_gas(tx_rcpt.gasUsed)

        except Exception as e:
            self.logger.error('Unable to Set Vote Status {}: {}'.format(identifier, e))

    def vote(self, identifier: int, signature: LinkableRingSignature, **kwargs):
        try:
            tag_array = [signature.tag[0].n, signature.tag[1].n]
            vote = signature.message
            tx_hash = self.contract.functions.vote(identifier, tag_array, signature.ring, signature.seed, vote).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Election {}: Gas: {:0>8}:Success vote'.format(identifier, tx_rcpt.gasUsed, identifier))
            self._use_gas(tx_rcpt.gasUsed, voter = True)

            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {}: Unable to Vote: {}'.format(identifier, e))

    def stop_vote(self, identifier: int, **kwargs):
        try:
            tx_hash = self.contract.functions.stop_vote(identifier).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Gas: {:0>8}:Success Start the Verification Phase of Election {}'.format( tx_rcpt.gasUsed, identifier))
            self._use_gas(tx_rcpt.gasUsed)

            return tx_rcpt
        except Exception as e:
            self.logger.error('Unable to Set Verfication Status {}: {}'.format(identifier, e))
        
    def verify_ballot(self, identifier: int, ballot: str ,**kwargs):
        try:
            ballot_hash = self.hash_vote(ballot)
            tx_hash = self.contract.functions.verify_ballot(identifier, ballot, ballot_hash).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Gas: {:0>8}:Success verifty ballot {} of Election {}'.format( tx_rcpt.gasUsed, ballot, identifier))
            self._use_gas(tx_rcpt.gasUsed, voter = True)

            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {}: Unable to verifty ballot {}: {}'.format(identifier, ballot, e))

    def check_if_verified(self, identifier:int, ballot_hash:int, **kwargs):
        try:
            tx_rcpt = self.contract.functions.check_if_verified(identifier, ballot_hash).call()
            self.logger.info('Election {} :Success Check If Verified'.format(identifier))
            return tx_rcpt
        except Exception as e:
            self.logger.error('Election {} :Unable to Check If Verified: {}'.format(identifier, e))

    def stop_verification(self, identifier: int, **kwargs):
        try:
            tx_hash = self.contract.functions.stop_verification(identifier).transact()
            tx_rcpt = self.web3.eth.wait_for_transaction_receipt(tx_hash)
            self.logger.info('Gas: {:0>8}:Success End Election {}'.format( tx_rcpt.gasUsed, identifier))
            self._use_gas(tx_rcpt.gasUsed)

            return tx_rcpt
        except Exception as e:
            self.logger.error('Unable End the Election {}: {}'.format(identifier, e))

    # def get_ballots(self, identifier: int):
    #     return self.contract.functions.get_ballots(identifier).call()
    
    # def wait(self, tx_hash):
    #     return self.web3.eth.wait_for_transaction_receipt(tx_hash)
    
    @staticmethod
    def hash_vote(ballot :str):
        _ = encode(['string'], [ballot])
        _ = keccak_256(_).digest()
        _ = bytes_to_int(_)
        return _