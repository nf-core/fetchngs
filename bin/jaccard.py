#!/usr/bin/env python

import mmh3
from Bio.Seq import Seq
from random import random
from scipy.stats import binom, hypergeom

# Import SearchIO and suppress experimental warning
from Bio import BiopythonExperimentalWarning
with warnings.catch_warnings():
    warnings.simplefilter('ignore', BiopythonExperimentalWarning)
    from Bio import SearchIO

# returns list of l-mers in k-mer
def get_lmers(kmer, l):

    """
    Creates list of l-mers from k-mer.
    """

    # Init
    lmers = []
    n_lmers = len(kmer) - l + 1

    # Loop over k-mer
    for i in range(n_lmers):
        lmer = kmer[i:i + l]
        lmers.append(lmer)

    return lmers

# Computes hash of l-mer
def hash_lmer_32(lmer, seed):

    """
    Computes hash of l-mer using random hash function with seed. We use canonical k-mers
    by default to allow strand-neutral comparisons.

    Arguments:
        - lmer: l-mer to be hashed
        - seed: seed to be used for random hash function

    Returns:
        - 32 bit hash of k-mer
    """

    # TODO: 32 bits would probably suffice?

    # TODO: adjust for RNA!

    # calculate the reverse complement
    rc_lmer = str(Seq(lmer).reverse_complement())

    # determine whether original k-mer or reverse complement is lesser
    if lmer < rc_lmer:
        canonical_lmer = lmer
    else:
        canonical_lmer = rc_lmer

    # calculate murmurhash using a hash
    hash = mmh3.hash(canonical_lmer, seed)
        # hash = mmh3.hash64(canonical_lmer, seed)[0]
    if hash < 0: hash += 2**32

    # done
    return hash

# Computes hash of l-mer
def hash_lmer_64(lmer, seed):

    """
    Computes hash of l-mer using random hash function with seed. We use canonical k-mers
    by default to allow strand-neutral comparisons.

    Arguments:
        - lmer: l-mer to be hashed
        - seed: seed to be used for random hash function

    Returns:
        - 64 bit hash of k-mer
    """

    # TODO: 32 bits would probably suffice?

    # TODO: adjust for RNA!

    # calculate the reverse complement
    rc_lmer = str(Seq(lmer).reverse_complement())

    # determine whether original k-mer or reverse complement is lesser
    if lmer < rc_lmer:
        canonical_lmer = lmer
    else:
        canonical_lmer = rc_lmer

    # calculate murmurhash using a hash
    hash = mmh3.hash64(canonical_lmer, seed)[0]
    if hash < 0: hash += 2**64

    # done
    return hash

# Compute hash of all l-mers in k-mer
def hash_kmers(lmers, seed):

    """
    Computes hash of all l-mers using random hash function with seed.

    Arguments:
        - lmers: l-mers to be hashed
        - seed: seed to be used for random hash function

    Returns:
        - 32 bit hash of all l-mers
    """

    # Init
    hashes = []

    # Hash all lmers
    for lmer in lmers:
        hashes.append(hash_lmer_32(lmer,seed))

    # Returns all hashes
    return set(hashes)

# returns s smallest hashes
def kmer_sketch(s, lmers, seed):

    """
    Computes k-mer sketch of size s using random hash function with seed.

    Arguments:
        - s: size of sketch
        - lmers: l-mers to be hashed
        - seed: seed to be used for random hash function

    Returns:
        - 32 bit hash sketch of k-mer
    """

    # Init
    keep = []

    # Loop over
    for lmer in lmers:
        keep.append(hash_lmer_32(lmer, seed))

    # Sort
    keep.sort()

    # Returns keepers
    return set(keep[0:s])

# returns s smallest hashes
def kmer_sketch_ondov(s, lmers, seed):

    """
    Computes k-mer bottom sketch of size s using random hash function with seed. For a sketch
    size s and genome size n, a bottom sketch can be efficiently computed in O(n log s) time
    by maintaining a sorted list of size s and updating the current sketch only when a new
    hash is smaller than the current sketch maximum. This is only faster if the genome size is
    very large.

    Arguments:
        - s: size of sketch
        - lmers: l-mers to be hashed
        - seed: seed to be used for random hash function

    Returns:
        - 32 bit hash sketch of k-mer
    """

    # init
    keep = [hash_lmer_32(lmers[0], seed)]

    # loop over
    for lmer in lmers[1:]:

        # get hash value
        x = hash_lmer_32(lmer, seed)

        # update only if smaller than the maximum
        if x<keep[-1]:

            # insert new value
            j = min(s-2,len(keep)-1)
            while j>=0:
                if keep[j]>x:
                    keep.insert(j, x)
                    break
                j -= 1

            # trim array
            if len(keep)>s:
                keep.pop(-1)

    # returns keepers
    return set(keep)

