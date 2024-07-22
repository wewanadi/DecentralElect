from random import randint

from py_ecc import bn128
from py_ecc.bn128 import add, multiply, curve_order, G1
from py_ecc.bn128 import field_modulus, FQ
from hashlib import sha256

from .utils import hashs, bytes_to_int, powmod

asint = lambda x: x.n if isinstance(x, FQ) else x

randsn = lambda: randint(1, curve_order - 1)
randsp = lambda: randint(1, field_modulus - 1)
sbmul = lambda s: multiply(G1, asint(s))
hashsn = lambda *x: hashs(*x) % curve_order
hashpn = lambda *x: hashsn(*[item.n for sublist in x for item in sublist])
hashp = lambda *x: hashs(*[item.n for sublist in x for item in sublist])
addmodn = lambda x, y: (x + y) % curve_order
addmodp = lambda x, y: (x + y) % field_modulus
mulmodn = lambda x, y: (x * y) % curve_order
mulmodp = lambda x, y: (x * y) % field_modulus
submodn = lambda x, y: (x - y) % curve_order
submodp = lambda x, y: (x - y) % field_modulus
# invmodn = lambda x: inv(x, curve_order)
# invmodp = lambda x: inv(x, field_modulus)
negp = lambda x: (x[0], -x[1])


def evalcurve(x):
	a = 5472060717959818805561601436314318772174077789324455915672259473661306552146
	beta = addmodp(mulmodp(mulmodp(x, x), x), 3)
	y = powmod(beta, a, field_modulus)
	return (beta, y)


def isoncurve(x, y):
	beta = addmodp(mulmodp(mulmodp(x, x), x), 3)
	return beta == mulmodp(y, y)


def hashtopoint(x: int):
	x = x % curve_order
	while True:
		beta, y = evalcurve(x)
		if beta == mulmodp(y, y):
			assert isoncurve(x, y)
			return FQ(x), FQ(y)
		x = addmodn(x, 1)

def generate_key_pair():
    private_key = randsn()
    public_key = sbmul(private_key)
    return private_key, public_key

def encrypt(message, public_key):
    k = randsn()
    R = sbmul(k)
    S = multiply(public_key, k)
    encrypted_message = bytes(a ^ b for a, b in zip(message, S[0].n.to_bytes(32, 'big')))
    return R, encrypted_message

def decrypt(R, encrypted_message, private_key):
    S = multiply(R, private_key)
    decrypted_message = bytes(a ^ b for a, b in zip(encrypted_message, S[0].n.to_bytes(32, 'big')))
    return decrypted_message

def sign_message(private_key, message:int):
    # z = bytes_to_int(sha256(message).digest()) % curve_order
    k = randsn()
    R = sbmul(k)
    r = R[0].n % curve_order
    s = (message + r * private_key) * pow(k, curve_order - 2, curve_order) % curve_order
    return (r, s)

def verify_signature(public_key, message, signature):
    r, s = signature
    z = bytes_to_int(sha256(message).digest()) % curve_order
    w = pow(s, curve_order - 2, curve_order)
    u1 = (z * w) % curve_order
    u2 = (r * w) % curve_order
    P = add(sbmul(u1), multiply(public_key, u2))
    return P[0].n % curve_order == r

if __name__ == "__main__":
	# Sanity test
	beta, y = evalcurve(1)
	assert mulmodp(y, y) == beta
	assert y == 2

	# Compatibility test
	z = bytes_to_int(sha256('hello world').digest())
	x, y = hashtopoint(z)
	assert x == 18149469767584732552991861025120904666601524803017597654373315627649680264678
	assert y == 18593544354303197021588991433499968191850988132424885073381608163097237734820

	# Compatibility with: uint256(keccak256(uint256(1), uint256(2), uint256(3))) % Curve.N();
	assert hashsn(1, 2, 3) == 5999809398626971894156481321441750001229812699285374901473004231265197659290

	# Generate key pair
	private_key, public_key = generate_key_pair()
	print("Private Key:", private_key)
	print("Public Key:", public_key)

	# Example message to encrypt
	message = b"Secret Message"
	print("Original Message:", message)

	# Encrypt the message
	R, encrypted_message = encrypt(message, public_key)
	print("Encrypted Message:", encrypted_message)

	# Decrypt the message
	decrypted_message = decrypt(R, encrypted_message, private_key)
	print("Decrypted Message:", decrypted_message)

	assert message == decrypted_message, "Decryption failed!"

	# Generate key pair
	private_key, public_key = generate_key_pair()
	print("Private Key:", private_key)
	print("Public Key:", public_key)

	# Example message to sign
	message = b"Sign this message"
	print("Message:", message)

	# Sign the message
	signature = sign_message(private_key, message)
	print("Signature:", signature)

	# Verify the signature
	is_valid = verify_signature(public_key, message, signature)
	print("Signature valid:", is_valid)

	assert is_valid, "Signature verification failed!"