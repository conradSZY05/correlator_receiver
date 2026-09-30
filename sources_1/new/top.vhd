library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity top is
    port (
        clk_100 : in std_logic; -- 100 MHz clock
        reset : in std_logic;
        
        -- UART
        data_i_uart : in std_logic; -- bits from uart
        
        -- VGA
        vga_r, vga_g, vga_b : out std_logic_vector(3 downto 0);
        h_sync, v_sync : out std_logic
    );
end top;

architecture rtl of top is
    signal valid_o_uart : std_logic := '0';
    signal data_o_uart : std_logic_vector(7 downto 0); -- byte magnitudes from rx module
    
    -- vga
    signal x_px, y_px : std_logic_vector(9 downto 0);
    signal active : std_logic;
    
    -- normalising data, preambles
    signal valid_o_norm : std_logic := '0';
    signal normalised_data : unsigned(7 downto 0) := (others => '0');
    signal preamble_detected : std_logic := '0';
    -- frame reading
    signal frame : std_logic_vector(111 downto 0) := (others => '0');
    signal df : std_logic_vector(4 downto 0) := (others => '0');
    signal ca : std_logic_vector(2 downto 0) := (others => '0');
    signal icao : std_logic_vector(23 downto 0) := (others => '0');
    signal tc : std_logic_vector(4 downto 0) := (others => '0');
    signal message : std_logic_vector(50 downto 0) := (others => '0');
    signal pi : std_logic_vector(23 downto 0) := (others => '0');
    signal done_reading : std_logic := '0';
    -- frame decoding
    
    -- clocking wizard
    signal clk_25 : std_logic;
    signal locked : std_logic;
    component clk_wiz_0
        port (
          clk_out1          : out    std_logic;
          reset             : in     std_logic;
          locked            : out    std_logic;
          clk_in1           : in     std_logic
         );
    end component;
begin

    pixel_clk_wizard : clk_wiz_0
        port map ( 
            clk_out1 => clk_25,           
            reset => reset,
            locked => locked,
            clk_in1 => clk_100
        );

    rx : entity work.uart_rx(rtl)
        port map (
            clk => clk_100,
            reset => reset,
            data_i => data_i_uart,
            data_o => data_o_uart,
            valid_o => valid_o_uart
        );
    vga : entity work.vga_controller(rtl) 
        port map (
            clk => clk_25,
            reset => reset,
            x_px => x_px,
            y_px => y_px,
            hsync => h_sync,
            vsync => v_sync,
            active => active
        );
    -- test values    
    vga_r <= x_px(9 downto 6) when active = '1' else "0000";
    vga_g <= y_px(9 downto 6) when active = '1' else "0000";
    vga_b <= (others => '1') when active = '1' else "0000";
    
    
    -- read two IQ pairs at a time from 0 to 255, normalises to -127 to 128 and returns magnitude from 0 to 255
    iqnorm : entity work.iqnorm(rtl)
        port map (
            clk => clk_100,
            reset => reset,
            data_i => data_o_uart,
            valid_o => valid_o_norm,
            data_o => normalised_data
        );
     
    -- stores last 16 magnitudes in a shift buffer, on each new magnitude uses match filter against known preamble pattern
    preamble_detector : entity work.preamble_detector(rtl)
        port map (
            clk => clk_100,
            reset => reset,
            data_i => normalised_data,
            valid_i => valid_o_norm,
            detected => preamble_detected
        );
        
    -- immediately starts reading and converting magnitudes to bits once preamble is detected, returns a 112 bit frame
    frame_reader : entity work.frame_reader(rtl)
        port map (
            clk => clk_100,
            reset => reset,
            detected => preamble_detected,
            data_i => normalised_data,
            valid_i => valid_o_norm,
            frame => frame,
            done => done_reading
        );    
        
    -- converts frame into actual data (callsign, speed, heading, lat/lon, baro altitude)
--    frame_decoder : entity work.frame_decoder(rtl)
--        port map (
--            clk => clk_100,
--            reset => reset,
--            frame => frame,
--            start => done_reading
--        );
    
    -- converts lat/lon into a local coordinate system
    
    -- need to figure out a way of saving the stuff based on callsign as key maybe, perhaps easier using 
    
    -- display using vga
    

end rtl;
