library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_preamble_detector is
end tb_preamble_detector;

architecture sim of tb_preamble_detector is
    constant CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal detected : std_logic := '0';
    
    signal data_i : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_o : std_logic := '0';
    signal data_o : unsigned(7 downto 0) := (others => '0');
    
    type t_char_file is file of character;
    type t_byte_arr is array(natural range <>) of std_logic_vector(7 downto 0);
begin
    norm : entity work.iqnorm(rtl)
        port map(
            clk => clk,
            reset => reset,
            data_i => data_i,
            valid_o => valid_o,
            data_o => data_o
        );
        
    uut : entity work.preamble_detector(rtl) 
        port map(
            clk => clk,
            reset => reset,
            data_i => data_o,
            valid_i => valid_o,
            detected => detected
        );
        
    clk <= not clk after CLK_PERIOD / 2;
    
    process
        file f : t_char_file open read_mode is "C:/Users/conra/Release(1)/x64/adsb_capture.bin";
        variable c : character;
        variable byte_v : std_logic_vector(7 downto 0);
        variable read_arr : t_byte_arr(0 to 6062150);
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
