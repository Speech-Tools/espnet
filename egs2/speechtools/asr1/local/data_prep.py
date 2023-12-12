"""
Python으로 구현한 Kaldi-Style 데이터 준비 스크립트
"""

import argparse
import subprocess
from glob import glob
from pathlib import Path
from typing import Union


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


def prepare_data(
    db_dir: Union[str, Path],
    data_part: Union[str, Path],
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
    transcripts = []
    wavs = []
    utt2spks = []
    print(f"Start find txt files in {src_dir}")

    

    for i, txt_file in enumerate(sorted(src_dir.rglob("*.txt"))):
        # '.txt' 파일에서 `label` 경로를 `source`로 바꾸고
        # 확장자를 '.wav'로 바꾸면 wav 파일 경로가 되도록 데이터셋을 구성함
        wav_file = str(txt_file).replace('label', 'source')
        wav_file = Path(wav_file).with_suffix('.wav')
        if not wav_file.is_file():
            # wav 파일이 없다면 이번 데이터는 패스
            print(f"No matching wav file to '{txt_file}'")
            continue

        # Prepare text
        utt_id = str(i)
        with open(txt_file, 'r') as f:
            utt = f.read().strip()

        transcript = f"{utt_id} {utt}"
        transcripts.append(transcript)

        # Prepare wav.scp
        wav_line = f"{utt_id} {wav_file.absolute()}"
        wavs.append(wav_line)

        # Prepare utt2spk
        # Actually, we don't use speaker information.
        utt2spk_line = f"{utt_id} {utt_id}"
        utt2spks.append(utt2spk_line)

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

