asr_exp=speechDATA/exp/asr_train_asr_streaming_conformer_raw_kr_bpe3569
lm_exp=speechDATA/exp/lm_train_lm_transformer_kr_bpe3569

python -m espnet2.bin.pack asr \
    --asr_train_config "${asr_exp}"/config.yaml \
    --asr_model_file "${asr_exp}"/7epoch.pth \
    --lm_train_config "${lm_exp}"/config.yaml \
    --lm_file "${lm_exp}"/25epoch.pth \
    --option data/kr_token_list/bpe_unigram3569/bpe.model \
    --outpath last.zip
