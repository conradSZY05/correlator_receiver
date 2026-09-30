library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity iqnorm is
    port (
        clk : in std_logic;
        reset : in std_logic;
        data_i : in std_logic_vector(7 downto 0); -- raw I/Q data range 0 to 255
        valid_o : out std_logic;
        data_o : out unsigned(7 downto 0) -- normalised magnitude range 0 to 255
    );
end iqnorm;

architecture rtl of iqnorm is

    function sqrt(I : std_logic_vector(7 downto 0); Q : std_logic_vector(7 downto 0)) return unsigned is
        variable shifted_I : signed(8 downto 0);
        variable shifted_Q : signed(8 downto 0);
        variable max : signed(8 downto 0);
        variable min : signed(8 downto 0);
    begin
        -- approximation of sqrt
        -- its an approximation so sometimes its 1 off of what it should be, but its mostly fine
        -- max(I, Q) + 0.375 * min(I, Q)
        
        -- first convert from 0 to 255 range to -128 to 127 range, and take absolute value
        shifted_I := abs(signed(resize(unsigned(I), 9)) - to_signed(128, 9));
        shifted_Q := abs(signed(resize(unsigned(Q), 9)) - to_signed(128, 9));
        
        -- get max
        if (shifted_I > shifted_Q) then
            max := shifted_I;
            min := shifted_Q;
        else 
            max := shifted_Q;
            min := shifted_I;
        end if;

        return unsigned(max + shift_right(min, 1) + shift_right(min, 2));
    end function;
    
    signal last_data_i : std_logic_vector(7 downto 0) := (others => '0'); -- I 
    signal ready : std_logic := '0';
    signal first : std_logic := '1';
    
begin
    
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                ready <= '0';
                valid_o <= '0';
                data_o <= (others => '0');
                first <= '1';
            else
                valid_o <= '0';
                if (ready = '0') then
                    ready <= '1';
                    -- save the last value
                    last_data_i <= data_i;
                else 
                    ready <= '0';
                    if (first = '1') then
                        first <= '0';
                    else 
                        -- have a set of I/Q, so return a magnitude
                        data_o <= sqrt(last_data_i, data_i)(7 downto 0);
                        valid_o <= '1';
                    end if;
                end if;
            end if;
        end if;
        
    end process;

end rtl;
