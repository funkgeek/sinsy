#!/bin/bash

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

function xrun () {
    set -x
    $@
    set +x
}

script_dir=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
NNSVS_ROOT=$script_dir/../../../
NNSVS_COMMON_ROOT=$NNSVS_ROOT/recipes/_common/spsvs
. $NNSVS_ROOT/utils/yaml_parser.sh || exit 1;

eval $(parse_yaml "./config.yaml" "")

train_set="train_no_dev"
dev_set="dev"
eval_set="eval"
datasets=($train_set $dev_set $eval_set)
testsets=($dev_set $eval_set)

dumpdir=dump

dump_org_dir=$dumpdir/$spk/org
dump_norm_dir=$dumpdir/$spk/norm

stage=0
stop_stage=0

. $NNSVS_ROOT/utils/parse_options.sh || exit 1;

# exp name
if [ -z ${tag:=} ]; then
    expname=${spk}
else
    expname=${spk}_${tag}
fi
expdir=exp/$expname

if [ ${stage} -le -1 ] && [ ${stop_stage} -ge -1 ]; then
    if [ ! -d downloads/HTS-demo_NIT-SONG070-F001 ]; then
        echo "stage -1: Downloading NIT-SONG070-F001"
        mkdir -p downloads
        cd downloads
        curl -LO http://hts.sp.nitech.ac.jp/archives/2.3/HTS-demo_NIT-SONG070-F001.tar.bz2
        tar jxvf HTS-demo_NIT-SONG070-F001.tar.bz2
        cd -
    fi
    if [ ! -d downloads/jsut-song_ver1 ]; then
        echo "stage -1: Downloading JSUT-song"
        cd downloads
        curl -LO https://ss-takashi.sakura.ne.jp/corpus/jsut-song_ver1.zip
        unzip jsut-song_ver1.zip
        cd -
    fi
    if [ ! -d downloads/todai_child ]; then
        echo "stage -1: Downloading JSUT-song labels"
        cd downloads
        curl -LO https://ss-takashi.sakura.ne.jp/corpus/jsut-song_label.zip
        unzip jsut-song_label.zip
        cd -
    fi
fi

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    echo "stage 0: Data preparation"
    python local/data_prep.py ./downloads/jsut-song_ver1 \
        ./downloads/todai_child/ \
        ./downloads/HTS-demo_NIT-SONG070-F001/ data
    echo "train/dev/eval split"
    mkdir -p data/list
    # exclude 045 since the label file is not available
    find data/acoustic/ -type f -name "*.wav" -exec basename {} .wav \; \
        | grep -v 045 | sort > data/list/utt_list.txt
    grep 003 data/list/utt_list.txt > data/list/$eval_set.list
    grep 004 data/list/utt_list.txt > data/list/$dev_set.list
    grep -v 003 data/list/utt_list.txt | grep -v 004 > data/list/$train_set.list
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo "stage 1: Feature generation"
    . $NNSVS_COMMON_ROOT/feature_generation.sh
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "stage 2: Training time-lag model"
    . $NNSVS_COMMON_ROOT/train_timelag.sh
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 3: Training duration model"
    . $NNSVS_COMMON_ROOT/train_duration.sh
fi

if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    echo "stage 4: Training acoustic model"
    . $NNSVS_COMMON_ROOT/train_acoustic.sh
fi

if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
    echo "stage 5: Generate features from timelag/duration/acoustic models"
    . $NNSVS_COMMON_ROOT/generate.sh
fi

if [ ${stage} -le 6 ] && [ ${stop_stage} -ge 6 ]; then
    echo "stage 6: Synthesis waveforms"
    . $NNSVS_COMMON_ROOT/synthesis.sh
fi
