######## Minimum Bandwidth Regenerating code ###############
## Author : Nitish Mital

## Implementation of my paper "Practical Functional Regenerating Codes for Broadcast Repair of Multiple Nodes", ISIT Paris, 2019. The code implementation resembles centralized repair more closely because all repair packets are collected in one matrix (Yx, Yy). Theoretically, centralized repair and broadcast repair are equivalent.

######## Generates a random message, encodes and stores it in n nodes using the code proposed in the paper.
######## Contains a function repair() that takes as arguments lists of helper node indices and newcomer node indices, and implements the repair procedure proposed in the paper.

################################################################################################

import random

############################
########## Function that repairs the newcomers using the scheme in the paper ###########################


'''
Function to repair a set of r nodes with the help of transmissions from d helper nodes
Inputs:
    helpers: list of indices of helper nodes
    newcmrs: list of indices of newcmr nodes
'''
def repair(helpers, newcmrs):
	random.shuffle(helpers)
	random.shuffle(newcmrs)
	tx_pkt_ind = [[0 for i in range(len(newcmrs))] for j in range(len(helpers))] # indices of the transmitted packets from each helper node
	
	for i in range(len(helpers)):
		ind = [t for t in range(n) if t not in [helpers[i]]]  # labels corresponding to all other nodes except the self for the stored packets in each node 
		for j in range(len(newcmrs)):
			tx_pkt_ind[i][j] = ind.index(newcmrs[j])
		#random.shuffle(tx_pkt_ind[i])
	cyclic_list = [[mod(i,d) for i in range((h-1)*r,h*r)] for h in range(1,ceil(float(d)/float(r) + 1)) for j in range(r)]
	cyclic_list = cyclic_list[:d]
	
	Yx = matrix([[nodes[helpers[i]][tx_pkt_ind[i][mod(h,r)],0] for i in cyclic_list[h]] for h in range(len(cyclic_list))])  ## repair matrix for the evaluation points
	
	Yy = matrix([[nodes[helpers[i]][tx_pkt_ind[i][mod(h,r)],1] for i in cyclic_list[h]] for h in range(len(cyclic_list))]) ## repair matrix for the coded message symbols 
	
	Yx_repair = Yx*C_gen_repair[:,r:]  # Matrix of repair packets
	Yy_repair = Yy*C_gen_repair[:,r:]
	c=0
	
	for i in newcmrs:
		nodes[i][:d,0] = Yx_repair[:,c]
		nodes[i][:d,1] = Yy_repair[:,c]
		nodes[i][d:,0] = C_gen_storage[:,d:].transpose() * nodes[i][:d,0]
		nodes[i][d:,1] = C_gen_storage[:,d:].transpose() * nodes[i][:d,1]
		c = c+1 
###############################################


######## Function to verify the linear independence of a list of points in extension field ##########################
######## Returns True is they are linearly independent, False if not #########################
## Inputs:
###    vpoints: list of points whose linear independence has to be checked
def verify_independence(vpoints):
	lnth=len(vpoints)
	v=[[base_k(0)]*l for i in range(lnth)]
	for i in range(lnth):
		v[i] = vector(vpoints[i])
	return((base_k^l).linear_dependence([v[j] for j in range(lnth)]) == [])
################################################

## Function to estimate the dimension of the intersection of two subspaces
## Inputs: 
##    v1: subspace 1
##    v2: subspace 2
def subspace_intersection(v1,v2):
	intersection = 0
	for i in range(len(v2)):
		v_temp = v1
		if not(verify_independence(v_temp+[v2[i]])):
			intersection += 1
	return intersection

def subspace_dimension(v):
	V = VectorSpace(GF(q),l)
	p_lst = [V(list(V(v[i]))) for i in range(len(v))]
	S = V.subspace(p_lst)
	return S.dimension()

