#!/bin/bash
#
# Job-submitting experiment example.
# The resulting experiment .sh file is expected to be located in exp/experiments/
#
# usage: $ exp/experiments/exp_METALEARN_EXPERIMENT.sh
#
# options:
#   -n | --dry-run      no submittion will happen, only print what should be done
#
# see also:
#   exp/bash_settings.sh
#   exp/metacentrum_metalearn_common.sh

#export EXPID='exp_METALEARN_EXPERIMENT'
export EXPID='exp_metaLearn_02'

# Enable this option for using Matlab MCR compilated binaries:
export useMCR=1

# !!! THIS HAS TO BE HERE !!!
#     vvvvvvvvvvvvvvvvvvv
CWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. $CWD/../bash_settings.sh
. $CWD/../metacentrum_metalearn_common.sh
#     ^^^^^^^^^^^^^^^^^^^
# !!! THIS HAS TO BE HERE !!!

# job submittion can be done via one of the following bash functions:
#
# (a) subtask [JOBNAME_SUFFIX]
#
#     submits a job with current-set $ID, $DIM, $FUNC, $INST and $OPTS
#
#
# (b) submit_sequence LOW_IDX STEP HIGH_IDX
#
#     call subtask() with 'modelOptionsIndices' set to a small
#     numbers of model-settings;
#     it submits a job for every $2 consecutive modelOptions' indices
#
#     e.g.: submit 11 4 22
#     submits jobs for the following modelOption indices:
#       - 11:14
#       - 15:18
#       - 19:22
#
#     Important: the HIGH_IDX should be the equal to (k*LOW_IDX) - 1
#                for some k
#
#
# (c) submit_model MODEL DIMS FUNCS INSTS DESIGNS DATASIZES
#
#     submit_sequence covering all options of given model is called
#     for every combination of dims, functions, instances, sampling designs
#     and data sizes
#
#     e.g.: submit_model "GP" DIMS FUNCS INSTS DESIGNS DATASIZES

# critical characters has to be replaced in $OPTS:
# '|' with ',' and "%" with "'" and '@' with ';'
OPTS=""

DATASET_PATH=$CWD/data_metalearn

ID="1"
DIMS="2 5 10"
FUNCS=`seq 1 24`
INSTS="[1:5,41:50]"
DESIGNS="lhs"
DATASIZES="50*dim"
OPTS=( 1 2 3 4 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 26 27 28 29 30 )

QUEUE="24:00:00"
submit_model "FOREST" "$DIMS" "$FUNCS" "$INSTS" "$DESIGNS" "$DATASIZES" "${OPTS[@]}"

OPTS=( 21 22 23 24 25 )
INSTS="`seq 1 5` `seq 41 50`"
QUEUE="48:00:00"
submit_model "FOREST" "$DIMS" "$FUNCS" "$INSTS" "$DESIGNS" "$DATASIZES"

exit 0