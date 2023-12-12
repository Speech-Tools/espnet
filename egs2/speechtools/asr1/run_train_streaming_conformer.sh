#!/usr/bin/env bash
# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

train_set="train_nodev"
valid_set="train_dev"
test_sets="test_clean"

feats_type=raw
local_data_opts=""

if [ "${feats_type}" = fbank_pitch ]; then
    local_data_opts="---pipe_wav true"
fi

./asr.sh \
    --stage 1 \
    --stop_stage 2 \
    --ngpu 4 \
    --token_type bpe \
    --local_data_opts "${local_data_opts}" \
    --nbpe 3192 \
    --lang kr \
    --lm_config conf/train_lm_transformer.yaml \
    --asr_config conf/train_asr_streaming_conformer.yaml \
    --inference_config conf/decode_asr.yaml \
    --train-set "${train_set}" \
    --valid-set "${valid_set}" \
    --test_sets "${test_sets}" \
    --bpe_nlsyms '[unk]' \
    --bpe_train_text "data/train_data_01/text" \
    --lm_train_text "data/train_data_01/text" "$@"
