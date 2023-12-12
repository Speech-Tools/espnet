#!/usr/bin/env bash

# Copyright  2018  Atlas Guide (Author : Lucas Jo)
#            2018  Gridspace Inc. (Author: Wonkyum Lee)
# Apache 2.0


set -euo pipefail
log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}
# Modified by Lucas Jo 2017 (Altas Guide)
pipe_wav=false

log "$0 $*"
. utils/parse_options.sh

if [ "$#" -ne 2 ]; then
  log "Usage: $0 <db-dir> <part>"
  log "e.g.: $0 ./db/train_data_01 data/train_data_01"
  exit 1
fi

db_dir=$1
data_part=$2

src=${db_dir}/${data_part}
dst=data/${data_part}

# all utterances are FLAC compressed

mkdir -p $dst || exit 1;

[ ! -d $src ] && log "$0: no such directory $src" && exit 1;

wav_scp=$dst/wav.scp; [[ -f "$wav_scp" ]] && rm $wav_scp
trans=$dst/text; [[ -f "$trans" ]] && rm $trans
utt2spk=$dst/utt2spk; [[ -f "$utt2spk" ]] && rm $utt2spk
utt2dur=$dst/utt2dur; [[ -f "$utt2dur" ]] && rm $utt2dur

for scriptid_dir in $(find -L $src -mindepth 1 -maxdepth 1 -type d | sort); do
  scriptid=$(basename $scriptid_dir)
  # LSH
  #if ! [ $scriptid -eq $scriptid ]; then  # not integer.
  #  log "$0: unexpected subdirectory name $scriptid"
  #  exit 1;
  #fi

  for reader_dir in $(find -L $scriptid_dir/ -mindepth 1 -maxdepth 1 -type d | sort); do
    reader=$(basename $reader_dir)
    # LSH
    #if ! [ "$reader" -eq "$reader" ]; then
    #  log "$0: unexpected reader-subdirectory name $reader"
    #  exit 1;
    #fi

    if "${pipe_wav}"; then
        find -L $reader_dir/ -iname "*.flac" | sort | xargs -I% basename % .flac | \
            awk -v "dir=$reader_dir" '{printf "%s flac -c -d -s %s/%s.flac |\n", $0, dir, $0}' >>$wav_scp|| exit 1
    else
        find -L $reader_dir/ -iname "*.flac" | sort | xargs -I% basename % .flac | \
            awk -v "dir=$reader_dir" '{printf "%s %s/%s.flac\n", $0, dir, $0}' >>$wav_scp|| exit 1
    fi

	reader_trans=$reader_dir/${reader}_${scriptid}.trans.txt
    [ ! -f  $reader_trans ] && log "$0: expected file $reader_trans to exist" && exit 1
    cat $reader_trans >>$trans

    cat $reader_trans | cut -f 1 -d ' ' | awk '{printf "%s %s\n", $0, $0}' >> $utt2spk || exit 1

    # NOTE: Each chapter is dedicated to each speaker.
    #awk -v "reader=$reader" -v "scriptid=$scriptid" '{printf "%s %s_%s\n", $1, reader, scriptid}' \
    #  <$reader_trans >>$utt2spk || exit 1

  done
done

# sort
cat $wav_scp    | sort > tmp
cp tmp $wav_scp
cat $trans      | sort > tmp
cp tmp $trans
cat $utt2spk    | sort > tmp
cp tmp $utt2spk
rm tmp


spk2utt=$dst/spk2utt
utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1

ntrans=$(wc -l <$trans)
nutt2spk=$(wc -l <$utt2spk)
! [ "$ntrans" -eq "$nutt2spk" ] && \
  log "Inconsistent #transcripts($ntrans) and #utt2spk($nutt2spk)" && exit 1;

utils/validate_data_dir.sh --no-feats $dst || exit 1;

log "$0: successfully prepared data in $dst"