if __name__ == '__main__':
	n=input('number of nodes: ')
	k1=input('recovery threshold: ')
	d=input('number of helpers: ')
	r=input('number of nodes repaired: ')
	q=input('size of base field: ')
	base_k=GF(q)
	#l=d^2  # size of extension chosen so that there are enough linearly independent points in the finite extension field
	l=d*(n-r)  # size of extension chosen so that there are enough linearly independent points in the finite extension field
	k.<x>=GF(q^l)
	subpacketization = int(k1/2*(2*d - k1 + r))
	Frob=k.frobenius_endomorphism();
	S.<y>=k['y',Frob]
	msg=[0]*subpacketization
	for i in range(subpacketization):
	   msg[i] = k.random_element()   # list of randomly picked points which act as the message symbols

	####### Construct linearized polynomial ################
	fy=0
	for i in range(subpacketization):
	    fy=fy+msg[i]*y^i

	####### snippet to choose l linearly independent evaluation points ##########
	points=[[0,0] for i in range(l)]
	v=[[base_k(0)]*l for i in range(l)]

	while(True):
	    for i in range(l):
		points[i][0] = k.random_element()   # list of randomly picked points which act as the evaluation points
		points[i][1] = fy(points[i][0])
		v[i] = vector(points[i][0])
	    print("initial evaluation points are linearly independent - ", (base_k^l).linear_dependence([v[j] for j in range(l)]) == [])
	    if ((base_k^l).linear_dependence([v[j] for j in range(l)]) == []):
		break
	##############################################


	base_field_elements = [i for i in base_k if i not in [0]]
	
	eval_pts = random.sample(base_field_elements, n-1)
	C_storage = codes.GeneralizedReedSolomonCode(eval_pts,d)
	C_gen_storage = C_storage.systematic_generator_matrix()

	eval_pts = random.sample(base_field_elements, 2*r)
	C_repair = codes.GeneralizedReedSolomonCode(eval_pts,r)
	C_gen_repair = C_repair.systematic_generator_matrix()
	
	##############################################


	########## Store coded packets/symbols in the first d nodes ############
	nodes = [None]*n
	for i in range(n):
	    ####### initializing n-1 placeholders in each node. Each row is of type (x,y), where x is the evaluation point, and y is the coded packet (evaluation of fy on x)
	    nodes[i] = zero_matrix(k,n-1,2) 

	for i in range(n-r):
	   nodes[i][:d,:] = matrix(points[i*d:(i+1)*d])   # d packets in node i
	   nodes[i][d:,:] = C_gen_storage[:,d:].transpose() * nodes[i][:d,:]  # storing the parity bits

	##############################################

	########## Fill in the remaining n-r nodes by using the repair scheme #############
	newcmrs = range(n-r,n)  # node indices of r newcomers
	helpers = range(d)  # nodes indices of d helper nodes
	repair(helpers,newcmrs)
	
        ## One repair round
	#newcmrs = [2,3,5,6]
	newcmrs_helpers = random.sample(range(n),r+d)
	newcmrs1 = newcmrs_helpers[0:r]
	#helpers = [0,1,4,7,8,9,10,11,12,13,14,15]
	helpers1 = newcmrs_helpers[r:]
	repair(helpers1,newcmrs1)
	vpoints = [nodes[j][i,ind] for j in random.sample(range(n),r) for i in range(d) for ind in [0]]
	print("The chosen packets after the first repair round are linearly independent: ",verify_independence(vpoints)) # the packets in the newcomers are linearly independent
	
	# multiple repair rounds
	print('Performing 30 repair rounds of random failures and randomly chosen helper nodes..')
	for loop in range(30):
		newcmrs_helpers = random.sample(range(n),r+d)
		newcmrs2 = newcmrs_helpers[0:r]
		helpers2 = newcmrs_helpers[r:]
		#newcmrs = [1,3,11,14]
		#helpers = [0,2,4,5,6,7,8,9,10,12,13,15]
		repair(helpers2,newcmrs2)
	
	## Check the dimension of 50 random sets of k1 nodes to estimate the probability of dimension being greater than subpacketization
	print('Randomly checking the dimension of various k1-subspaces..')
	avg_dim = 0
	space_dim = [0 for i in range(50)]
	min_dim = subpacketization
	for loop in range(50):
		node_list = [i for i in range(n)]
		sample1 = random.sample(node_list,k1)
		vpoints1 = [nodes[j][i,ind] for j in sample1 for i in range(d) for ind in [0]]
		space_dim[loop] = subspace_dimension(vpoints1)
		if space_dim[loop] < min_dim:
			min_dim = space_dim[loop]
		avg_dim += space_dim[loop]/50
	
	print('average dimension of 50 k1-subspaces: ',float(avg_dim))
	print('minimum dimension of k1-subspace: ', float(min_dim))
	print('Number of subpackets: ',subpacketization)
	