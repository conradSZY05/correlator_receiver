library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_rx is
    generic (
        CLK_DIV : integer := 54 -- (100 MHz / 115200 baud ) / 16 oversampling = 54.25 (change to 1 when running testbench)
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        data_i : in std_logic;
        data_o : out std_logic_vector(7 downto 0); -- 0 to 255 value magnitude
        valid_o : out std_logic
    );
end uart_rx;

architecture rtl of uart_rx is
    type state_t is (IDLE, START, DATA, STOP);
    signal state_r : state_t := IDLE;
    
    signal clk_en : std_logic := '0';
    
    signal start_r : std_logic := '0';
    signal start_reset : std_logic := '0';
    
    signal os_counter : integer range 0 to 15 := 0; -- counting oversampling
    signal counter_reset : std_logic := '0';
    
    signal shift_count : integer range 0 to 8 := 0; -- position in buf_data_o
    
    signal buf_data_o : std_logic_vector(7 downto 0) := (others => '0'); -- building data_o
begin
    -- oversampling clock enable
    process(clk)
        variable clk_cycles : integer := CLK_DIV - 1;
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                clk_en <= '0';
                clk_cycles := CLK_DIV - 1;
            else    
                if (clk_cycles = 0) then
                    clk_en <= '1';
                    clk_cycles := CLK_DIV - 1;
                else 
                    clk_en <= '0';
                    clk_cycles := clk_cycles - 1;
                end if;
            end if;
        end if;
    end process;
    
    -- start signal
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') or (start_reset = '1') then
                start_r <= '0';
            elsif (data_i = '0') and (state_r = IDLE) then
                start_r <= '1';
            end if;
        end if;
    end process;
    
    -- count position in buf_data_i
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') or (counter_reset = '1') then
                os_counter <= 0;
            else
                if (clk_en = '1') then
                    if (os_counter = 15) then
                        os_counter <= 0;
                    else 
                        os_counter <= os_counter + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- fsm
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                state_r <= IDLE;
                start_reset <= '0';
                counter_reset <= '0';
                valid_o <= '0';
            else
                if (clk_en = '1') then
                valid_o <= '0';
                start_reset <= '0';
                counter_reset <= '0';
                    case state_r is
                        when IDLE =>
                            if (start_r = '1') then
                                counter_reset <= '1'; -- clear os_counter
                                start_reset <= '1'; -- clear start_r
                                state_r <= START;
                            end if;
                        when START =>
                            if (os_counter = 6) then
                                shift_count <= 0;
                                state_r <= DATA;
                            end if;
                        when DATA =>
                            if (os_counter = 7) then
                                buf_data_o <= data_i & buf_data_o(7 downto 1);
                                shift_count <= shift_count + 1;
                                if(shift_count = 8) then
                                    state_r <= STOP;
                                end if;
                            end if;
                        when STOP =>
                            if (os_counter = 7) then
                                shift_count <= 0;
                                -- stop bit
                                if (data_i = '1') then 
                                    data_o <= buf_data_o;
                                    valid_o <= '1';
                                    buf_data_o <= (others => '0');
                                end if;
                                state_r <= IDLE;
                                start_reset <= '1';
                            end if;
                        when others =>
                            state_r <= IDLE;
                    end case;
                end if;
            end if;
        end if;
    end process;
end rtl;
