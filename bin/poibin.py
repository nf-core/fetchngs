#!/usr/bin/env python

"""
https://github.com/tsakim/poibin
Created on Tue Mar 29, 2016
Module:
    poibin - Poisson Binomial Distribution
Author:
    Mika Straka
Description:
    Implementation of the Poisson Binomial distribution for the sum of
    independent and not identically distributed random variables as described
    in the reference [Hong2013]_.
    Implemented method:
        * ``pmf``: probability mass function
        * ``cdf``: cumulative distribution function
        * ``pval``: p-value (1 - cdf)
Usage:
    Be ``p`` a list or  NumPy array of success probabilities for ``n``
    non-identically distributed Bernoulli random variables.
    Import the module and create an instance of the distribution with::
        >>> from poibin import PoiBin
        >>> pb = PoiBin(p)
    Be ``x`` a list or NumPy array of different number of successes.
    To obtain the:
    * probability mass function of x, use::
        >>> pb.pmf(x)
    * cumulative distribution function of x, use::
        >>> pb.cdf(x)
    * p-values of x, use::
        >>> pb.pval(x)
    The functions are applied component-wise and a NumPy array of the same
    length as ``x`` is returned.
References:
.. [Hong2013] Yili Hong, On computing the distribution function for the Poisson
    binomial distribution,
    Computational Statistics & Data Analysis, Volume 59, March 2013,
    Pages 41-51, ISSN 0167-9473,
    http://dx.doi.org/10.1016/j.csda.2012.10.006.
"""

import collections
import numpy as np


class PoiBin(object):
    """Poisson Binomial distribution for random variables.
    This class implements the Poisson Binomial distribution for Bernoulli
    trials with different success probabilities. The distribution describes
    thus a random variable that is the sum of independent and not identically
    distributed single Bernoulli random variables.
    The class offers methods for calculating the probability mass function, the
    cumulative distribution function, and p-values for right-sided testing.
    """

    def __init__(self, probabilities):
        """Initialize the class and calculate the ``pmf`` and ``cdf``.
        :param probabilities: sequence of success probabilities :math:`p_i \\in
            [0, 1] \\forall i \\in [0, N]` for :math:`N` independent but not
            identically distributed Bernoulli random variables
        :type probabilities: numpy.array
        """
        self.success_probabilities = np.array(probabilities)
        self.number_trials = self.success_probabilities.size
        self.check_input_prob()
        self.omega = 2 * np.pi / (self.number_trials + 1)
        self.pmf_list = self.get_pmf_xi()
        self.cdf_list = self.get_cdf(self.pmf_list)

# ------------------------------------------------------------------------------
# Methods for the Poisson Binomial Distribution
# ------------------------------------------------------------------------------

    def pmf(self, number_successes):
        """Calculate the probability mass function ``pmf`` for the input values.
        The ``pmf`` is defined as
        .. math::
            pmf(k) = Pr(X = k), k = 0, 1, ..., n.
        :param number_successes: number of successful trials for which the
            probability mass function is calculated
        :type number_successes: int or list of integers
        """
        self.check_rv_input(number_successes)
        return self.pmf_list[number_successes]

    def cdf(self, number_successes):
        """Calculate the cumulative distribution function for the input values.
        The cumulative distribution function ``cdf`` for a number ``k`` of
        successes is defined as
        .. math::
            cdf(k) = Pr(X \\leq k), k = 0, 1, ..., n.
        :param number_successes: number of successful trials for which the
            cumulative distribution function is calculated
        :type number_successes: int or list of integers
        """
        self.check_rv_input(number_successes)
        return self.cdf_list[number_successes]

    def pval(self, number_successes):
        """Return the p-values corresponding to the input numbers of successes.
        The p-values for right-sided testing are defined as
        .. math::
            pval(k) = Pr(X \\geq k ),  k = 0, 1, ..., n.
        .. note::
            Since :math:`cdf(k) = Pr(X <= k)`, the function returns
            .. math::
                1 - cdf(X < k) & = 1 - cdf(X <= k - 1)
                               & = 1 - cdf(X <= k) + pmf(X = k),
                               k = 0, 1, .., n.
        :param number_successes: number of successful trials for which the
            p-value is calculated
        :type number_successes: int, numpy.array, or list of integers
        """
        self.check_rv_input(number_successes)
        i = 0
        try:
            isinstance(number_successes, collections.Iterable)
            pvalues = np.array(number_successes, dtype='float')
            # if input is iterable (list, numpy.array):
            for k in number_successes:
                pvalues[i] = 1. - self.cdf(k) + self.pmf(k)
                i += 1
            return pvalues
        except TypeError:
            # if input is an integer:
            if number_successes == 0:
                return 1
            else:
                return 1 - self.cdf(number_successes - 1)

