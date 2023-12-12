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

DATA_ROOT="/host_shares/speechDATA"

stage=1
stop_stage=100000

skip_segmentation=true

ndev_utt=220
pipe_wav=false

log "$0 $*"
. utils/parse_options.sh

if [ $# -ne 0 ]; then
    log "Error: No positional arguments are required."
    exit 2
fi

. ./path.sh
. ./cmd.sh

train_set="train_transfer_nodev"
train_dev="train_transfer_dev"
test_set="test_transfer_clean"

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    log "stage 1: Data Download"
    log "Pass"
fi

if [ $stage -le 2 ] && [ ${stop_stage} -ge 2 ]; then
  # format the data as Kaldi data directories
  for part in train_data_transfer test_data_01; do
  	# use underscore-separated names in data directories.
  	local/data_prep.sh --pipe_wav "${pipe_wav}" "${DATA_ROOT}" "${part}"
  done
fi

if ! "${skip_segmentation}"; then
  if [ $stage -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    # update segmentation of transcripts
    for part in train_data_transfer test_data_01; do
      local/update_segmentation.sh data/$part data/local/lm
    done
  fi
fi

if [ $stage -le 4 ] && [ ${stop_stage} -ge 4 ]; then

  # shuffle whole training set
  utils/shuffle_list.pl data/train_data_transfer/utt2spk > utt2spk.tmp

  # make a dev set
  head -${ndev_utt} utt2spk.tmp | \
  utils/subset_data_dir.sh --utt-list - data/train_data_transfer "data/${train_dev}"

  # make a traing set
  n=$(($(wc -l < data/train_data_transfer/text) - ndev_utt))
  tail -${n} utt2spk.tmp | \
  utils/subset_data_dir.sh --utt-list - data/train_data_transfer "data/${train_set}"

  rm -f utt2spk.tmp

  # copy a test set
  utils/copy_data_dir.sh data/test_data_01 "data/${test_set}"
fi

log "Successfully finished. [elapsed=${SECONDS}s]"
