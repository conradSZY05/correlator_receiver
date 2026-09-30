library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_uart_rx is
end tb_uart_rx;

architecture sim of tb_uart_rx is
    constant CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal start_i : std_logic := '0';
    signal data_i : std_logic := '1';
    signal data_o : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_o : std_logic := '0';
    signal tx_done : std_logic := '0';
    
    signal data_i_tx : std_logic_vector(7 downto 0) := (others => '0');
begin
    tx : entity work.uart_tx(rtl)
        port map (
            clk => clk,
            reset => reset,
            start_i => start_i,
            data_i => data_i_tx,
            tx_done => tx_done,
            data_o => data_i
        );
        

    rx : entity work.uart_rx(rtl)
        port map (
            clk => clk,
            reset => reset,
            data_i => data_i,
            data_o => data_o,
            valid_o => valid_o
        );

    clk <= not clk after CLK_PERIOD / 2;
    
    process
        file f : text open read_mode is "C:\Users\conra\Release(1)\x64\adsb_norm.txt";
        variable f_line : line;
        variable int_v : integer;
    begin
        reset <= '1';
        wait for CLK_PERIOD * 2;
        reset <= '0';
        wait for CLK_PERIOD * 2;
    
        readline(f, f_line);
        read(f_line, int_v);
        data_i_tx <= std_logic_vector(to_unsigned(int_v, 8));
        start_i <= '1';
        wait for CLK_PERIOD;
        start_i <= '0';
        
        while (not endfile(f)) loop
            wait until tx_done = '1';
            wait for CLK_PERIOD;
            readline(f, f_line);
            read(f_line, int_v);
            data_i_tx <= std_logic_vector(to_unsigned(int_v, 8));
            start_i <= '1';
            wait for CLK_PERIOD;
            start_i <= '0';
        end loop;
        
        wait;
    end process;

end sim;