# ------------------------------------------------------------------------------
# Methods to obtain pmf and cdf
# ------------------------------------------------------------------------------

    def get_cdf(self, event_probabilities):
        """Return the values of the cumulative density function.
        Return a list which contains all the values of the cumulative
        density function for :math:`i = 0, 1, ..., n`.
        :param event_probabilities: array of single event probabilities
        :type event_probabilities: numpy.array
        """
        cdf = np.empty(self.number_trials + 1)
        cdf[0] = event_probabilities[0]
        for i in range(1, self.number_trials + 1):
            cdf[i] = cdf[i - 1] + event_probabilities[i]
        return cdf

    def get_pmf_xi(self):
        """Return the values of the variable ``xi``.
        The components ``xi`` make up the probability mass function, i.e.
        :math:`\\xi(k) = pmf(k) = Pr(X = k)`.
        """
        chi = np.empty(self.number_trials + 1, dtype=complex)
        chi[0] = 1
        half_number_trials = int(
            self.number_trials / 2 + self.number_trials % 2)
        # set first half of chis:
        chi[1:half_number_trials + 1] = self.get_chi(
            np.arange(1, half_number_trials + 1))
        # set second half of chis:
        chi[half_number_trials + 1:self.number_trials + 1] = np.conjugate(
            chi[1:self.number_trials - half_number_trials + 1] [::-1])
        chi /= self.number_trials + 1
        xi = np.fft.fft(chi)
        if self.check_xi_are_real(xi):
            xi = xi.real
        else:
            raise TypeError("pmf / xi values have to be real.")
        xi += np.finfo(type(xi[0])).eps
        return xi

    def get_chi(self, idx_array):
        """Return the values of ``chi`` for the specified indices.
        :param idx_array: array of indices for which the ``chi`` values should
            be calculated
        :type idx_array: numpy.array
        """
        # get_z:
        exp_value = np.exp(self.omega * idx_array * 1j)
        xy = 1 - self.success_probabilities + \
            self.success_probabilities * exp_value[:, np.newaxis]
        # sum over the principal values of the arguments of z:
        argz_sum = np.arctan2(xy.imag, xy.real).sum(axis=1)
        # get d value:
        exparg = np.log(np.abs(xy)).sum(axis=1)
        d_value = np.exp(exparg)
        # get chi values:
        chi = d_value * np.exp(argz_sum * 1j)
        return chi

# ------------------------------------------------------------------------------
# Auxiliary functions
# ------------------------------------------------------------------------------

    def check_rv_input(self, number_successes):
        """Assert that the input values ``number_successes`` are OK.
        The input values ``number_successes`` for the random variable have to be
        integers, greater or equal to 0, and smaller or equal to the total
        number of trials ``self.number_trials``.
        :param number_successes: number of successful trials
        :type number_successes: int or list of integers """
        try:
            for k in number_successes:
                assert (type(k) == int or type(k) == np.int64), \
                        "Values in input list must be integers"
                assert k >= 0, 'Values in input list cannot be negative.'
                assert k <= self.number_trials, \
                    'Values in input list must be smaller or equal to the ' \
                    'number of input probabilities "n"'
        except TypeError:
            assert (type(number_successes) == int or \
                type(number_successes) == np.int64), \
                'Input value must be an integer.'
            assert number_successes >= 0, "Input value cannot be negative."
            assert number_successes <= self.number_trials, \
                'Input value cannot be greater than ' + str(self.number_trials)
        return True

    @staticmethod
    def check_xi_are_real(xi_values):
        """Check whether all the ``xi``s have imaginary part equal to 0.
        The probabilities :math:`\\xi(k) = pmf(k) = Pr(X = k)` have to be
        positive and must have imaginary part equal to zero.
        :param xi_values: single event probabilities
        :type xi_values: complex
        """
        return np.all(xi_values.imag <= np.finfo(float).eps)

    def check_input_prob(self):
        """Check that all the input probabilities are in the interval [0, 1]."""
        if self.success_probabilities.shape != (self.number_trials,):
            raise ValueError(
                "Input must be an one-dimensional array or a list.")
        if not np.all(self.success_probabilities >= 0):
            raise ValueError("Input probabilities have to be non negative.")
        if not np.all(self.success_probabilities <= 1):
            raise ValueError("Input probabilities have to be smaller than 1.")

################################################################################
# Main
################################################################################

if __name__ == "__main__":
    pass
