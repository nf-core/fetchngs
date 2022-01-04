#!/usr/bin/env python

# create de bruijn graph
def make_debruijn_graph(seqs):

    """
    Creates a de bruijn graph from the passed sequences.
    """

    # Init
    edges = []
    nodes = set()
    not_starts = set()

    # Loop over sequences
    for seq in seqs:

        # Loop over k-mers
        for r in seq:
            r1 = r[:-1]
            r2 = r[1:]
            nodes.add(r1)
            nodes.add(r2)
            edges.append((r1,r2))
            not_starts.add(r2)

    # return
    return (nodes,edges,list(nodes-not_starts))

# builds kmers from sequence
def build_k_mer(seq, k):

    """
    Builds k-mers from sequence.
    """

    return [seq[i:k+i] for i in range(0,len(seq)-k+1)]

# creates node-edge map
def make_node_edge_map(edges):

    """
    Creates node-edge map.
    """

    # init
    node_edge_map = {}

    # loop over edges
    for e in edges:
        n = e[0]
        if n in node_edge_map:
            node_edge_map[n].append(e[1])
        else:
            node_edge_map[n] = [e[1]]

    # Make unique
    for key in node_edge_map:
        node_edge_map[key] = list(set(node_edge_map[key]))

    # return dictionary
    return node_edge_map

# finds eulerian trail
def eulerian_trail(m, v):

    """
    Finds Eulerian trail.
    """

    # init
    nemap = m
    start = v
    result_trail = []
    result_trail.append(start)

    # search until found
    while(True):

        trail = []
        previous = start

        while(True):

            if(previous not in nemap):
                break
            next = nemap[previous].pop()
            if(len(nemap[previous]) == 0):
                nemap.pop(previous,None)
            trail.append(next)
            if(next == start):
                break;
            previous = next

        # completed one trail
        # print(trail)
        index = result_trail.index(start)
        result_trail = result_trail[0:index+1] + trail + result_trail[index+1:len(result_trail)]

        # choose new start
        if(len(nemap)==0):
          break
        found_new_start = False

        for n in result_trail:
            if n in nemap:
                start = n
                found_new_start = True
                break # from for loop

        if not found_new_start:
            # print("error")
            # print("result_trail",result_trail)
            # print(nemap)
            break

    # return trail
    return result_trail

# visualization
def visualize_debruijn(G):

    """
    Prints de Bruijn graph.
    """

    # Get nodes and edges
    nodes = G[0]
    edges = G[1]
    dot_str= 'digraph "DeBruijn graph" {\n '
    for node in nodes:
        dot_str += '    %s [label="%s"] ;\n' %(node,node)
    for src,dst in edges:
        dot_str += '    %s->%s;\n' %(src,dst)
    return dot_str + '}\n'

# assembles trails
def assemble_trail(trail):

    """
    Assembles trails.
    """

    if len(trail) == 0:
        return ""
    result = trail[0][:-1]
    for node in trail:
        result += node[-1]
    return result

# assembles keys
def asmbl_keys(keys):

    kmers = [build_k_mer(seq, 9) for seq in keys]

    # Make graph
    G = make_debruijn_graph(kmers)

    # Make node-edge
    m = make_node_edge_map(G[1])

    # Find start of path (problem if cycle)
    start = G[2][0] if (len(G[2])>0) else ""

    if not start == "":

        # Find trails and assemble them
        t = eulerian_trail(m, start)
        a = assemble_trail(t)

    else:

        a = ""

    # return assemble
    return a
