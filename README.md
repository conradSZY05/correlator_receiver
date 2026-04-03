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
