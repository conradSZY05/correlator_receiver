library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity Dflipflop is
    port (
        clk : in std_logic;
        D : in std_logic;
        Q : out std_logic  
    );
end Dflipflop;

architecture rtl of Dflipflop is
begin

    process (clk) 
        variable count : integer := 0;
    begin
        if rising_edge(clk) then
            count := count + 1;
            if (count = 2) then -- 2 stages to let it settle
                count := 0;
                Q <= D;
            else
                null;
            end if;
        end if;
    end process;

end rtl;
