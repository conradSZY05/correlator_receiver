library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;
--library UNISIM;
--use UNISIM.VComponents.all;

entity top is
    port (
        clk_100 : in std_logic; -- 100 MHz clock
        reset : in std_logic;
        
        -- VGA
        vga_r, vga_g, vga_b : out std_logic_vector(3 downto 0);
        h_sync, v_sync : out std_logic;
        
        -- FT2232H mini module
        ft_data : in std_logic_vector(7 downto 0);
        ft_rxf : in std_logic;
        ft_tx : in std_logic;
        ft_rd : out std_logic;
        ft_oe : out std_logic;
        ft_clkout : in std_logic;
        
        led : out std_logic_vector(7 downto 0)
        
    );
end top;

architecture rtl of top is

    -- fifo
    signal valid_o, fifo_valid, fifo_empty, fifo_full : std_logic := '0';
    signal fifo_dout : std_logic_vector(7 downto 0) := (others => '0');

    -- vga
    signal x_px, y_px : std_logic_vector(9 downto 0) := (others => '0');
    signal active : std_logic := '0';
    
    -- normalising data, preambles
    signal sample : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_o_norm : std_logic := '0';
    signal normalised_data : unsigned(7 downto 0) := (others => '0');
    signal preamble_detected : std_logic := '0';
    -- frame reading
    signal frame : std_logic_vector(111 downto 0) := (others => '0');
    signal icao : std_logic_vector(23 downto 0) := (others => '0');
    signal done_reading : std_logic := '0';
    
    -- frame decoding
    signal done_decoding : std_logic := '0';
    
    -- flight_table 
    signal callsign_w : string(1 to 8) := (others => ' ');
    signal x_w : std_logic_vector(8 downto 0) := (others => '0');
    signal y_w : std_logic_vector(7 downto 0) := (others => '0');
    signal lat_w, lon_w : signed(27 downto 0) := (others => '0');
    signal speed_w : unsigned(9 downto 0) := (others => '0');
    signal alt_w : unsigned(16 downto 0) := (others => '0');
    signal heading_w : unsigned(9 downto 0) := (others => '0'); 
    signal callsign_r : string(1 to 8) := (others => ' ');
    signal x_r : std_logic_vector(8 downto 0) := (others => '0');
    signal y_r : std_logic_vector(7 downto 0) := (others => '0');
    signal lat_r, lon_r : signed(27 downto 0) := (others => '0');
    signal speed_r : unsigned(9 downto 0) := (others => '0');
    signal alt_r : unsigned(16 downto 0) := (others => '0');
    signal heading_r : unsigned(9 downto 0) := (others => '0');
    signal rd_idx : unsigned(5 downto 0) := (others => '0'); -- index of the flight table you want to read??
    signal rd_valid : std_logic := '0';
    
    -- double frame buffer
    signal wr_en_a, wr_en_b: std_logic := '0';
    signal r_data_a, r_data_b, wr_data : std_logic_vector(0 downto 0) := (others => '0');
    signal wr_addr, r_addr : std_logic_vector(16 downto 0);
    signal front_sel : std_logic := '0'; -- '0' means buffer a gets written to and b gets read from
    signal frame_end : std_logic := '0';
    
    signal front_sel_cpy : std_logic := '0';
    
    signal s_fifo, s_norm, s_pre, s_read, s_dec, s_pos, s_tbl : std_logic := '0';
    
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
        
        
    ft_rx : entity work.ft_rx(rtl)
        port map (
            clk => ft_clkout,
            reset => reset,
            rxf_n => ft_rxf,
            oe_n => ft_oe,
            rd_n => ft_rd,
            d_in => ft_data,
            fifo_full => fifo_full,
            data_o => sample,
            valid_o => valid_o
        );
        
        
    u_fifo_rx : entity xil_defaultlib.fifo_rx
        port map (
            rst       => reset,
            wr_clk    => ft_clkout,
            rd_clk    => clk_100,
            din       => sample,
            wr_en     => valid_o,
            rd_en     => fifo_valid,
            dout      => fifo_dout,
            full      => open,
            empty     => fifo_empty,
            prog_full => fifo_full
        );
    
    fifo_valid <= not fifo_empty;
    
    
    -- read two IQ pairs at a time from 0 to 255, normalises to -127 to 128 and returns magnitude from 0 to 255
    iqnorm : entity work.iqnorm(rtl)
        port map (
            clk => clk_100,
            reset => reset,
            data_i => fifo_dout,
            valid_o => valid_o_norm,
            valid_i => fifo_valid,
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
        
        
    frame_decoder : entity work.frame_decoder(rtl)
        port map(
            clk => clk_100,
            reset => reset,
            frame => frame,
            start => done_reading,
            done => done_decoding,
            icao => icao,
            callsign => callsign_w,
            x => x_w,
            y => y_w,
            lat => lat_w,
            lon => lon_w,
            speed => speed_w,
            alt => alt_w,
            heading => heading_w
        );
        
        
    flight_table : entity work.flight_table(rtl)
        port map(
            clk => clk_100,
            reset => reset,
            write => done_decoding,
            icao => icao,
            callsign_w => callsign_w,
            x_w => x_w,
            y_w => y_w,
            lat_w => lat_w,
            lon_w => lon_w,
            speed_w => speed_w,
            alt_w => alt_w,
            heading_w => heading_w,
            callsign_r => callsign_r,
            x_r => x_r,
            y_r => y_r,
            lat_r => lat_r,
            lon_r => lon_r,
            speed_r => speed_r,
            alt_r => alt_r,
            heading_r => heading_r,
            rd_idx => rd_idx, 
            rd_valid => rd_valid
        );
        
        
    renderer : entity work.renderer(rtl)
        port map(
            clk => clk_100,
            reset => reset,
            front_sel => front_sel,
            callsign_r => callsign_r,
            x_r => x_r,
            y_r => y_r,
            lat_r => lat_r,
            lon_r => lon_r,
            speed_r => speed_r,
            alt_r => alt_r,
            heading_r => heading_r,
            rd_idx => rd_idx, 
            rd_valid => rd_valid,
            wr_en_a => wr_en_a,
            wr_en_b => wr_en_b,
            wr_data => wr_data,
            wr_addr => wr_addr
        );
        
    

    fb_a : entity work.framebuffer(rtl)
        port map(
            wr_clk => clk_100,
            wr_en => wr_en_a,
            wr_addr => wr_addr,
            wr_data => wr_data,
            r_clk => clk_25,
            r_addr => r_addr,
            r_data => r_data_a
        );
        
     fb_b : entity work.framebuffer(rtl)
        port map(
            wr_clk => clk_100,
            wr_en => wr_en_b,
            wr_addr => wr_addr,
            wr_data => wr_data,
            r_clk => clk_25,
            r_addr => r_addr,
            r_data => r_data_b
        );
       
    
    
    -- display using vga
    vga : entity work.vga_controller(rtl) 
        port map (
            clk => clk_25,
            reset => reset,
            r_addr => r_addr,
            hsync => h_sync,
            vsync => v_sync,
            front_sel => front_sel,
            active => active
        );
    
    vga_r <= (others => '0');
    vga_g <= (others => '1') when (active = '1' and ((front_sel = '0' and r_data_b(0) = '1') or (front_sel = '1' and r_data_a(0) = '1'))) else (others => '0');
    vga_b <= (others => '0');
    
    process (clk_100)
    begin
        if rising_edge(clk_100) then
            if reset = '1' then
                s_fifo <= '0'; s_norm <= '0'; s_pre <= '0'; s_read <= '0';
                s_dec  <= '0'; s_pos  <= '0'; s_tbl <= '0';
            else
                if fifo_valid        = '1' then s_fifo <= '1'; end if;  -- bytes arrive from the FIFO
                if valid_o_norm      = '1' then s_norm <= '1'; end if;  -- iqnorm produces magnitudes
                if preamble_detected = '1' then s_pre  <= '1'; end if;  -- preamble matched
                if done_reading      = '1' then s_read <= '1'; end if;  -- 112-bit frame captured
                if done_decoding     = '1' then
                    s_dec <= '1';                                       -- decoder accepted a DF17/18 frame
                    if x_w /= "000000000" or y_w /= "00000000" then
                        s_pos <= '1';                                   -- ...with an on-screen position
                    end if;
                end if;
                if rd_valid = '1' then s_tbl <= '1'; end if;            -- table has a valid entry
            end if;
        end if;
    end process;
    
    led <= '0' & s_tbl & s_pos & s_dec & s_read & s_pre & s_norm & s_fifo;
    

end rtl;
