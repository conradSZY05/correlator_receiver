library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_frame_reader is
end tb_frame_reader;

architecture sim of tb_frame_reader is
    constant CLK_PERIOD : time := 10 ns;
    constant START_BYTE : integer := 4071288;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal detected : std_logic := '0';
    
    signal data_i : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_o : std_logic := '0';
    signal data_o : unsigned(7 downto 0) := (others => '0');
    
    signal frame : std_logic_vector(111 downto 0) := (others => '0');
        
    signal done : std_logic := '0';
    signal done_decoding : std_logic := '0';
    
    type t_char_file is file of character;
    type t_byte_arr is array(natural range <>) of std_logic_vector(7 downto 0);
    
    signal icao : std_logic_vector(23 downto 0);
    signal callsign_w : string(1 to 8);
    signal lat_w, lon_w : std_logic_vector(16 downto 0);
    signal speed_w : unsigned(9 downto 0);
    signal alt_w : std_logic_vector(12 downto 0);
    signal heading_w : unsigned(9 downto 0);
    
    signal callsign_r : string(1 to 8);
    signal lat_r, lon_r : std_logic_vector(16 downto 0);
    signal speed_r : unsigned(9 downto 0);
    signal alt_r : std_logic_vector(12 downto 0);
    signal heading_r : unsigned(9 downto 0);
    
begin
    norm : entity work.iqnorm(rtl)
        port map(
            clk => clk,
            reset => reset,
            data_i => data_i,
            valid_o => valid_o,
            data_o => data_o
        );
        
    detector : entity work.preamble_detector(rtl) 
        port map(
            clk => clk,
            reset => reset,
            data_i => data_o,
            valid_i => valid_o,
            detected => detected
        );
        
    uut : entity work.frame_reader(rtl)
        port map(
            clk => clk,
            reset => reset,
            detected => detected, 
            data_i => data_o,
            valid_i => valid_o,
            frame => frame,
            done => done
        );
        
    frame_decoder : entity work.frame_decoder(rtl)
        port map (
            clk => clk,
            reset => reset,
            frame => frame,
            start => done,
            done => done_decoding,
            icao => icao,
            callsign => callsign_w,
            lat => lat_w,
            lon => lon_w,
            speed => speed_w,
            alt => alt_w,
            heading => heading_w
        );
        
    flight_table : entity work.flight_table(rtl)
        port map (
            clk => clk,
            reset => reset,
            write => done_decoding,
            icao => icao,
            callsign_w => callsign_w,
            lat_w => lat_w,
            lon_w => lon_w,
            speed_w => speed_w,
            alt_w => alt_w,
            heading_w => heading_w,
            callsign_r => callsign_r,
            lat_r => lat_r,
            lon_r => lon_r,
            speed_r => speed_r,
            alt_r => alt_r,
            heading_r => heading_r
        );
        
    clk <= not clk after CLK_PERIOD / 2;
    
    process
        file f : t_char_file open read_mode is "C:/Users/conra/Release(1)/x64/adsb_test_realistic.bin";
        variable c : character;
        variable byte_v : std_logic_vector(7 downto 0);
        variable read_arr : t_byte_arr(0 to 1499999);
    begin
    
        reset <= '1';
        wait for CLK_PERIOD * 2;
        reset <= '0';
        wait for CLK_PERIOD * 2;
        
        for i in read_arr'range loop
            read(f, c);
            read_arr(i) := std_logic_vector(to_unsigned(character'POS(c), 8));
        end loop;
        
        for i in read_arr'range loop
            data_i <= read_arr(i);
            wait for CLK_PERIOD;
        end loop;
    
        wait;
    end process;

end sim;
