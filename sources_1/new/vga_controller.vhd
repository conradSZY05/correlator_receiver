library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga_controller is
    generic (
        H_PIXELS : integer := 640;
        H_F_PORCH : integer := 16;
        H_S_PULSE : integer := 96;
        H_B_PORCH : integer := 48;
        
        V_PIXELS : integer := 480;
        V_F_PORCH : integer := 10;
        V_S_PULSE : integer := 2;
        V_B_PORCH : integer := 33
    );
    port (
        clk : in std_logic; -- 25.125 MHz from clock wizard
        reset : in std_logic;
        x_px : out std_logic_vector(9 downto 0); -- 0 to 640
        y_px : out std_logic_vector(9 downto 0); -- 0 to 480
        hsync : out std_logic;
        vsync : out std_logic;
        active : out std_logic
    );
end vga_controller;

architecture rtl of vga_controller is

    constant H_MAX : integer := H_PIXELS + H_F_PORCH + H_S_PULSE + H_B_PORCH;
    constant V_MAX : integer := V_PIXELS + V_F_PORCH + V_S_PULSE + V_B_PORCH;
    
    signal h_counter : integer range 0 to H_MAX - 1 := 0;
    signal v_counter : integer range 0 to V_MAX - 1 := 0;
    
begin

    hsync <= '0' when (h_counter > H_PIXELS + H_F_PORCH - 1) and (h_counter < H_MAX - H_B_PORCH) else '1';
    vsync <= '0' when (v_counter > V_PIXELS + V_F_PORCH - 1) and (v_counter < V_MAX - V_B_PORCH) else '1';
    x_px <= std_logic_vector(to_unsigned(h_counter, 10)) when (h_counter < H_PIXELS) and (v_counter < V_PIXELS) else (others => '0');
    y_px <= std_logic_vector(to_unsigned(v_counter, 10)) when (h_counter < H_PIXELS) and (v_counter < V_PIXELS) else (others => '0');
    active <= '1' when (h_counter < H_PIXELS) and (v_counter < V_PIXELS) else '0';
    
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                h_counter <= 0;
                v_counter <= 0;
            else
                if (h_counter = H_MAX - 1) then
                    h_counter <= 0;
                    if (v_counter = V_MAX - 1) then
                        v_counter <= 0;
                    else 
                        v_counter <= v_counter + 1; -- counts complete horizontals
                    end if;
                else
                    h_counter <= h_counter + 1;
                end if; 
            end if;
        end if;
    end process;

end rtl;
