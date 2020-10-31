# NOTE: the script is supposed to be used called from nnsvs recipes.
# Please don't try to run the shell script directry.

for s in ${testsets[@]}; do
    for typ in timelag duration acoustic; do
        checkpoint=$expdir/$typ/latest.pth
        name=$(basename $checkpoint)
        xrun nnsvs-generate model.checkpoint=$checkpoint \
            model.model_yaml=$expdir/$typ/model.yaml \
            out_scaler_path=$dump_norm_dir/out_${typ}_scaler.joblib \
            in_dir=$dump_norm_dir/$s/in_${typ}/ \
            out_dir=$expdir/$typ/predicted/$s/${name%.*}/
    done
done