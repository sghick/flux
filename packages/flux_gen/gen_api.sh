#!/bin/bash
python3 gen_api.py -f
cd  ..
dart run build_runner build