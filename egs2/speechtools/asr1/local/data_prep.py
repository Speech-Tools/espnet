"""
Python으로 구현한 Kaldi-Style 데이터 준비 스크립트
"""
import math
import argparse
import subprocess
import numpy as np
from glob import glob
from pathlib import Path
from typing import Union, List, Tuple
from multiprocessing import Pool


DATA = Path("data")


def get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SpeechTools asr1 data preparation")

    parser.add_argument(
        "--db_dir",
        type=str,
        required=True,
        help="Database Root directory"
    )
    parser.add_argument(
        "--data_part",
        type=str,
        required=True,
        help="Part of database"
    )
    return parser

def process_one(txt_file: Tuple[int, Path]):
    i, txt_file_path = txt_file
        
    wav_file = str(txt_file_path).replace('label', 'source')
    wav_file = Path(wav_file).with_suffix('.wav')
    if not wav_file.is_file():
        # wav 파일이 없다면 이번 데이터는 패스
        print(f"No matching wav file to '{txt_file_path}'")
        return (None, None, None)

    # Prepare text
    utt_id = str(i)
    with open(txt_file_path, 'r') as f:
        utt = f.read().strip()
        utt = utt.replace('\n',' ')

        # utt가 없다면 패스
        if len(utt) < 1:
            return (None, None, None)

    transcript = f"{utt_id} {utt}"

    # Prepare wav.scp
    wav_line = f"{utt_id} {wav_file.absolute()}"

    # Prepare utt2spk
    # Actually, we don't use speaker information.
    utt2spk_line = f"{utt_id} {utt_id}"

    return (transcript, wav_line, utt2spk_line)

def work(txt_files: List[Tuple[int, Path]]):
    outputs = list(map(process_one, txt_files))
    outputs = [output for output in outputs if output[0] != None]
    print(f"Done multiprocess id: {txt_files[0][0]}")
    return outputs

def prepare_data(
    db_dir: Union[str, Path],
    data_part: Union[str, Path],
    nj: int = 256,
):
    db_dir = Path(db_dir)
    data_part = Path(data_part)
    
    src_dir = (db_dir / data_part).absolute()
    dst_dir = (DATA / data_part).absolute()

    if not dst_dir.is_dir():
        dst_dir.mkdir(parents=True, exist_ok=True)

    if not src_dir.is_dir():
        raise FileNotFoundError(f"No such directorry: {src_dir}")

    wav_scp = dst_dir / "wav.scp"
    trans = dst_dir / "text"
    utt2spk = dst_dir / "utt2spk"
    spk2utt = dst_dir / "spk2utt"
    
    # Remove if exists
    wav_scp.unlink(missing_ok=True)
    trans.unlink(missing_ok=True)
    utt2spk.unlink(missing_ok=True)
    spk2utt.unlink(missing_ok=True)
            
    # Prepare `text`
    ## '.txt' 파일 탐색
    ## utt id는 순서대로 임의로 붙이기
    print(f"Start find txt files in {src_dir}")

    target_txts = list(enumerate(sorted(src_dir.rglob('*.txt'))))
    target_txts = [(str(target_txt[0]).zfill(10), target_txt[1]) for target_txt in target_txts]
    div = math.ceil(len(target_txts) / nj)
    div_target_txts = [target_txts[i*div:(i+1)*div] for i in range((len(target_txts)+div-1) // div)]

    with Pool(nj) as p:
        results = p.map(work, div_target_txts)

    transcripts = []
    wavs = []
    utt2spks = []
    for result in results:
        for transcript, wav_line, utt2spk_line in result:
            transcripts.append(transcript)
            wavs.append(wav_line)
            utt2spks.append(utt2spk_line)

    # Sort
    transcripts.sort()
    wavs.sort()
    utt2spks.sort()

    # Check data
    if len(transcripts) != len(utt2spks):
        raise ValueError(f"Inconsistent #transcripts(${len(transcripts)}) and #utt2spks(${len(utt2spks)})")
   
    # Write 'text'
    with open(trans, 'w') as f:
        print(f"Write text to {trans}, size: {len(transcripts)}")
        f.write('\n'.join(transcripts) + '\n')

    # Write 'wav.scp'
    with open(wav_scp, 'w') as f:
        print(f"Write wav.scp to {wav_scp}, size: {len(wavs)}")
        f.write('\n'.join(wavs) + '\n')

    # Write 'utt2spk'
    with open(utt2spk, 'w') as f:
        print(f"Write utt2spk to {utt2spk}, size: {len(utt2spks)}")
        f.write('\n'.join(utt2spks) + '\n')


def main():
    parser = get_parser()
    args = parser.parse_args()
    
    prepare_data(args.db_dir, args.data_part)


if __name__=="__main__":
    main()

