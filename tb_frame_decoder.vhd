library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library std;
use std.env.finish;

entity tb_frame_decoder is  
end entity;


architecture sim of tb_frame_decoder is 
    constant CLK_PERIOD : time := 10 ns;
    
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';

    -- frame_decoder stuff
    signal frame : std_logic_vector(111 downto 0) := (others => '0');
    signal start : std_logic := '0';
    signal done : std_logic := '0';
    signal icao : std_logic_vector(23 downto 0) := (others => '0');
    signal callsign : string(1 to 8) := (others => ' ');
    signal lat, lon : signed(27 downto 0) := (others => '0');
    signal speed : unsigned(9 downto 0) := (others => '0');
    signal alt : unsigned(16 downto 0) := (others => '0');
    signal heading : unsigned(9 downto 0) := (others => '0');

begin    
    frame_decoder : entity work.frame_decoder(rtl)
        port map (
            clk => clk,
            reset => reset,
            frame => frame,
            start => start,
            done => done,
            icao => icao,
            callsign => callsign,
            lat => lat,
            lon => lon,
            speed => speed,
            alt => alt, 
            heading => heading
        );


    clk <= not clk after CLK_PERIOD/2;

    
    process

    begin
        reset <= '1';
        wait for CLK_PERIOD;
        reset <= '0';
        wait for CLK_PERIOD;

        frame <= x"8D40621D58C382D690C8AC28C4AE"; -- even
        wait for CLK_PERIOD;
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        frame <= x"8D40621D58C386435CC412692AD6"; -- odd 
        wait for CLK_PERIOD;
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        wait for CLK_PERIOD*7;

        finish;
    end process;

end sim;