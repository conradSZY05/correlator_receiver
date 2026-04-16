# correlator_receiver
correlator receiver implemented on a Basys 3 FPGA, written in VHDL, with C++ scripting for capturing and packaging raw I/Q data for real time plotting over VGA

# Antenna
Here are the antenna I've made and used so far, its been a fun topic to learn about, I got most of my information [here](https://discussions.flightaware.com/t/three-easy-diy-antennas-for-beginners/16348/2), great site full of useful information.
<img width="1215" height="1620" alt="image" src="https://github.com/user-attachments/assets/8d24474a-4399-4744-b7c6-44f6ec1c3d0f" />
<img width="1215" height="1620" alt="image" src="https://github.com/user-attachments/assets/71dfc22f-8506-49e5-8ce4-0afc63e2cb4c" />
<img width="1215" height="1620" alt="image" src="https://github.com/user-attachments/assets/aba029b4-a283-4b29-a763-1aef438b4dbb" />

# I/Q data
The RTL-SDR Blog v4 comes with some handy tools, one in particular is rtl_sdr.exe. You can find these tools [here](https://github.com/rtlsdrblog/rtl-sdr-blog/releases) but i also included the tools I used in this repo. The official RTL-SDR website also has some helpful tutorials on getting everything set up. I recommend NOT using a Windows PC for ANYTHING related to RTL-SDR unless you want a headache, it will just be so much easier on Linux.  
Unfortunately I did this on Windows, I used wsl to get dump1090 running in an Ubuntu terminal, I also played around with SDR# to test my antenna builds directly on Windows, you can see this working in the first cantenna image listening to 1090 MHz frequencies. But all that I really need to capture raw data is the official tools, specifically rtl_sdr.exe, everything else is just to confirm that I can in fact receive and decode ADS-B signals with my current physical setup.   
This is the decoded data I get using dump1090 in wsl Ubuntu.  
<img width="1724" height="916" alt="image" src="https://github.com/user-attachments/assets/92e7d700-a727-4e92-af65-5056fce21daf" />  
I also set up tar1090 in wsl to get a live map, just for a sample of what the end product should look like. The range isn't amazing for the current set up I am testing on, but its a good example nevertheless.
<img width="3199" height="1797" alt="image" src="https://github.com/user-attachments/assets/7c5baa96-e2ba-4ed6-a592-59df867f2ef2" />

Decoded ADS-B data looks quite different to I/Q data (see I/Q data captured using rtl_sdr.exe below with the following command).
``` ./rtl_sdr.exe -f 1090000000 -s 2000000 -g 0 -n 20000000 adsb_capture.bin ``` (frequency 1090 MHz, sampling rate of 2000000 MSPS, gain 0 dB (I found this works best I think because of the internal RTL-SDR gain control im not sure), -n 20000000 is the number of samples to capture which took around 11 seconds)
<img width="2092" height="1132" alt="image" src="https://github.com/user-attachments/assets/a040444f-3d98-4e8b-84d7-cb8cd8b4cf26" />  
I/Q data stands for In-phase and Quadrature, it describes the two main components (amplitude and phase) of the received waveform at any one time. rtl_sdr.exe outputs them interleaved as I,Q,I,Q.... (pairs of unsigned 8 bit integers). The output looks like complete garbage, but thats just because powershell cant display raw binary files as text, you can still get an idea of the pairs being sent seperated by commas.  

Below is what normalised I/Q data should look like. The magnitude is just the magnitude of the I and Q values, the noise level is anywhere between 0 and 20 magnitude, with clear ADS-B signals spiking the magnitude to 100+, these parts with sudden spikes to large magnitudes are the parts that will be decoded on the Basys 3 FPGA. For now I will test it by writing to a text file and reading it in VHDL, but later I aim to implement it using rtl_tcp.exe (another awesome program that game in the tools).
<img width="1179" height="825" alt="image" src="https://github.com/user-attachments/assets/94ba3dbb-1b17-48f4-87c3-94f02585135e" />  

# ADS-B preamble
The preamble for an ADS-B signal is an 8 microsecond synchronisation pattern that initiates every message. It consists of 4 pulses at 0, 1, 3.5 and 4.5 microseconds, I am sampling and capturing raw I/Q data at 2 MSPS which means that each preamble lasts for exactly 16 bits (2000000 SPS * 8 microseconds = 16 bits), and so the preamble looks like "10100001010000000". This preamble is used to detect any real time ADS-B preambles in normalised 1090 MHz signal data, its detection indicates the start of a packet and is a signal for the receiver to start decoding. Magnitude data is converted to bits using Pulse Position Modulation (PPM). Every bit period of one microsecond has exactly two samples, with exactly one pulse, the position of the pulse determines if the bit is 1 or 0. Say you have two samples A and B, if A pulses high and B low i.e. A > B, then the bit is 1, if A pulses low and B high i.e. A < B then the bit is 0.  

As a proof of concept I wrote a small C++ program using the I/Q data converted into magnitude data produced by iqnorm.cpp, to produce what I aim to produce in VHDL. That is, decode and detect signals at a reasonable rate and produce a real time output. So, once I/Q data is captured in adsb_capture.bin, it is converted to magnitude values in a format that can easily be read (single magnitude values, one per line) by a receiver in a file adsb_norm.txt. Below are some of the decoded signals obtained in 2 million I/Q samples.  
<img width="1254" height="323" alt="image" src="https://github.com/user-attachments/assets/576705f9-1cee-4f65-9cc9-c4642c305852" />
<img width="1276" height="291" alt="image" src="https://github.com/user-attachments/assets/1fa4de0f-df39-4173-b127-b32d414213b9" />
<img width="1271" height="348" alt="image" src="https://github.com/user-attachments/assets/f144a7ea-e4b7-45f4-adfb-4af5732d4126" />  

# Frame
You can see that different decoded signals have different sets of decoded data, (speed and heading, location and callsign) and that the frame in most signals is 112 bits. Speed, heading, location and callsign are the only pieces of data needed to produce a display. How the receiver knows what its supposed to be decoding is determined by the different sections of information in each frame. DF is downlink format, we are only interested in signals with df 17, this is the first 5 bits of the frame. CA is the transponder capability, this is the next 3 bits of the frame. The ICAO address is the next 24 bits and is a Mode-S transponder code that serves as a unique identifier for the aircraft. The message containing the speed and heading, location or callsign is the next 56 bits. The TC or type code is the first 5 bits of the message, it determines what that particular frames message contains and is how the receiver knows what it is supposed to be decoding, for example type code 1-4 is the aircraft callsign, typecode 9-18 is the barometric altitude. The last 24 bits of the frame contains the Parity/Interrogator ID, this is used in the CRC check.  

The CRC check is essential for verifying that the decoded signal was not corrupted due to noise, weak signals, overlapping transmissions etc. Helpful sources I used for learning these essential things are [here ](https://mode-s.org/1090mhz/content/ads-b/1-basics.html) and the dump1090 source code which was a very helpful example.  
  
The C++ examples I wrote decode around 89 signals per 2 million raw I/Q samples.  
