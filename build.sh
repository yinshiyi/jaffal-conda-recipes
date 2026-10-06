#!/bin/bash

# Setup path variables
BINARY_HOME=$PREFIX/bin
PACKAGE_HOME=$PREFIX/share/$PKG_NAME-$PKG_VERSION-$PKG_BUILDNUM

# Create destination directories
mkdir -p $PACKAGE_HOME
mkdir -p $BINARY_HOME

# Copy files over into $PACKAGE_HOME
cp -aR * $PACKAGE_HOME

# Compile JAFFA's helper programs into the conda environment. These binaries
# must match the Groovy pipeline from the same JAFFA release.
for tool in \
    process_transcriptome_align_table \
    make_3_gene_fusion_table \
    make_count_table \
    make_final_table \
    extract_seq_from_fasta \
    make_simple_read_table \
    make_simple_read_table_assembly \
    compile_results \
    split_fusion_reads \
    prepare_ref_helper; do
    $CXX -std=c++11 -O3 -o "$BINARY_HOME/$tool" "$PACKAGE_HOME/src/$tool.c++"
done

# Create wrappers
SOURCE_FILE=$RECIPE_DIR/run-jaffa.sh
for suffix in direct assembly hybrid jaffal; do
    DEST_FILE=$PACKAGE_HOME/jaffa-$suffix

    echo "#!/bin/bash" > $DEST_FILE
    echo "PKG_NAME=$PKG_NAME" >> $DEST_FILE
    echo "PKG_VERSION=$PKG_VERSION" >> $DEST_FILE
    echo "PACKAGE_HOME=$PACKAGE_HOME" >> $DEST_FILE
    echo "RUNMODE=$suffix" >>$DEST_FILE
    cat $SOURCE_FILE >> $DEST_FILE

    chmod +x $DEST_FILE
    if [ "$suffix" = "jaffal" ]; then
        ln -s $DEST_FILE $PREFIX/bin/jaffal
    else
        ln -s $DEST_FILE $PREFIX/bin/jaffa-$suffix
    fi
done

# prepare_jaffa_reference.sh looks up every tool at <JAFFA_PATH>/tools/bin/<name>
# (the layout install_linux64.sh creates). Recreate that layout inside the package
# with symlinks to the conda binaries, renaming where JAFFA expects a different
# name. conda-build rewrites these absolute links as relative ones.
mkdir -p $PACKAGE_HOME/tools/bin
for pair in prepare_ref_helper:prepare_ref_helper gffread_bin:gffread reformat:reformat.sh \
            bedtools:bedtools minimap2:minimap2 bowtie2-build:bowtie2-build \
            makeblastdb:makeblastdb gtfToGenePred:gtfToGenePred; do
    ln -s $BINARY_HOME/${pair#*:} $PACKAGE_HOME/tools/bin/${pair%%:*}
done

# Expose the reference builder with JAFFA_PATH pre-filled
PREPARE_DEST=$BINARY_HOME/prepare_jaffa_reference.sh
echo "#!/bin/bash" > $PREPARE_DEST
echo "export PATH=\"\$(dirname \"\$0\"):\$PATH\"" >> $PREPARE_DEST
echo "exec bash $PACKAGE_HOME/prepare_jaffa_reference.sh $PACKAGE_HOME \"\$@\"" >> $PREPARE_DEST
chmod +x $PREPARE_DEST
