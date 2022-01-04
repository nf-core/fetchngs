#!/usr/bin/env python

###########################################################################################################################
# Example where we have DNA sequences of length 50 bp and where the looping probability is a function of the content
# of the sequence. In particular, here P(looping)=1/(1+exp{-(25-#Cs-#Gs)}). Thus, P(looping)>0.5 when #Cs+#Gs<25, and
# P(looping)<0.5 when #Cs+#Gs>25, and P(looping)=0.5 when #Cs+#Gs=25. With a sample size of 250 observations, the BLSTM
# network achieves a correlation wrt the true looping probability vector of 95%.
###########################################################################################################################

# Load dependencies
import math
import numpy as np
import random as rnd
import matplotlib.pyplot as plt
from sklearn.preprocessing import LabelEncoder
from sklearn.preprocessing import OneHotEncoder
from keras.models import Sequential
from keras.utils import to_categorical
from keras.preprocessing import sequence
from keras.layers import Dense, Dropout, Embedding, LSTM, Bidirectional

# one hot encoding, eg. one_hot(['C','A','T','G'])
def one_hot(seq):
    enc = []
    for _ in seq:
        if _ == 'A':
            enc.append([1,0,0,0])
        elif _ == 'C':
            enc.append([0,1,0,0])
        elif _ == 'G':
            enc.append([0,0,1,0])
        elif _ == 'T':
            enc.append([0,0,0,1])
        else:
            print("Unexpected nucleotide during one-hot encoding")
    # Return encoding
    return enc

# create a sequence of nucleotides, e.g. x,y = gen_pair(10)
def gen_pair(length_dna):
    # create a sequence of random numbers in [0,1]
    x = np.array(rnd.choices(['A','C','G','T'], k=length_dna))
    # Define probability of DNA sequence
    y = 1/(1+np.exp(-(length_dna/2-(sum(x=='C')+sum(x=='G')))))
    # Return pair
    return x, y

# function to generate data, e.g. X,y=gen_data(5,10)
def gen_data(length_dna=50,sample_size=1000):
    # Initialize out vectors
    X_out = []
    y_out = []
    for _ in range(sample_size):
        # Generate pair (seq,prob)
        x,y = gen_pair(length_dna)
        X = one_hot(x)
        # Append
        X_out.append(X)
        y_out.append(y)
    # Pad X for keras
    X_out = sequence.pad_sequences(X_out, maxlen=length_dna, dtype='uint8')
    # Reshape: total sample size, number of time-points (nucleotides), number of vectors per time-points
    X_out = X_out.reshape(sample_size,length_dna,4)
    # Return sample_size pairs (X,y)
    return X_out,np.array(y_out)

# function to define network
def def_blstm(length_dna):
    # Define a sequential model
    model = Sequential()
    # Add a bidirectional LSTM layer with as many input units as time-points (nucleotides)
    model.add(Bidirectional(LSTM(length_dna,return_sequences=False),input_shape=(length_dna,4)))
    # Add dropout of 50% in training of BLSTM
    model.add(Dropout(0.5))
    # Add dense layer
    model.add(Dense(1,activation='sigmoid'))
    # Compile model with binary cross-entropy loss and use Adam for optimization
    model.compile(loss='mean_absolute_error', optimizer='adam')
    # Return model
    return model


# Define
length_dna = 50
sample_size = 250
x_train,y_train = gen_data(length_dna,sample_size)
x_test,y_test = gen_data(length_dna,sample_size)

# Define network
model = def_blstm(length_dna)

# Fit model
model.fit(x_train,y_train,epochs=4,validation_data=[x_test, y_test])

# evaluate BLSTM
x,y = gen_data(length_dna,10000)
yhat = np.ndarray.flatten(model.predict(x, verbose=0))
print("Corr(y,yhat):",np.corrcoef(y,yhat)[0,1])

# Plot histogram of difference
num_bins = 200
n, bins, patches = plt.hist(y-yhat, num_bins, range=(-1, 1), facecolor='blue', alpha=0.5)
