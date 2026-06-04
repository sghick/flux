#!/bin/bash
rm -rf ../lib/routes
python3 gen_pages.py init
python3 gen_pages.py routes
python3 gen_pages.py generate
git add ..