flac -l 12 -b 1024 -m -p -e -f -o stream.lossy.flac stream.lossy.wav
flac -l 12 -b 4608 -m -p -e -f -o stream.lpc.flac stream.wav
flac -l 0 -b 4608 -m -p -e -f -o stream.fixed.flac stream.wav
flac -l 0 -r 0 -b 4608 -m -p -e -f -o stream.fzo.flac stream.wav
flac -l 0 -b 4608 -m -p -e -f --disable-fixed-subframes -o stream.vbt.flac stream.wav
