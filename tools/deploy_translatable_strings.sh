#!/bin/bash

# This code is part of Qiskit.
#
# (C) Copyright IBM 2018, 2021.
#
# This code is licensed under the Apache License, Version 2.0. You may
# obtain a copy of this license in the LICENSE.txt file in the root directory
# of this source tree or at http://www.apache.org/licenses/LICENSE-2.0.
#
# Any modifications or derivative works of this code must retain this
# copyright notice, and modified files need to carry a notice indicating
# that they have been altered from the originals.

# Script for pushing the translatable strings to qiskit-translations repo.

# Non-travis variables used by this script.
SOURCE_REPOSITORY="git@github.com:Qiskit/qiskit-finance.git"
SOURCE_DIR=`pwd`
SOURCE_LANG='en'

TARGET_REPOSITORY="git@github.com:qiskit-community/qiskit-translations.git"
TARGET_BRANCH_PO="master"

DOC_DIR_PO="docs/locale/"

echo "show current dir: "
pwd

pushd docs

# Extract document's translatable messages into pot files
# https://sphinx-intl.readthedocs.io/en/master/quickstart.html
echo "Extract document's translatable messages into pot files and generate po files"
tox -egettext -- -D language=$SOURCE_LANG

echo "Setup ssh keys"
pwd
set -e
# Add qiskit-translations push key to ssh-agent
openssl enc -aes-256-cbc -d -in ../tools/github_poBranch_update_key.enc -out github_poBranch_deploy_key -K $encrypted_deploy_po_branch_key -iv $encrypted_deploy_po_branch_iv
chmod 600 github_poBranch_deploy_key
eval $(ssh-agent -s)
ssh-add github_poBranch_deploy_key

# Clone to the working repository for .po and pot files
popd
pwd
echo "git clone for working repo"
git clone --depth 1 $TARGET_REPOSITORY temp --single-branch --branch $TARGET_BRANCH_PO
pushd temp

git config user.name "Qiskit (Finance) Autodeploy"
git config user.email "qiskit@qiskit.org"

echo "git rm -rf for the translation po files"
git rm -rf --ignore-unmatch finance/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/*.po \
    finance/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/api \
    finance/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/apidocs \
    finance/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/stubs \
    finance/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/release_notes.po \
    finance/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/theme \
    finance/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/_*

# Remove api/ and apidoc/ to avoid confusion while translating
rm -rf $SOURCE_DIR/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/api/ \
    $SOURCE_DIR/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/apidocs \
    $SOURCE_DIR/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/stubs \
    $SOURCE_DIR/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/release_notes.po \
    $SOURCE_DIR/$DOC_DIR_PO/$SOURCE_LANG/LC_MESSAGES/theme/

# Copy the new rendered files and add them to the commit.
echo "copy directory"
cp -r $SOURCE_DIR/$DOC_DIR_PO/ finance/docs
cp $SOURCE_DIR/setup.py finance/.
cp $SOURCE_DIR/requirements-dev.txt finance/.
cp $SOURCE_DIR/requirements.txt finance/.
cp $SOURCE_DIR/qiskit_finance/VERSION.txt finance/qiskit_finance/.

# git checkout translationDocs
echo "add to po files to target dir"
git add finance/

# Commit and push the changes.
git commit -m "[Qiskit Finance] Automated documentation update to add .po files" -m "skip ci" -m "Commit: $GITHUB_SHA" -m "Github Actions Run: https://github.com/Qiskit/qiskit/runs/$GITHUB_RUN_NUMBER"
echo "git push"
git push --quiet origin $TARGET_BRANCH_PO
echo "********** End of pushing po to working repo! *************"
popd
