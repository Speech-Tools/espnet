#!/usr/bin/env bash
# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

train_set="train_transfer_nodev"
valid_set="train_transfer_dev"
test_sets="test_transfer_clean"

feats_type=raw
local_data_opts=""

if [ "${feats_type}" = fbank_pitch ]; then
    local_data_opts="---pipe_wav true"
fi

./asr_transfer.sh \
    --stage 6 \
    --token_type bpe \
    --local_data_opts "${local_data_opts}" \
    --nbpe 3192 \
    --lang kr \
    --lm_config conf/train_lm.yaml \
    --asr_config conf/train_asr_conformer.yaml \
    --inference_config conf/decode_asr.yaml \
    --train_set "${train_set}" \
    --valid_set "${valid_set}" \
    --test_sets "${test_sets}" \
    --bpe_nlsyms '[unk]' \
    --bpe_train_text "data_conformer_120h/train_data_01/text" \
    --lm_train_text "data/train_data_transfer/text" \
    --pretrained_model temp/asr.pth \
    --pretrained_lm temp/lm.pth "$@"