# Computes Jaccard similarity exactly
def comp_js_exact(a, b):

    """
    Computes exact Jaccard similarity between two lists of l-mers.

    Arguments:
        - a: set of l-mers A.
        - b: set of l-mers B.

    Returns:
        - exact jaccard similarity

    """

    # Return |A int B| / |A union B|
    return len(a.intersection(b)) / len(a.union(b))

# Computes approximate Jaccard similarity
def comp_js(a, b):

    """
    Computes approximate Jaccard similarity between two k-mer skeches.

    Arguments:
        - a: sketch of sequence A.
        - b: sketch of sequence B.

    Returns:
        - approximate jaccard similarity

    """

    # TODO: implement Broder’s original formulation and merge-sorts two bottom sketches S(A) & S(B)

    # Define sets
    a_u_b = sorted(a.union(b))
    a_u_b = set(a_u_b[0:len(a)])

    # Return
    return len(a_u_b.intersection(a).intersection(b)) / len(a_u_b)

# Computes exact p-value for a given number of matches
def comp_pval_js_exact(x, y, sx, sy):

    """
    Computes exact p-value under null hypothesis that observed approximated JS can be explained by the
    variability in JS derived from a random distribution of k-mers. The hypergeometric distribution is
    used in this case. See Ondov et al 2016 for details.

    Arguments:
        - x: set of unique l-mers in k-mer X
        - y: set of unique l-mers in k-mer Y
        - sx: sketch of k-mer X
        - sy: sketch of k-mer Y

    Returns:
        - p-value

    """

    # Get quantities
    s = len(sx)
    m = len(x.union(y))
    w = len(x.intersection(y))
    z = len(sx.intersection(sy))
        # print(f's={s}')
        # print(f'm={m}')
        # print(f'w={w}')
        # print(f'z={z}')

    # Return pval
    return 1.0-hypergeom.cdf(z, m, w, s) if w>0 else 1.0

# Computes approximate p-value for a given number of matches
def comp_pval_js(sx, sy, gx, gy, l):

    """
    Computes approximate p-value under null hypothesis that observed JS can be explained by the variability
    in JS derived from a random distribution of k-mers. The hypergeometric distribution is approximated with
    a binomial distribution. See Ondov et al 2016 for details.

    Arguments:
        - sx: sketch of k-mer X
        - sy: sketch of k-mer Y
        - gx: length of genome encoded by sketch of k-mer X
        - gy: length of genome encoded by sketch of k-mer y
        - l: l-mer size

    Returns:
        - p-value

    """

    # TODO: can r be computed outside just once?

    # Get quantities
    s = len(sx)
    z = len(sx.intersection(sy))
    px = 1. - (1. - 0.25 ** l) ** gx
    py = 1. - (1. - 0.25 ** l) ** gy
    r = px * py / (px + py - px * py)

    # Return pval
    return 1.0-binom.cdf(z, s, r)

# collapse keys based on JS
def add_new_val_js(vals, new_val, l, jsthrsh):

    """
    Adds new value to dictionary. If a key with large enough JS is found, then the count
    is updated. Otherwise, a new key is created and initialized at 1. Returns true if a
    new key had to be created.
    """

    # init
    x = False
    merged = False
    key_match = ""
    lmers_val = set(get_lmers(new_val, l))

    # if key is present update and return
    if new_val in vals:
        vals[new_val] += 1
        return x

    # loop over keys
    for key in vals:

        # if similarity is good enough add to key
        if comp_js_exact(set(get_lmers(key, l)), lmers_val)>=jsthrsh:

            # update entry
            merged = True
            vals[key] += 1
            key_match = key

            # no need to check further
            break

    # if merged...
    if merged:

        # coin flip to decide if we change key. note: needs to be different, otherwise we remove the entry
        if new_val!=key_match and random()>=0.5:
            vals[new_val] = vals.pop(key_match)

    else:

        # create key if didn't merge
        x = True
        vals[new_val] = 1

    # return bool
    return x
