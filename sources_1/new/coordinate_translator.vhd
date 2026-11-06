library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;


entity coordinate_translator is 
    generic ( -- 53.381410824758305, -2.1617052169511735
        REF_LAT : integer := 7006500; -- receiver latitude scaled by 131072
        REF_LON : integer := -290998 -- 46894922 - 47185920 (decoder wraps lon to signed)
    );
    port (
        clk : in std_logic;
        start : in std_logic;
        lat : in signed(27 downto 0);
        lon : in signed(27 downto 0);
        x : out std_logic_vector(8 downto 0);     -- 0..319
        y : out std_logic_vector(7 downto 0);     -- 0..239
        on_screen : out std_logic
    );
end coordinate_translator;

architecture rtl of coordinate_translator is

begin

    process (clk)
        variable dx, dy, px, py : integer;
    begin
        if rising_edge(clk) then
            dx := to_integer(lon) - REF_LON;
            dy := to_integer(lat) - REF_LAT;
            px := 160 + (dx * 19) / 131072;
            py := 120 - dy / 4096;
            if px >= 0 and px < 320 and py >= 0 and py < 240 then
                x <= std_logic_vector(to_unsigned(px, 9));
                y <= std_logic_vector(to_unsigned(py, 8));
                on_screen <= '1';
            else
                x <= (others => '0');
                y <= (others => '0');
                on_screen <= '0';
            end if;
        end if;
    end process;

end rtl;