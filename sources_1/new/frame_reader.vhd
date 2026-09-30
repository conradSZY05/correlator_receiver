library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity frame_reader is
    port (
        clk : in std_logic;
        reset : in std_logic;
        detected : in std_logic;
        data_i : in unsigned(7 downto 0);
        valid_i : in std_logic;
        
        -- frame
        frame : out std_logic_vector(111 downto 0);
        done : out std_logic
    );
end frame_reader;

architecture rtl of frame_reader is

    signal last_data_i : unsigned(7 downto 0) := (others => '0');
    signal reading : std_logic := '0';
    signal ready : std_logic := '0';
   
begin

    -- when a preamble is detected, immediately start converting magnitude pairs to bit values
    -- so 112 bit frame from 224 magnitudes
    -- process to fill each component of frame
    process(clk) 
        variable current_bit : std_logic := '0';
        variable bit_count : integer := 0;
        variable clear_frame : std_logic := '0';
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                done <= '0';
                ready <= '0';
                reading <= '0';
                frame <= (others => '0');
            else 
                if (clear_frame = '1') then -- keeps frame contents for one extra cycle so it can be caught by decoder
                    frame <= (others => '0');
                    clear_frame := '0';
                end if;
                
                if (done = '1') then
                    clear_frame := '1';
                end if;
                
                done <= '0';
                if (detected = '1') or (reading = '1') then
                    reading <= '1'; -- keep read high until done reading 224 magnitudes
                    
                    if (bit_count = 112) then
                        bit_count := 0;
                        done <= '1';
                        reading <= '0';
                       
                        
                    end if;
                    if (valid_i = '1') then
                        if (ready = '0') then
                            ready <= '1';
                            last_data_i <= data_i;
                            
                        else
                            ready <= '0';
                            current_bit := '1' when (last_data_i > data_i) else '0'; -- convert magnitude pair to a bit
                            frame(111 - bit_count) <= current_bit;
                            bit_count := bit_count + 1;
    
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;
