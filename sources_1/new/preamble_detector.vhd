library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;


entity preamble_detector is
    port (
        clk : in std_logic;
        reset : in std_logic;
        data_i : in unsigned(7 downto 0); -- 0 to 255 magnitude from rx
        valid_i : in std_logic;
        detected : out std_logic
    );
end preamble_detector;

architecture rtl of preamble_detector is

    type shift_arr_t is array(15 downto 0) of unsigned(7 downto 0);
    signal shift_arr : shift_arr_t := (others => (others => '0'));
    
    
    signal noise_estimate : unsigned(15 downto 0) := (others => '0'); -- rolling estimate of noise
    --signal shifted_noise_estimate : unsigned(7 downto 0) := (others => '0');
    
begin

-- need to calculate noise_estimate + (shift_arr(0) - noise_estimate)/1024
-- noise estimate needs to be Q8.8 format to calculate a rolling average properly
noise_estimate <= noise_estimate - (noise_estimate srl 10) + ((resize(shift_arr(0),16) sll 8) srl 10);
--shifted_noise_estimate <= noise_estimate(15 downto 8);


-- fill shift buffer with magnitudes from iqnorm.vhd
-- doesnt matter that for the first 16 cycles the buffer wont be filled, it just wont detect any preambles
process(clk)
begin
    if rising_edge(clk) then
        if (reset = '1') then
            shift_arr <= (others => (others => '0'));
        else 
            if (valid_i = '1') then -- since iqnorm takes two clock cycles, dont want to fill twice, so only fill when iqnorm pulses valid_o
                
                shift_arr(15 downto 1) <= shift_arr(14 downto 0);
                shift_arr(0) <= data_i;
            end if;
        end if;
    end if;
end process;

-- check if array matches preamble
process(clk)
    variable preamble_mag : signed(11 downto 0) := (others => '0'); -- 16 8 bit numbers added together
    variable gate : signed(8 downto 0) := (others => '0');
begin
    if rising_edge(clk) then
        if (reset = '1') then
            detected <= '0';
            preamble_mag := (others => '0');
            gate := (others => '0');
        else 
            detected <= '0';
            -- calculate the sum using standard ADS-B preamble structure of 1010000101000000
            preamble_mag := signed(resize(unsigned(shift_arr(15)), 12)) - signed(resize(unsigned(shift_arr(14)), 12)) + signed(resize(unsigned(shift_arr(13)), 12)) - signed(resize(unsigned(shift_arr(12)), 12))
                            - signed(resize(unsigned(shift_arr(11)), 12)) - signed(resize(unsigned(shift_arr(10)), 12)) - signed(resize(unsigned(shift_arr(9)), 12)) + signed(resize(unsigned(shift_arr(8)), 12))
                            - signed(resize(unsigned(shift_arr(7)), 12)) + signed(resize(unsigned(shift_arr(6)), 12)) - signed(resize(unsigned(shift_arr(5)), 12)) - signed(resize(unsigned(shift_arr(4)), 12)) 
                            - signed(resize(unsigned(shift_arr(3)), 12)) - signed(resize(unsigned(shift_arr(2)), 12)) - signed(resize(unsigned(shift_arr(1)), 12)) - signed(resize(unsigned(shift_arr(0)), 12)) ;
            -- since there are 4 high preamble values in an ADS-B preamble, check against 4 times the noise threshold
            -- noise_estimate is in Q8.8 format, so need to just take the top 8 bits
            gate := signed('0' & std_logic_vector(shift_left(noise_estimate(15 downto 8), 2)));
            
            -- check if preamble magnitude is greater than the noise threshold
            if (preamble_mag > gate) then
                -- check the peaks are at the correct positions 
                if (signed('0' & std_logic_vector(shift_arr(15))) > gate) and
                   (signed('0' & std_logic_vector(shift_arr(13))) > gate) and
                   (signed('0' & std_logic_vector(shift_arr(8))) > gate) and
                   (signed('0' & std_logic_vector(shift_arr(6))) > gate) then
                   detected <= '1';
                end if; 
            end if;
            
        end if;
    end if;
end process;

end rtl;
