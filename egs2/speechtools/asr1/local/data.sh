#!/usr/bin/env bash
# Copyright 2020 Electronics and Telecommunications Research Institute (Hoon Chung)
# Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}
SECONDS=0

DATA_ROOT="speechDATA"

stage=1
stop_stage=100000

ndev_utt=220

log "$0 $*"
. utils/parse_options.sh

if [ $# -ne 0 ]; then
    log "Error: No positional arguments are required."
    exit 2
fi

. ./path.sh
. ./cmd.sh

train_set="train_nodev"
train_dev="train_dev"
test_set="test_clean"

if [ $stage -le 1 ] && [ ${stop_stage} -ge 1 ]; then
  # format the data as Kaldi data directories
  for part in train_data_01 test_data_01; do
  	# use underscore-separated names in data directories.
    log "$0: Start data prep local/data_prep.py ${part}"
    python local/data_prep.py \
        --db_dir "${DATA_ROOT}" \
        --data_part "${part}"
    
    dst=data/${part}
    wav_scp=$dst/wav.scp
    trans=$dst/text
    utt2spk=data/${part}/utt2spk
    spk2utt=data/${part}/spk2utt

    # Sort
    cat $wav_scp | sort > tmp
    cp tmp $wav_scp
    cat $trans | sort > tmp
    cp tmp $trans
    cat $utt2spk | sort > tmp
    cp tmp $utt2spk
    rm tmp

    # Make spk2utt using utt2spk
    utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1

    # Check data dir
    utils/validate_data_dir.sh --no-feats data/${part} || exit 1;

    log "$0: successfully prepared data in data/${part}"
  done
fi

if [ $stage -le 2 ] && [ ${stop_stage} -ge 2 ]; then
  # shuffle whole training set
  utils/shuffle_list.pl data/train_data_01/utt2spk > utt2spk.tmp

  # make a dev set
  head -${ndev_utt} utt2spk.tmp | \
  utils/subset_data_dir.sh --utt-list - data/train_data_01 "data/${train_dev}"

  # make a traing set
  n=$(($(wc -l < data/train_data_01/text) - ndev_utt))
  tail -${n} utt2spk.tmp | \
  utils/subset_data_dir.sh --utt-list - data/train_data_01 "data/${train_set}"

  rm -f utt2spk.tmp

  # copy a test set
  utils/copy_data_dir.sh data/test_data_01 "data/${test_set}"
fi

log "Successfully finished. [elapsed=${SECONDS}s]"
