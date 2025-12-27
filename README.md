# Pengembangan Sistem _Frequency Analyzer_ Digital Berbasis _Fast Fourier Transform_ 64-Titik Radix-2 pada FPGA Cyclone IV untuk Optimasi _Zero-Crossing Switching_

### EL2002 Final Project, Group 28

Project Assigned by: Nana Sutisna,. S.T., M.T., Ph.D.

### Team:
- Muhammad Adli Syauqi (13224082)
- Muhammad Ammar Hanif (13224087)
- Moch Dimas Ristanto (13224083)

### Version Working:
The working version are the one inside **_v5_32_16_** (32 POINT, 16 bit per POINT) and **_v5_64_8_** (64 POINT, 8 bit per POINT). 

Note that there's a bug for **_v5_32_16_** the version, because it can output the correct and false output randomly (with the same exact input). Therefore, to get the correct output, just retry uploading the input until you get the similar output as the expected output.

The main revision was to use the memory-based architecture rather than the SDF architecture. This change has to be done because of the **Logic Element (LE)** limitation in the Cyclone IV FPGA.